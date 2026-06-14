import Foundation
import SwiftData

/// 角色语种：控制回复/心理活动/语音的语言
enum CharacterLanguage: String, Codable, CaseIterable, Sendable {
    case chinese
    case japanese

    var displayName: String {
        switch self {
        case .chinese: "中文"
        case .japanese: "日语"
        }
    }

    /// GPT-SoVITS text_lang / Kokoro lang 提示
    var langCode: String {
        switch self {
        case .chinese: "zh"
        case .japanese: "ja"
        }
    }

    /// 注入 system prompt 的语言指令（硬编码，宪法 VI）
    var promptDirective: String {
        switch self {
        case .chinese:
            "【语言】请始终使用简体中文回复，包括括号内的心理活动。"
        case .japanese:
            "【言語】必ず日本語で応答してください。括弧内の心理描写も日本語で書いてください。"
        }
    }
}

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
    /// 绑定的外接语音服务；nil 用内置引擎（FR-408）
    var voiceProvider: VoiceProviderConfig?
    /// 回复/心理活动/语音的语种；声明默认值保证旧数据轻量迁移
    var languageRaw: String = CharacterLanguage.chinese.rawValue
    var createdAt: Date

    var language: CharacterLanguage {
        get { CharacterLanguage(rawValue: languageRaw) ?? .chinese }
        set { languageRaw = newValue.rawValue }
    }

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
    var externalVoice: VoiceProviderSnapshot?
    var language: CharacterLanguage

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
        externalVoice = card.voiceProvider.map(VoiceProviderSnapshot.init)
        language = card.language
    }
}
