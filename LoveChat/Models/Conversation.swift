import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var character: CharacterCard?
    var chatProvider: ChatProviderConfig?
    var imagineProvider: ImagineProviderConfig?
    /// 记忆对话轮数，1...20，默认 10（FR-015）
    var memoryTurns: Int
    /// 压缩阈值，UI 层强制 ≤ memoryTurns（FR-016）
    var compressThreshold: Int
    /// 压缩后的历史摘要，注入 system prompt（FR-018）
    var memorySummary: String
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.conversation)
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "新对话",
        character: CharacterCard? = nil,
        chatProvider: ChatProviderConfig? = nil,
        imagineProvider: ImagineProviderConfig? = nil,
        memoryTurns: Int = 10,
        compressThreshold: Int = 10
    ) {
        self.id = id
        self.title = title
        self.character = character
        self.chatProvider = chatProvider
        self.imagineProvider = imagineProvider
        self.memoryTurns = memoryTurns
        self.compressThreshold = min(compressThreshold, memoryTurns)
        self.memorySummary = ""
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// 按时间排序的消息（SwiftData 关系数组无序）
    var sortedMessages: [ChatMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }
}
