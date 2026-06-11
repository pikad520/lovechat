# LoveChat

带界面的 AI 角色对话 macOS 应用。SwiftUI + SwiftData + 原生 URLSession SSE，零第三方依赖。

需求基准：[DESIGN.md](DESIGN.md)（唯一需求来源）
开发制品：[specs/001-lovechat-app/](specs/001-lovechat-app/)（spec / plan / tasks，spec-kit 规范驱动开发）

## 环境要求

- macOS 26 (Tahoe) 及以上
- 配套 Xcode（支持 macOS 26 SDK / Swift 6）

## 编译运行

1. `open LoveChat.xcodeproj`
2. 在 Signing & Capabilities 中选择你的 Team（或 Sign to Run Locally）
3. 选择 My Mac，⌘R 运行

## 首次使用

1. 运行后按 ⌘, 打开设置
2. **Provider** 标签页：添加一个 AI Chat Provider（名称、Base URL、API Key、模型名、
   协议类型 OpenAI/Anthropic），点「测试连接」确认可用；可选添加 Imagine Provider（生图）
3. **角色** 标签页：创建角色卡（名称必填；可开启「展示心理活动」「允许发送图片」）
4. 回主窗口点右上角 + 新开对话，选择角色与 Provider，开始聊天

## 功能要点

- 双协议（OpenAI / Anthropic 标准 API），SSE 流式回复，可随时停止
- 思考模式开关（extended thinking / reasoning effort），模型不支持时静默降级
- 心理活动以（括号）特殊样式展示，解析失败自动容错
- 上下文记忆 1–20 轮可调，超出部分后台压缩为摘要，失败降级截断
- 情境生图：自动判断时机 → Images API 生成 → 立即落盘本地
- 对话历史本地持久化（SwiftData），可继续/删除/导出 Markdown，消息可编辑/删除/重新生成
- API Key 仅存 macOS Keychain，绝不明文落盘

## 验证

完整人工验证场景见 [specs/001-lovechat-app/quickstart.md](specs/001-lovechat-app/quickstart.md)。
