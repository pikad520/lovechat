# Tasks: LoveChat — AI 角色对话 macOS 应用

**Input**: Design documents from `/specs/001-lovechat-app/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: 未要求测试 target（开发环境无 xcodebuild，宪法约束）；验证以
quickstart.md 人工场景为准。

**Organization**: 按用户故事分组；每个故事完成后即为可演示增量。

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [x] T001 创建目录骨架 `LoveChat/`（Models/Services/ViewModels/Views/Support）与
      `LoveChat.xcodeproj/project.pbxproj`（objectVersion 77，
      PBXFileSystemSynchronizedRootGroup 指向 `LoveChat/`，
      MACOSX_DEPLOYMENT_TARGET=26.0，SWIFT_VERSION=6.0，App Sandbox +
      com.apple.security.network.client entitlement，GENERATE_INFOPLIST_FILE=YES）
      ；entitlements 文件 `LoveChat/LoveChat.entitlements`（plan R10）

---

## Phase 2: Foundational（阻塞全部故事）

- [x] T002 [P] 五个 SwiftData 模型：`LoveChat/Models/ChatProviderConfig.swift`、
      `ImagineProviderConfig.swift`、`CharacterCard.swift`、`Conversation.swift`、
      `ChatMessage.swift`（字段/枚举/关系/级联删除严格按 data-model.md，含
      MessageStatus 状态机与 excludedFromContext）
- [x] T003 [P] `LoveChat/Services/KeychainStore.swift`：SecItem save/load/delete，
      service 固定、account=UUID（research R7；宪法 III）
- [x] T004 [P] `LoveChat/Support/AppError.swift`：错误枚举 + 友好文案映射表
      （contracts/chat-providers.md 错误映射）
- [x] T005 [P] `LoveChat/Services/PromptLibrary.swift`：四个硬编码提示词接口 +
      systemPrompt 组装（contracts/internal-prompts.md；宪法 VI）
- [x] T006 `LoveChat/Services/SSEParser.swift`：AsyncBytes → 行缓冲 → SSE 事件
      （data:/event: 前缀、空行分隔；research R1）
- [x] T007 `LoveChat/Services/ChatProtocolAdapter.swift`：StreamEvent、ChatRequest、
      协议定义 + baseURL `/v1` 去重规范化工具（contracts/chat-providers.md）
- [x] T008 [P] `LoveChat/Services/OpenAIAdapter.swift`：流式 + completeOnce +
      reasoning_effort + 400 剥参重试（research R3/R4）
- [x] T009 [P] `LoveChat/Services/AnthropicAdapter.swift`：流式 + completeOnce +
      thinking budget + 400 剥参重试（research R3/R4）
- [x] T010 `LoveChat/LoveChatApp.swift`：@main、ModelContainer（5 模型）、
      NavigationSplitView 壳 `LoveChat/Views/ContentView.swift`、空白占位视图

**Checkpoint**: 工程可在 Xcode 打开编译出空壳 App。

---

## Phase 3: US1 — 配置服务并完成一次流式对话 (P1) 🎯 MVP

**Goal**: Provider 配置 + 连通性测试 + 最简角色 + 流式对话 + 停止 + 错误重试

**Independent Test**: quickstart V1

- [x] T011 [P] [US1] `LoveChat/Views/ProviderListView.swift` +
      `ChatProviderEditView.swift`：增删改查、必填校验、Key 写 Keychain、
      「测试连接」按钮（completeOnce ping，FR-001/003/004）
- [x] T012 [P] [US1] `LoveChat/Views/CharacterListView.swift` +
      `CharacterEditView.swift`：全字段表单 + 两个开关（FR-011；开关本期仅存储）
- [x] T013 [US1] `LoveChat/ViewModels/ChatSessionViewModel.swift`：@Observable 流式
      状态机（pending→streaming→complete/stopped/failed）、Task 取消实现停止、
      错误→.systemNotice 消息 + 重试（FR-006/008/010）
- [x] T014 [US1] `LoveChat/Services/ChatService.swift`：上下文窗口构建（data-model
      派生规则）+ systemPrompt 组装 + 适配器分发（本期暂不含判图/压缩钩子）
- [x] T015 [US1] `LoveChat/Views/ChatView.swift` + `MessageBubbleView.swift`：
      消息流（ScrollView+LazyVStack 底部锚定）、输入栏、停止按钮、流式增量渲染
      （本期气泡纯文本）；新建对话入口（选角色+Provider）
- [x] T016 [US1] `LoveChat/Views/SettingsView.swift`：Settings scene 三 tab 壳，
      接入 Provider/角色两个列表

**Checkpoint**: MVP — 配置→对话→流式→停止→错误重试 全通。

---

## Phase 4: US2 — 角色定制与心理活动 (P2)

**Goal**: 心理活动指令注入与特殊渲染（容错）

**Independent Test**: quickstart V2

- [x] T017 [P] [US2] `LoveChat/Support/ThoughtParser.swift`：单遍扫描半/全角括号
      → [Segment]，异常整体回退 normal（research R9）
- [x] T018 [US2] MessageBubbleView 接 ThoughtParser：流式中纯文本、流结束后解析
      重渲染；thought 段斜体淡色样式（FR-012）
- [x] T019 [US2] ChatService systemPrompt 路径确认 showInnerThoughts 开关生效
      （开启含 P1 指令、关闭不含，FR-018）

**Checkpoint**: 心理活动样式可见且容错。

---

## Phase 5: US3 — 对话管理 (P3)

**Goal**: 历史卡片、继续/删除/新开、重新生成、消息编辑删除、Markdown 导出

**Independent Test**: quickstart V3

- [x] T020 [US3] `LoveChat/Views/ConversationListView.swift`：@Query 卡片列表
      （标题/角色名/更新时间/摘要预览）、选择继续、滑动/右键删除（级联+图片清理）、
      新开对话（FR-019/020）
- [x] T021 [US3] ChatView 消息操作：右键菜单 重新生成最后回复（删旧→重走流式）、
      编辑消息（sheet）、删除消息（FR-009）
- [x] T022 [P] [US3] `LoveChat/Support/MarkdownExporter.swift` + NSSavePanel 导出：
      标题/时间/角色名 + 逐条消息；不含任何配置与密钥（FR-021）
- [x] T023 [US3] 删除保护策略：角色/Provider 被删后历史对话可读可导出，发消息时
      提示重新关联（spec Edge Case / Assumptions）

**Checkpoint**: 对话全生命周期管理可用。

---

## Phase 6: US4 — 上下文记忆与压缩 (P4)

**Goal**: 记忆轮数设置、后台压缩、失败降级截断

**Independent Test**: quickstart V4

- [x] T024 [US4] SettingsView/对话设置：memoryTurns Stepper(1...20) +
      compressThreshold 联动钳制 ≤ memoryTurns（FR-015/016）
- [x] T025 [US4] `LoveChat/Services/ContextCompressor.swift`：actor、按对话串行；
      旧摘要+滑出消息→新摘要（P4 提示词，completeOnce maxTokens 1000）写回
      memorySummary；失败标记 excludedFromContext（FR-016/017，research R8）
- [x] T026 [US4] ChatService 接入：发送后检测超阈值→后台 Task 触发压缩；上下文
      窗口排除 excluded 消息；摘要注入 systemPrompt（FR-018）

**Checkpoint**: 长对话记忆生效、压缩永不阻塞。

---

## Phase 7: US5 — 图片生成联动 (P5)

**Goal**: Imagine Provider 配置、生图判断、生成落盘、失败降级

**Independent Test**: quickstart V5

- [x] T027 [P] [US5] `LoveChat/Views/ImagineProviderEditView.swift` + 列表接入
      SettingsView；Key 入 Keychain（FR-002/003）
- [x] T028 [P] [US5] `LoveChat/Services/ImageStore.swift`：Application Support/
      LoveChat/Images 读写/删除（research R6）
- [x] T029 [US5] `LoveChat/Services/ImageGenService.swift`：Images API（b64_json
      优先、URL 立即下载、120s 超时）→ ImageStore（contracts/image-provider.md）
- [x] T030 [US5] ChatService 接入判图流程：allowImages 时每条用户消息先
      completeOnce 判断（P2 提示词，maxTokens 200，JSON 容错解析）→ 并行生图，
      失败仅提示图片失败、文字不受影响（FR-013，SC-006）
- [x] T031 [US5] MessageBubbleView 图片渲染：缩略图 + 点击放大 + 失败占位；
      对话新建/设置中可选 Imagine Provider

**Checkpoint**: 图文联动完整，失败零干扰。

---

## Phase 8: US6 — 思考模式 (P6)

**Goal**: 开关贯通 + 静默降级验证

**Independent Test**: quickstart V6

- [x] T032 [US6] ChatProviderEditView 暴露 thinkingEnabled 开关；ChatService 透传；
      复核两适配器 400 剥参重试路径覆盖思考参数（FR-005）

---

## Phase 9: Polish & Cross-Cutting

- [x] T033 [P] 全局自查（宪法「开发工作流」门控）：Swift 6 并发标注
      （@MainActor/actor/Sendable）一致性、macOS 26 SDK API 可用性、类型一致性
- [x] T034 [P] 密钥安全审计：grep 全部落盘路径（SwiftData/导出/日志/错误文案）
      确认零明文密钥（宪法 III，SC-005）
- [x] T035 README.md：编译步骤、配置指引、quickstart.md 链接
- [x] T036 按 quickstart.md V1–V7 走查代码路径（桌面无编译环境，逐场景代码审读
      确认行为符合预期）

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 →（Phase 3..8 按优先级顺序；US2/US3 仅依赖 Foundational+US1
  的 ChatView 骨架；US4/US5 依赖 ChatService）→ Phase 9
- 同 Phase 内 [P] 任务文件互不重叠，可并行。

## Implementation Strategy

MVP = Phase 1–3（T001–T016），随后按 US2→US6 增量交付，每个 Checkpoint 可独立演示。
