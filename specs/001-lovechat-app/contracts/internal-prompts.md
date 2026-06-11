# Contract: 硬编码提示词（PromptLibrary.swift）

三类提示词 MUST 集中于 `LoveChat/Services/PromptLibrary.swift`，无任何 UI 暴露
（宪法 VI / FR-014）。本契约约定其接口与输出格式；中文措辞在实现时定稿。

## P1. 心理活动提示词（appendix to system prompt）

- **接口**: `PromptLibrary.innerThoughtsInstruction: String`
- **要求**: 指示角色在回复中自然穿插心理活动，心理活动必须用半角小括号 `(...)`
  包裹、独立成句、第一人称；正文不得使用小括号做其他用途。
- **消费方**: system prompt 组装（FR-018）；渲染端 `ThoughtParser` 按 R9 容错解析。

## P2. 生图判断提示词（独立非流式调用）

- **接口**: `PromptLibrary.imageDecisionPrompt(recentMessages:) -> String`
- **输入**: 最近 ≤ 6 条消息的纯文本拼接。
- **调用约束**: 非流式、`maxTokens: 200`、不带思考参数。
- **输出契约**（模型被要求仅输出 JSON）:
  ```json
  {"generate": true, "prompt": "<english image description>"}
  ```
- **解析规则**: 整体 JSON 解码 → 失败则抽取首个 `{...}` 再解码 → 仍失败 ⇒
  `{"generate": false}`（降级，宪法 V）。

## P3. 生图提示词模板

- **接口**: `PromptLibrary.imagePrompt(appearance:decisionPrompt:) -> String`
- **组成**: 角色外貌设定（CharacterCard.appearance）+ P2 产出的情境描述 +
  固定质量/风格后缀。产出直接作为 Images API 的 `prompt`。

## System Prompt 组装（FR-018）

- **接口**: `PromptLibrary.systemPrompt(for: CharacterCard, summary: String) -> String`
- **顺序**: 角色设定段 → P1（仅 showInnerThoughts）→ `[过往剧情摘要]` + summary（仅非空）。

## P4. 压缩提示词（ContextCompressor 内部使用，归属同文件）

- **接口**: `PromptLibrary.compressionPrompt(oldSummary:slidOutMessages:) -> String`
- **要求**: 第三人称、保留人物事实/约定/情感进展、≤ 500 字摘要。
- **调用约束**: 非流式、`maxTokens: 1000`。
