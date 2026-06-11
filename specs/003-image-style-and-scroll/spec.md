# Feature Specification: 图片生成风格 + 历史对话自动定位

**Feature Branch**: `003-image-style-and-scroll`

**Created**: 2026-06-11

**Status**: Draft

**Input**: User description: "①点击历史会话时自动定位到最新消息 ②配置了 Imagine Provider 时，角色设定需选择图片生成风格（作用于头像生成与对话生图），仅预置：3D写实/3D日漫/2D日漫。"

## User Scenarios & Testing

### User Story 1 - 历史对话自动定位 (Priority: P1)

用户点击左侧任意历史对话，聊天区直接显示在最新一条消息处，无需手动滚动。

**Acceptance Scenarios**:

1. **Given** 一段超过一屏的历史对话，**When** 从列表点击进入，**Then** 视图自动定位到最后一条消息（底部）。
2. **Given** 已在对话中，**When** 切换到另一个对话再切回，**Then** 仍定位到最新消息。

### User Story 2 - 图片生成风格 (Priority: P2)

用户在角色编辑界面（已配置 Imagine Provider 时）从三个预置风格中选择一个；
此后该角色的头像生成与对话中的情境生图都使用所选风格。

**Acceptance Scenarios**:

1. **Given** 已配置 Imagine Provider，**When** 编辑角色，**Then** 出现风格选择（3D写实/3D日漫/2D日漫），默认 3D写实。
2. **Given** 未配置任何 Imagine Provider，**When** 编辑角色，**Then** 不显示风格选择。
3. **Given** 角色选择了某风格，**When** 生成头像或对话中触发生图，**Then** 发给 Images API 的提示词包含该风格的硬编码描述。
4. **Given** 既有角色（迭代前创建），**When** 升级后打开，**Then** 风格为默认值 3D写实，数据无损。

### Edge Cases

- 风格提示词不可由用户编辑（宪法 VI）；仅三个预置项，无自定义入口。

## Requirements

- **FR-201**: 打开任意对话 MUST 自动定位到最新消息。
- **FR-202**: 角色 MUST 有图片生成风格字段，预置三选一（3D写实/3D日漫/2D日漫），默认 3D写实；仅在配置了 Imagine Provider 时展示选择项。
- **FR-203**: 风格 MUST 同时作用于头像生成与对话情境生图的提示词；各风格的提示词片段 MUST 硬编码于 PromptLibrary（宪法 VI）。

## Success Criteria

- **SC-201**: 任意长度对话打开即见最新消息，零手动滚动。
- **SC-202**: 三种风格生成的图片风格差异肉眼可辨；旧角色数据零迁移成本。
