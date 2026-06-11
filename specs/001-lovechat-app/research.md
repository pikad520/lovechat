# Research: LoveChat 技术决策

**Date**: 2026-06-10 | **Plan**: [plan.md](./plan.md)

每项格式：Decision / Rationale / Alternatives considered。

## R1. SSE 流式实现

- **Decision**: `URLSession.bytes(for:)` 返回的 `AsyncBytes` 按 `\n` 切行，自实现
  轻量 SSE 解析器（识别 `data:`、`event:` 前缀，空行分隔事件）。
- **Rationale**: 原生 API、天然适配 Swift 并发；SSE 文本协议简单，无需依赖。
- **Alternatives**: ① 第三方 EventSource 库 — 违反宪法 II，弃。② `URLSessionDataDelegate`
  回调式 — 与 async/await 风格割裂，样板代码多，弃。

## R2. 双协议统一抽象

- **Decision**: 定义 `ChatProtocolAdapter` 协议：
  `streamChat(request) -> AsyncThrowingStream<StreamEvent, Error>` 与
  `completeOnce(request) -> String`（非流式）。OpenAI/Anthropic 各一实现。
- **Rationale**: UI 与编排层（ChatService）协议无关；新增协议只加适配器。
- **Alternatives**: 在 ChatService 内 switch 协议分支 — 分支扩散、难测试，弃。

## R3. 协议细节

- **OpenAI**: `POST {base}/chat/completions`，`stream: true`；增量在
  `choices[0].delta.content`；终止标志 `data: [DONE]`。非流式同端点 `stream: false`。
  鉴权 `Authorization: Bearer {key}`。
- **Anthropic**: `POST {base}/v1/messages`，`stream: true`；关注事件
  `content_block_delta`（`delta.text`）与 `message_stop`；需要头
  `x-api-key: {key}`、`anthropic-version: 2023-06-01`。
- **Base URL 规范化**: 用户可能填含或不含 `/v1` 的地址；适配器按「以已知端点后缀
  补全」策略处理（如末尾已含 `/v1` 则不重复追加）。

## R4. 思考模式映射与降级

- **Decision**: Anthropic → `thinking: {"type": "enabled", "budget_tokens": 4096}`
  （同时确保 `max_tokens > budget_tokens`）；OpenAI → `reasoning_effort: "medium"`。
  开关存于 ChatProviderConfig。发送后若收到 HTTP 400 且 body 提到不支持的参数名，
  剥离思考参数重试一次；重试也失败才走常规错误路径。
- **Rationale**: DESIGN.md 要求不支持时静默降级、不中断；预检无法可靠探知模型能力，
  「失败即剥离重试」最稳。
- **Alternatives**: 维护模型能力白名单 — 自定义 Base URL/模型名场景下不可维护，弃。

## R5. 生图判断的结构化输出

- **Decision**: 非流式调用，system 指令要求仅输出 JSON：
  `{"generate": true/false, "prompt": "..."}`，`max_tokens: 200`，温度 0。解析时
  先尝试整体 JSON 解码，失败则正则抽取首个 `{...}` 块，再失败视为 `generate=false`。
- **Rationale**: 双协议通用（不依赖各家专有 structured-output 特性）；解析失败的
  默认值符合「生图失败不影响文字」的降级原则。
- **Alternatives**: OpenAI function calling / Anthropic tool use — 双协议实现成本翻倍
  且自定义网关兼容性差，弃。

## R6. 图片获取与存储

- **Decision**: `POST {base}/images/generations`，请求 `response_format: "b64_json"`；
  若服务忽略该参数返回 `url`，立即下载。字节写入
  `~/Library/Application Support/LoveChat/Images/{uuid}.png`，消息记录仅存文件名。
- **Rationale**: b64 路径彻底规避 URL 过期；文件系统存图避免 SwiftData 膨胀。
- **Alternatives**: SwiftData 存 `Data`（外部存储属性）— 导出/清理不透明，弃。

## R7. Keychain 方案

- **Decision**: `kSecClassGenericPassword`；`kSecAttrService` = `"com.lovechat.app.apikey"`，
  `kSecAttrAccount` = provider UUID 字符串；封装 `KeychainStore.save/load/delete`。
  Provider 删除时同步删除钥匙串条目。
- **Rationale**: 标准做法；UUID 解耦名称变更。
- **Alternatives**: UserDefaults 加混淆 — 仍是明文落盘，违反宪法 III，弃。

## R8. 上下文窗口与压缩算法

- **Decision**: 以「轮」为单位（用户消息+回复=1 轮）。设记忆轮数 N、压缩阈值 T（≤N）。
  当对话总轮数超过 N，把最旧的滑出轮次批量交给 ContextCompressor（非流式，
  prompt 要求第三人称事实摘要，max_tokens 1000），结果合并进
  `Conversation.memorySummary`（已有摘要时执行「旧摘要+新滑出消息→新摘要」）。
  压缩期间用户可继续发消息：压缩任务以 conversation 为粒度串行（actor 隔离），
  完成后一次性写回。失败时仅把滑出消息标记 `excludedFromContext = true`。
- **Rationale**: 满足 FR-015~018 与宪法 IV/V；actor 串行避免摘要写覆盖。
- **Alternatives**: 同步压缩再发送 — 阻塞用户，违反宪法 IV，弃。

## R9. 心理活动解析

- **Decision**: `ThoughtParser` 对完整消息文本做单遍扫描，匹配成对的 `(...)` 与
  全角 `（...）`，输出 `[Segment]`（`.normal(String)` / `.thought(String)`）。
  不配对、嵌套异常时整段回退 `.normal`。流式期间整体按普通文本渲染，流结束后
  再解析一次替换渲染（避免半截括号闪烁）。
- **Rationale**: 容错优先（宪法 V）；流后解析实现简单且视觉稳定。
- **Alternatives**: 流式增量解析 — 状态机复杂、半括号易闪烁，收益低，弃。

## R10. Xcode 工程文件

- **Decision**: 手写 `project.pbxproj`，`objectVersion = 77`，使用
  `PBXFileSystemSynchronizedRootGroup` 指向 `LoveChat/` 目录（Xcode 16+ 的目录同步
  特性，macOS 26 配套 Xcode 支持）。Target 设置：`MACOSX_DEPLOYMENT_TARGET = 26.0`、
  `SWIFT_VERSION = 6.0`、App Sandbox + 出站网络 entitlement、
  `GENERATE_INFOPLIST_FILE = YES`。
- **Rationale**: 目录同步组让新增/删除源文件无需改 pbxproj，最大降低手写工程
  出错面；沙箱+网络是上架 Mac App 的默认要求。
- **Alternatives**: ① 逐文件登记的传统 pbxproj — 手写易错且每加文件要改，弃。
  ② Swift Package 可执行目标 — 不便打包成 .app 与配 entitlements，弃。

## R11. UI 骨架

- **Decision**: `NavigationSplitView`（侧栏=对话卡片列表，详情=ChatView）；
  设置用独立 `Settings` scene（macOS 标准 ⌘,），内含 Provider/角色/通用三个 tab。
  消息列表用 `ScrollView + LazyVStack` + 底部锚定滚动。
- **Rationale**: macOS 平台惯例；SwiftData `@Query` 直接驱动列表。
- **Alternatives**: 自绘窗口管理 — 无必要复杂度，弃。
