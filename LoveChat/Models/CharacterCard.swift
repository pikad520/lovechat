import Foundation
import SwiftData

/// 图片生成预置风格（FR-202）：仅三选一，提示词片段硬编码于 PromptLibrary
enum ImageStyle: String, Codable, CaseIterable, Sendable {
    case realistic3D
    case anime3D
    case anime2D

    var displayName: String {
        switch self {
        case .realistic3D: "3D写实"
        case .anime3D: "3D日漫"
        case .anime2D: "2D日漫"
        }
    }
}

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
    /// 图片生成风格（FR-202）；声明默认值保证旧数据轻量迁移
    var imageStyleRaw: String = ImageStyle.realistic3D.rawValue
    /// 回复完成后自动朗读（FR-405）
    var autoSpeak: Bool = false
    /// 角色音色编号；-1 表示跟随全局设置（FR-405/408）
    var voiceSid: Int = -1
    var createdAt: Date

    var imageStyle: ImageStyle {
        get { ImageStyle(rawValue: imageStyleRaw) ?? .realistic3D }
        set { imageStyleRaw = newValue.rawValue }
    }

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
    var imageStyle: ImageStyle
    var autoSpeak: Bool
    var voiceSid: Int

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
        imageStyle = card.imageStyle
        autoSpeak = card.autoSpeak
        voiceSid = card.voiceSid
    }
}
