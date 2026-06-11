<!--
Sync Impact Report
- Version change: (template) → 1.0.0
- Modified principles: 初次制定，全部新增
- Added sections: Core Principles (6), 技术与平台约束, 开发工作流
- Removed sections: 无
- Templates requiring updates:
  - .specify/templates/plan-template.md ✅ 兼容（Constitution Check 门控引用本文件）
  - .specify/templates/spec-template.md ✅ 兼容
  - .specify/templates/tasks-template.md ✅ 兼容
- Follow-up TODOs: 无
-->

# LoveChat Constitution

## Core Principles

### I. DESIGN.md 为唯一需求基准

项目根目录的 `DESIGN.md` 是唯一需求来源（single source of truth）。所有 spec、plan、tasks
必须可追溯到 DESIGN.md 的具体条目；与 DESIGN.md 冲突的实现一律视为缺陷。需求变更 MUST 先
修订 DESIGN.md，再向下游制品传播。

### II. 零第三方依赖（原生优先）

技术栈固定为 SwiftUI + SwiftData + 原生 URLSession（SSE 流式）。MUST NOT 引入任何第三方
包依赖（SPM/CocoaPods/Carthage 均不允许）。所有能力——包括 SSE 解析、JSON 编解码、
Keychain 访问——一律使用 Apple 原生框架实现。

理由：减小供应链风险与维护负担，保证用户拿到 Xcode 工程即可直接编译。

### III. 密钥安全（NON-NEGOTIABLE）

API Key MUST 只存储在 macOS Keychain 中，严禁以任何形式明文落盘——包括 SwiftData、
UserDefaults、日志、导出文件与崩溃报告。日志与错误文案 MUST NOT 包含密钥内容；
导出对话（Markdown）MUST NOT 携带任何 Provider 凭据。

### IV. 流式优先、永不阻塞

聊天回复 MUST 使用 SSE 流式逐字呈现。内部辅助调用（生图判断、context 压缩）MUST 为
非流式且在后台异步执行，MUST NOT 阻塞用户发消息或 UI 渲染。主线程只做 UI；
网络与持久化在并发上下文中完成。

### V. 优雅降级（容错为先）

所有可失败路径 MUST 有降级方案，且降级 MUST 静默或友好、绝不中断主对话流：

- 思考模式参数不被模型支持 → 静默忽略，不报错；
- context 压缩失败 → 降级为直接截断旧消息;
- 生图失败 → 不影响文字回复展示;
- 心理活动括号格式解析失败 → 按普通文本容错显示;
- API 错误（审核拒绝/网络/限流）→ 对话流中友好文案 + 可重试。

### VI. 硬编码提示词边界

三类提示词（心理活动、生图判断、生图模板）MUST 硬编码在代码中，集中于单一源文件管理，
MUST NOT 暴露给用户或角色自定义。System prompt 的组装顺序固定为：
角色设定 → 心理活动提示词（若开启）→ 压缩历史摘要（若有）。

## 技术与平台约束

- 目标平台：macOS 26 (Tahoe) 及以上；仅打包为 Mac App。
- 交付物：完整 Xcode 工程，由用户在 Mac 上用 Xcode 打开编译运行。
- 开发环境无法运行 `xcodebuild`：代码 MUST 在不可编译验证的前提下编写，因此 MUST
  优先选择保守、惯用的 Swift/SwiftUI 写法，避免依赖编译器才能发现的边缘 API。
- 协议支持：OpenAI 标准 API 与 Anthropic 标准 API 双协议；Images API 优先 OpenAI 标准。
- 生成图片 MUST 立即下载到本地存储（返回 URL 短期过期）。
- 上下文记忆轮数 1–20（默认 10）；压缩阈值 MUST ≤ 记忆轮数（UI 层强制）。

## 开发工作流

- 采用 spec-kit 规范驱动开发：constitution → specify → clarify → plan → tasks → implement。
- 每个 feature 的 spec/plan/tasks 制品存放于 `specs/<feature>/` 并随代码一起提交。
- 实现阶段 MUST 按 tasks.md 顺序执行；偏离计划的改动 MUST 回写到对应制品。
- 由于无法本地编译，每个任务完成后 MUST 自查：类型一致性、API 可用性（macOS 26 SDK）、
  并发标注（Swift 6 严格并发）正确性。

## Governance

本 constitution 优先于其他一切开发惯例。修订 MUST 通过更新本文件完成，并附版本号递增
（语义化版本：原则增删为 MAJOR/MINOR，措辞澄清为 PATCH）与 Sync Impact Report。
所有代码评审 MUST 校验对原则 II（零依赖）与 III（密钥安全）的遵从——二者为不可协商项。

**Version**: 1.0.0 | **Ratified**: 2026-06-10 | **Last Amended**: 2026-06-10
