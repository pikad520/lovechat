import Foundation

/// 对话导出（FR-021）：只含对话内容与角色名，绝不含 Provider 配置或密钥（宪法 III）。
enum MarkdownExporter {

    @MainActor
    static func export(_ conversation: Conversation) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        let characterName = conversation.character?.name ?? "角色"
        var lines: [String] = []
        lines.append("# \(conversation.title)")
        lines.append("")
        lines.append("- 角色：\(characterName)")
        lines.append("- 创建时间：\(formatter.string(from: conversation.createdAt))")
        lines.append("- 导出时间：\(formatter.string(from: Date()))")
        lines.append("")
        lines.append("---")
        lines.append("")

        for message in conversation.sortedMessages {
            switch message.role {
            case .user:
                lines.append("**我**：")
            case .assistant:
                lines.append("**\(characterName)**：")
            case .systemNotice:
                continue // 错误提示不进入导出
            }
            lines.append("")
            lines.append(message.text)
            if message.imageFileName != nil {
                lines.append("")
                lines.append("> 📷 [此处有一张生成的图片]")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
