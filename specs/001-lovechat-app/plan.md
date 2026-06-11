# Implementation Plan: LoveChat — AI 角色对话 macOS 应用

**Branch**: `001-lovechat-app` | **Date**: 2026-06-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-lovechat-app/spec.md`

## Summary

构建单窗口 macOS 原生应用：左侧对话历史卡片列表，右侧聊天区，独立设置面板管理
Provider 与角色。核心技术路径：SwiftUI 界面 + SwiftData 持久化 + URLSession
`bytes(for:)` 实现 SSE 流式解析；双协议适配器（OpenAI / Anthropic）抽象为统一
`ChatProtocolAdapter` 接口；密钥经 Security 框架存入 Keychain，SwiftData 只存
Keychain 引用；生图判断与上下文压缩走非流式短调用；三类提示词集中硬编码于
`PromptLibrary.swift`。交付完整 Xcode 工程（手写 `project.pbxproj`），用户本机编译。

## Technical Context

**Language/Version**: Swift 6（严格并发），SwiftUI

**Primary Dependencies**: 仅 Apple 原生框架 — SwiftUI、SwiftData、Foundation
(URLSession)、Security (Keychain)、AppKit（NSSavePanel 导出）。零第三方依赖（宪法 II）

**Storage**: SwiftData（对话/消息/角色/Provider 元数据）；图片文件存
`Application Support/LoveChat/Images/`；密钥存 Keychain

**Testing**: 开发环境无 xcodebuild（宪法约束），不交付测试 target；以
quickstart.md 的人工验证场景为准；代码自查门控见宪法「开发工作流」

**Target Platform**: macOS 26 (Tahoe)+，仅 Mac App

**Project Type**: desktop-app（单 Xcode 工程）

**Performance Goals**: 流式首字延迟 ≈ 上游延迟；UI 60fps；压缩/生图判断后台执行不阻塞

**Constraints**: 离线可浏览历史；明文密钥零落盘；内部调用限制 max_tokens

**Scale/Scope**: 单用户本地应用；约 12 个界面组件、5 个 SwiftData 模型、2 个协议适配器

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原则 | 状态 | 说明 |
|------|------|------|
| I. DESIGN.md 唯一基准 | ✅ | spec.md 全部 FR 可追溯至 DESIGN.md 条目 |
| II. 零第三方依赖 | ✅ | 仅 Apple 框架；SSE/JSON/Keychain 全部原生实现 |
| III. 密钥安全 | ✅ | Keychain 存储；SwiftData 模型只持有 keychain key；导出与日志路径设计上不接触密钥 |
| IV. 流式优先、永不阻塞 | ✅ | 聊天 SSE 流式；压缩与生图判断在后台 Task 中非流式执行 |
| V. 优雅降级 | ✅ | 五条降级路径在 data-model 状态机与服务层错误处理中逐一落实 |
| VI. 硬编码提示词边界 | ✅ | PromptLibrary.swift 单文件集中管理，无任何 UI 暴露 |

**Post-Phase-1 re-check**: ✅ 设计制品未引入违背项。

## Project Structure

### Documentation (this feature)

```text
specs/001-lovechat-app/
├── plan.md              # 本文件
├── research.md          # Phase 0 输出
├── data-model.md        # Phase 1 输出
├── quickstart.md        # Phase 1 输出
├── contracts/
│   ├── chat-providers.md    # OpenAI/Anthropic 聊天协议契约
│   ├── image-provider.md    # Images API 契约
│   └── internal-prompts.md  # 硬编码提示词与结构化输出契约
└── tasks.md             # Phase 2 输出（/speckit-tasks 生成）
```

### Source Code (repository root)

```text
LoveChat.xcodeproj/
└── project.pbxproj              # 手写工程文件（单 app target）

LoveChat/
├── LoveChatApp.swift            # @main 入口，ModelContainer 装配
├── Models/
│   ├── ChatProviderConfig.swift # SwiftData @Model
│   ├── ImagineProviderConfig.swift
│   ├── CharacterCard.swift
│   ├── Conversation.swift
│   └── ChatMessage.swift
├── Services/
│   ├── KeychainStore.swift      # SecItem 封装（save/load/delete）
│   ├── PromptLibrary.swift      # 三类硬编码提示词 + system prompt 组装
│   ├── SSEParser.swift          # 行级 SSE 事件解析（AsyncSequence）
│   ├── ChatProtocolAdapter.swift# 协议抽象 + 请求/响应统一模型
│   ├── OpenAIAdapter.swift      # chat/completions 流式 + 非流式
│   ├── AnthropicAdapter.swift   # messages 流式 + 非流式
│   ├── ChatService.swift        # 发送编排：判图→流式→压缩触发
│   ├── ImageGenService.swift    # Images API 调用 + 立即落盘
│   ├── ContextCompressor.swift  # 后台压缩，失败降级截断
│   └── ImageStore.swift         # 图片文件读写（Application Support）
├── ViewModels/
│   └── ChatSessionViewModel.swift  # @Observable，流式状态机
├── Views/
│   ├── ContentView.swift        # NavigationSplitView 主布局
│   ├── ConversationListView.swift  # 卡片式历史列表
│   ├── ChatView.swift           # 消息流 + 输入栏 + 停止/重新生成
│   ├── MessageBubbleView.swift  # 气泡 + 心理活动括号解析渲染
│   ├── CharacterListView.swift
│   ├── CharacterEditView.swift  # 角色卡编辑（含两个开关）
│   ├── ProviderListView.swift
│   ├── ChatProviderEditView.swift   # 含连通性测试按钮
│   ├── ImagineProviderEditView.swift
│   └── SettingsView.swift       # 记忆轮数/压缩阈值（UI 强制约束）
└── Support/
    ├── MarkdownExporter.swift   # 对话导出
    ├── ThoughtParser.swift      # 括号心理活动容错解析
    └── AppError.swift           # 友好错误文案映射
```

**Structure Decision**: 单 app target、按层分组（Models/Services/Views）。无测试
target（开发环境不可编译，宪法约束）；服务层与 UI 严格分离以便日后补测试。

## 关键设计决策（摘自 research.md）

1. **SSE**：`URLSession.shared.bytes(for:)` 得到 `AsyncBytes`，按行切分解析
   `data:` 事件；OpenAI 以 `[DONE]` 结束，Anthropic 以 `message_stop` 事件结束。
2. **双协议适配**：`ChatProtocolAdapter` 协议统一输出 `AsyncThrowingStream<StreamEvent>`
   （`.textDelta` / `.finished` / `.failure`），上层 UI 与协议无关。
3. **思考模式**：Anthropic 加 `thinking: {type: enabled, budget_tokens}`；OpenAI 加
   `reasoning_effort`。收到 400 且错误信息指向该参数时，去掉参数重试一次（静默降级）。
4. **生图判断**：非流式短调用，要求模型输出 JSON `{"generate": bool, "prompt": string}`，
   `max_tokens` 限制 200；解析失败视为「不生图」。
5. **图片落盘**：优先请求 `response_format: b64_json` 直接得到字节；返回 URL 时立即
   `URLSession.data(from:)` 下载；二者最终写入 `ImageStore`，消息只存相对文件名。
6. **Keychain**：`kSecClassGenericPassword`，service = bundle id，account = provider
   UUID；SwiftData 模型只存 UUID 引用。
7. **压缩**：消息数超阈值时取滑出窗口的旧消息，用当前 Chat Provider 非流式调用生成
   摘要写回 `Conversation.memorySummary`；失败时把旧消息标记为 `excludedFromContext`
   （即截断）。
8. **Xcode 工程**：手写 `project.pbxproj`（objectVersion 77 / Xcode 26 格式，
   fileSystemSynchronizedGroups 同步根目录，避免逐文件登记，新增文件零维护）。

## Complexity Tracking

无宪法违背项，无需豁免。
