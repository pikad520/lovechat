# LoveChat

带界面的 AI 角色对话 macOS 应用：创建你的专属角色，与之流式畅聊，支持心理活动演出、
旁白导演、情境配图与长期记忆。

**作者**：pikad | **技术栈**：Swift 6 · SwiftUI · SwiftData · URLSession SSE · 零第三方依赖

## ✨ 功能特性

### 对话体验
- **SSE 流式回复**：逐字呈现，可随时停止；中断可恢复或重新生成
- **心理活动**：角色用（小括号）穿插内心独白，以特殊样式渲染，格式异常自动容错
- **旁白输入**：在输入框上方描述场景/情节（如「夜晚，两人走在江边」），角色感知剧情推进
- **消息管理**：编辑、删除、重新生成、Markdown 导出

### 角色系统
- 角色卡字段：名称、性别、外貌、灵魂（性格内核）、称呼、说话风格、自由补充
- **头像**：本地上传，或用 Imagine Provider 基于外貌设定一键生成
- **图片生成风格**：3D写实 / 3D日漫 / 2D日漫 预置三选一

### Provider 体系
- **双协议**：OpenAI 标准 API 与 Anthropic 标准 API，可配置多个，内置连通性测试
- **思考模式**：extended thinking / reasoning effort，模型不支持时静默降级
- **情境生图**：自动判断时机 → OpenAI 标准 Images API 生成 → 立即落盘本地

### 记忆与安全
- 上下文记忆 1–20 轮可调；旧消息后台压缩为剧情摘要，失败自动降级截断，永不阻塞
- 对话历史 SwiftData 本地持久化；**API Key 仅存 macOS 钥匙串，绝不明文落盘**

## 📦 环境要求

- macOS 26 (Tahoe) 及以上
- 配套 Xcode（macOS 26 SDK / Swift 6）
- 自备 AI 服务的 API Key（OpenAI / Anthropic 标准协议均可，含各类兼容网关）

## 🔨 编译运行

```bash
open LoveChat.xcodeproj
```

1. 在 Signing & Capabilities 中选择你的 Team（或 Sign to Run Locally）
2. 选择 My Mac，⌘R 运行

## 🚀 首次使用

1. 按 ⌘,（或点侧栏左下角齿轮）打开设置
2. **Provider**：添加 Chat Provider（Base URL 填到 `/v1` 即可），点「测试连接」
3. **角色**：创建角色卡，按需开启心理活动 / 允许发图、设置头像与图片风格
4. 回主窗口点右上角 ✏️ 新开对话开聊

应用内完整指引：菜单栏 帮助 → LoveChat 使用指引（⌘?）

## 🏗 项目结构

本项目采用 [spec-kit](https://github.com/github/spec-kit) 规范驱动开发（SDD）：

| 路径 | 内容 |
| --- | --- |
| `DESIGN.md` | 唯一需求基准 |
| `.specify/memory/constitution.md` | 项目宪法（零依赖、密钥安全等不可协商原则） |
| `specs/001-lovechat-app/` | 主特性：spec / plan / research / data-model / contracts / tasks |
| `specs/002~004-*/` | 各迭代特性制品 |
| `LoveChat/` | 应用源码（Models / Services / ViewModels / Views / Support） |

人工验证场景：[specs/001-lovechat-app/quickstart.md](specs/001-lovechat-app/quickstart.md)

## ⚠️ 免责声明

1. **AI 生成内容**：本应用的对话与图片均由你所接入的第三方 AI 服务生成，内容不代表
   开发者立场。AI 输出可能存在不准确、虚构或不当内容，请自行甄别，不应作为专业建议
   （医疗、法律、财务等）的依据。
2. **虚拟角色**：应用内角色均为虚拟扮演，不具有真实人格。请理性使用，避免过度情感
   依赖；未成年人请在监护人指导下使用。
3. **API 使用与费用**：你需自备第三方 AI 服务的 API Key，调用产生的费用由你与服务商
   结算，与本应用无关。请遵守所接入服务商的使用条款与内容政策。
4. **数据与隐私**：所有对话数据仅存储在你的本机（SwiftData / 本地图片目录 / 钥匙串），
   本应用不收集、不上传任何用户数据；但你发送的消息会经由你配置的 AI 服务商处理，
   其隐私政策请参阅对应服务商条款。
5. **无担保**：本软件按「现状」提供，不附带任何明示或默示担保。因使用本软件造成的
   任何直接或间接损失，开发者不承担责任。

## 📄 License

MIT © pikad
