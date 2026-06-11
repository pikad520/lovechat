# Tasks: 图片生成风格 + 历史对话自动定位

**Input**: specs/003-image-style-and-scroll/spec.md | 架构沿用 001 plan

- [x] T201 ChatView：打开对话自动定位最新消息（defaultScrollAnchor + onAppear 兜底）（FR-201）
- [x] T202 CharacterCard：ImageStyle 枚举（realistic3D/anime3D/anime2D）+ imageStyleRaw 字段（声明默认值，轻量迁移）+ Snapshot 透传（FR-202）
- [x] T203 PromptLibrary：三种风格硬编码提示词片段；avatarPrompt/imagePrompt 接入 style 参数（FR-203）
- [x] T204 CharacterEditView：风格 Picker（仅 imagineProviders 非空时显示）；头像生成走所选风格（FR-202/203）
- [x] T205 ChatSessionViewModel：对话生图提示词携带角色风格（FR-203）
- [x] T206 自查 + 提交
