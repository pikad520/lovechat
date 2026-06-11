import Foundation
import SwiftData

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    /// 对话流中的友好错误提示（FR-010），可附带重试动作
    case systemNotice
}

enum MessageStatus: String, Codable, Sendable {
    case pending
    case streaming
    case complete
    case stopped
    case failed
}

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var conversation: Conversation?
    var roleRaw: String
    var text: String
    /// 随用户消息附带的旁白（FR-104/106）；nil 或空表示无旁白
    var narration: String?
    /// ImageStore 中的相对文件名（FR-022）
    var imageFileName: String?
    /// 图片生成失败时在气泡内轻量提示（SC-006）
    var imageFailed: Bool
    var statusRaw: String
    /// 压缩失败降级截断标记（R8）：true 则不进入上下文窗口
    var excludedFromContext: Bool
    var createdAt: Date

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    var status: MessageStatus {
        get { MessageStatus(rawValue: statusRaw) ?? .complete }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String = "",
        status: MessageStatus = .complete
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.text = text
        self.narration = nil
        self.imageFileName = nil
        self.imageFailed = false
        self.statusRaw = status.rawValue
        self.excludedFromContext = false
        self.createdAt = Date()
    }
}
