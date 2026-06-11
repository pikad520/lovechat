import SwiftUI

/// 中文使用指引（FR-302）：内容硬编码，不依赖网络
struct HelpGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("LoveChat 使用指引")
                    .font(.largeTitle.bold())

                section("1. 快速开始", """
                ① 按 ⌘, 或点击主窗口左下角齿轮打开设置
                ② 在「Provider」标签页添加一个 AI Chat Provider：填写名称、Base URL、\
                API Key、模型名，选择协议类型（OpenAI 标准 / Anthropic 标准），点「测试连接」确认可用
                ③ 在「角色」标签页创建角色卡（仅名称必填）
                ④ 回主窗口点右上角 ✏️ 新开对话，选择角色与 Provider，开始聊天
                """)

                section("2. Provider 配置", """
                • Base URL 填到域名或 /v1 即可（如 https://api.openai.com/v1），\
                误填完整接口地址也会自动纠正
                • API Key 只保存在 macOS 钥匙串中，绝不明文存储
                • 「思考模式」开启后支持的模型会先深入思考再回复；不支持的模型自动忽略，不会报错
                • Imagine Provider 用于图片生成，使用 OpenAI 标准 Images API
                """)

                section("3. 角色卡片", """
                • 外貌、灵魂、说话风格等字段写得越具体，角色扮演效果越好
                • 头像：可上传本地图片，或用 Imagine Provider 基于外貌设定一键生成
                • 「展示心理活动」：角色会用（小括号）穿插内心独白，以特殊样式渲染
                • 「允许发送图片」：根据对话情境自动判断并生成图片（需为对话配置 Imagine Provider）
                • 图片生成风格：3D写实 / 3D日漫 / 2D日漫 三选一，同时作用于头像与对话生图
                """)

                section("4. 对话功能", """
                • 回复为流式输出，期间可随时点 ⏹ 停止
                • 右键消息：编辑、删除；右键最后一条角色回复可「重新生成」
                • 输入框上方的「旁白」栏（可选）：描述场景或情节，如「夜晚，两人走在江边」，\
                发送后角色会感知场景；旁白以斜体样式显示在你的消息上方
                • 工具栏 ↑ 按钮可将对话导出为 Markdown 文件
                """)

                section("5. 记忆与压缩", """
                • 对话设置（工具栏滑块按钮）中可调记忆轮数（1–20，默认 10）
                • 超出记忆窗口的旧消息会在后台自动压缩成剧情摘要，角色依然「记得」之前的事
                • 压缩阈值控制积累多少轮旧消息后触发压缩，不能大于记忆轮数
                """)

                section("6. 常见问题", """
                • 测试连接失败：检查 Base URL、API Key、模型名是否正确，网络是否可达
                • 回复中断：网络波动所致，已收到的内容会保留，可点「重试」或「重新生成」
                • 内容被拒绝：服务方内容审核所致，换个说法即可
                • 图片生成失败：不影响文字回复，可检查 Imagine Provider 配置
                • 删除了正在使用的角色/Provider：历史对话仍可查看与导出，\
                继续聊天需在对话设置中重新关联
                """)
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
            .textSelection(.enabled)
        }
        .frame(minWidth: 520, idealWidth: 640, minHeight: 480, idealHeight: 640)
    }

    private func section(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.bold())
            Text(content)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(3)
        }
    }
}
