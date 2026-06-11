# Data Model: LoveChat

**Date**: 2026-06-10 | **Plan**: [plan.md](./plan.md)

全部实体为 SwiftData `@Model`。API Key 不在任何模型中——只存 Keychain，模型持有
UUID 引用（宪法 III）。

## ChatProviderConfig

| 字段 | 类型 | 约束/默认 |
|------|------|-----------|
| id | UUID | 主键；亦为 Keychain account |
| name | String | 必填，非空 |
| baseURL | String | 必填，URL 格式 |
| modelName | String | 必填 |
| protocolType | enum `APIProtocol` | `.openAI` / `.anthropic` |
| thinkingEnabled | Bool | 默认 false |
| createdAt | Date | 自动 |

## ImagineProviderConfig

| 字段 | 类型 | 约束/默认 |
|------|------|-----------|
| id | UUID | 主键；亦为 Keychain account |
| name | String | 必填 |
| baseURL | String | 必填 |
| modelName | String | 必填 |
| createdAt | Date | 自动 |

## CharacterCard

| 字段 | 类型 | 约束/默认 |
|------|------|-----------|
| id | UUID | 主键 |
| name | String | 必填 |
| gender | String | 可空串 |
| appearance | String | 外貌；生图模板的素材 |
| soul | String | 性格内核 |
| userAddressing | String | 对用户的称呼 |
| speakingStyle | String | 说话风格 |
| extraNotes | String | 自由补充 |
| showInnerThoughts | Bool | 默认 false（FR-012） |
| allowImages | Bool | 默认 false（FR-013） |
| createdAt | Date | 自动 |

## Conversation

| 字段 | 类型 | 约束/默认 |
|------|------|-----------|
| id | UUID | 主键 |
| title | String | 默认取首条用户消息前缀 |
| character | CharacterCard? | 可空（角色被删后历史仍可读） |
| chatProvider | ChatProviderConfig? | 可空（同上） |
| imagineProvider | ImagineProviderConfig? | 可空 |
| memoryTurns | Int | 1...20，默认 10（FR-015） |
| compressThreshold | Int | ≤ memoryTurns，UI 强制（FR-016） |
| memorySummary | String | 压缩摘要，初始空 |
| messages | [ChatMessage] | 级联删除 |
| createdAt / updatedAt | Date | 自动 |

## ChatMessage

| 字段 | 类型 | 约束/默认 |
|------|------|-----------|
| id | UUID | 主键 |
| conversation | Conversation? | 反向关系 |
| role | enum `MessageRole` | `.user` / `.assistant` / `.systemNotice`（错误文案用） |
| text | String | 内容 |
| imageFileName | String? | ImageStore 中的相对文件名（FR-022） |
| status | enum `MessageStatus` | 见状态机 |
| excludedFromContext | Bool | 默认 false；压缩降级截断用（R8） |
| createdAt | Date | 自动 |

### MessageStatus 状态机

```text
.pending ──开始收流──▶ .streaming ──正常结束──▶ .complete
   │                      │
   │                      ├─用户停止──▶ .stopped   （内容保留，可重新生成）
   │                      └─流中断───▶ .failed    （内容保留，可重试/重新生成）
   └─请求失败────────────▶ .failed
```

- 重新生成：删除最后一条 assistant 消息 → 新建 `.pending` 消息走完整流程。
- `.systemNotice` 消息承载友好错误文案（FR-010），带重试动作。

## 派生规则（非持久化）

- **上下文窗口**：取最近 `memoryTurns` 轮中 `excludedFromContext == false` 且
  `status == .complete`（用户消息恒视为 complete）的消息。
- **system prompt**（PromptLibrary 组装，FR-018）：
  `角色设定段(name/gender/appearance/soul/userAddressing/speakingStyle/extraNotes)`
  + `心理活动提示词`（仅 showInnerThoughts）
  + `"[过往剧情摘要]\n" + memorySummary`（仅非空）。

## 校验规则汇总

| 规则 | 落点 |
|------|------|
| Provider 必填字段非空、baseURL 可解析为 URL | 编辑表单保存校验 |
| memoryTurns ∈ [1,20] | Stepper/TextField 双向钳制 |
| compressThreshold ≤ memoryTurns | 表单联动钳制（FR-016） |
| 删除 Provider → 删除 Keychain 条目 | KeychainStore.delete |
| 删除 Conversation → 级联删消息 + 清理关联图片文件 | 删除流程 |
