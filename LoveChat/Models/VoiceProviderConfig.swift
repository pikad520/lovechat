import Foundation
import SwiftData

/// 外接语音服务协议（FR-407）
enum VoiceProtocol: String, Codable, CaseIterable, Sendable {
    case openAICompatible
    case gptSoVITS

    var displayName: String {
        switch self {
        case .openAICompatible: "OpenAI 兼容"
        case .gptSoVITS: "GPT-SoVITS"
        }
    }
}

@Model
final class VoiceProviderConfig {
    @Attribute(.unique) var id: UUID
    var name: String
    var baseURL: String
    var protocolTypeRaw: String
    /// OpenAI 兼容：模型名（如 tts-1）；GPT-SoVITS 不使用
    var modelName: String
    /// OpenAI 兼容：音色名（如 alloy）；GPT-SoVITS 不使用
    var voiceName: String
    /// GPT-SoVITS：参考音频在服务端的路径（克隆音色来源）
    var refAudioPath: String
    /// GPT-SoVITS：参考音频对应的文本
    var promptText: String
    var createdAt: Date

    var protocolType: VoiceProtocol {
        get { VoiceProtocol(rawValue: protocolTypeRaw) ?? .gptSoVITS }
        set { protocolTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        baseURL: String = "",
        protocolType: VoiceProtocol = .gptSoVITS,
        modelName: String = "tts-1",
        voiceName: String = "alloy",
        refAudioPath: String = "",
        promptText: String = ""
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.protocolTypeRaw = protocolType.rawValue
        self.modelName = modelName
        self.voiceName = voiceName
        self.refAudioPath = refAudioPath
        self.promptText = promptText
        self.createdAt = Date()
    }
}

/// 跨并发域快照
struct VoiceProviderSnapshot: Sendable {
    var id: UUID
    var baseURL: String
    var protocolType: VoiceProtocol
    var modelName: String
    var voiceName: String
    var refAudioPath: String
    var promptText: String

    init(_ provider: VoiceProviderConfig) {
        id = provider.id
        baseURL = provider.baseURL
        protocolType = provider.protocolType
        modelName = provider.modelName
        voiceName = provider.voiceName
        refAudioPath = provider.refAudioPath
        promptText = provider.promptText
    }
}
