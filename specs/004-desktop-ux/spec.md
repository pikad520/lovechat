# Feature Specification: 桌面体验（设置入口 / 帮助指引 / About 作者）

**Feature Branch**: `004-desktop-ux`

**Created**: 2026-06-11

**Status**: Draft

**Input**: User description: "①左下角增加设置按钮（兼容 Windows 用户操作体验）②Help 菜单增加中文使用指引 ③About 中增加作者名称 pikad。"

## User Scenarios & Testing

### User Story 1 - 左下角设置按钮 (Priority: P1)

不熟悉 macOS ⌘, 习惯的用户（如 Windows 迁移用户）在主窗口侧栏左下角看到齿轮按钮，
点击即打开设置窗口。

**Acceptance Scenarios**:

1. **Given** 主窗口，**When** 点击侧栏左下角齿轮按钮，**Then** 打开与 ⌘, 相同的设置窗口。

### User Story 2 - Help 使用指引 (Priority: P2)

用户点菜单栏「帮助」中的「LoveChat 使用指引」，弹出独立窗口展示中文图文指引，
覆盖：配置 Provider、创建角色、对话功能、旁白、生图、记忆压缩、常见问题。

**Acceptance Scenarios**:

1. **Given** 任意时刻，**When** 点 Help → 使用指引（或 ⌘?），**Then** 打开指引窗口，内容为中文。
2. **Given** 指引窗口已开，**When** 再次触发，**Then** 聚焦既有窗口而非重复开窗。

### User Story 3 - About 作者署名 (Priority: P3)

**Acceptance Scenarios**:

1. **Given** 应用菜单，**When** 点「关于 LoveChat」，**Then** 面板中显示「作者：pikad」。

## Requirements

- **FR-301**: 侧栏左下角 MUST 有设置按钮，行为与 ⌘, 一致。
- **FR-302**: Help 菜单 MUST 提供中文使用指引窗口（⌘? 快捷键）；内容硬编码于应用内，不依赖网络。
- **FR-303**: About 面板 MUST 显示作者名称 pikad。
