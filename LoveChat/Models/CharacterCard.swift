import Foundation
import SwiftData

@Model
final class CharacterCard {
    @Attribute(.unique) var id: UUID
    var name: String
    var gender: String
    var appearance: String
    var soul: String
    var userAddressing: String
    var speakingStyle: String
    var extraNotes: String
    var showInnerThoughts: Bool
    var allowImages: Bool
    /// ImageStore 中的头像文件名（FR-101）；nil 时 UI 显示占位
    var avatarFileName: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        gender: String = "",
        appearance: String = "",
        soul: String = "",
        userAddressing: String = "",
        speakingStyle: String = "",
        extraNotes: String = "",
        showInnerThoughts: Bool = false,
        allowImages: Bool = false
    ) {
        self.id = id
        self.name = name
        self.gender = gender
        self.appearance = appearance
        self.soul = soul
        self.userAddressing = userAddressing
        self.speakingStyle = speakingStyle
        self.extraNotes = extraNotes
        self.showInnerThoughts = showInnerThoughts
        self.allowImages = allowImages
        self.avatarFileName = nil
        self.createdAt = Date()
    }
}

/// 跨并发域传递的角色快照（@Model 非 Sendable，服务层只接收快照）
struct CharacterSnapshot: Sendable {
    var name: String
    var gender: String
    var appearance: String
    var soul: String
    var userAddressing: String
    var speakingStyle: String
    var extraNotes: String
    var showInnerThoughts: Bool
    var allowImages: Bool

    init(_ card: CharacterCard) {
        name = card.name
        gender = card.gender
        appearance = card.appearance
        soul = card.soul
        userAddressing = card.userAddressing
        speakingStyle = card.speakingStyle
        extraNotes = card.extraNotes
        showInnerThoughts = card.showInnerThoughts
        allowImages = card.allowImages
    }
}
