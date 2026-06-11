# Tasks: 角色头像与旁白输入

**Input**: specs/002-avatar-and-narration/spec.md | 架构沿用 001 plan，无新增依赖（宪法 II）

技术要点（plan 摘要）：
- `CharacterCard.avatarFileName: String?`、`ChatMessage.narration: String?` —— 均为可选新增字段，SwiftData 轻量迁移自动完成
- 头像文件复用 ImageStore；生成头像走 ImageGenService + PromptLibrary 新增 avatarPrompt（硬编码）
- 旁白合并标记由 PromptLibrary.composeUserTurn 硬编码（FR-105，宪法 VI）；
  ChatSessionViewModel.contextTurns 与压缩输入统一经由该函数组装

- [x] T101 模型字段：CharacterCard.avatarFileName、ChatMessage.narration（FR-101/106）
- [x] T102 PromptLibrary：avatarPrompt(appearance:)（P5）+ composeUserTurn(narration:text:)（FR-105）
- [x] T103 CharacterEditView 头像区：预览、上传（NSOpenPanel）、Imagine 生成（Provider 选择 + 进度 + 失败提示）、移除；换头像清理旧文件（FR-101/102）
- [x] T104 CharacterListView：删除角色时清理头像文件；列表行显示小头像（FR-102）
- [x] T105 MessageBubbleView：assistant 消息旁圆形头像/占位；user 气泡内旁白特殊样式（FR-103/106）
- [x] T106 ChatView：旁白输入框（非必填、发送后清空）；头像传入气泡（FR-104）
- [x] T107 ChatSessionViewModel：send 携带 narration；contextTurns/压缩输入经 composeUserTurn 组装（FR-105/106）
- [x] T108 自查：零回归路径（无旁白时请求体不变）、Swift 6 并发、文件清理完整性
