import Foundation
import SwiftData

enum APIProtocol: String, Codable, CaseIterable, Sendable {
    case openAI
    case anthropic

    var displayName: String {
        switch self {
        case .openAI: "OpenAI 标准"
        case .anthropic: "Anthropic 标准"
        }
    }
}

@Model
final class ChatProviderConfig {
    @Attribute(.unique) var id: UUID
    var name: String
    var baseURL: String
    var modelName: String
    var protocolTypeRaw: String
    var thinkingEnabled: Bool
    var createdAt: Date

    var protocolType: APIProtocol {
        get { APIProtocol(rawValue: protocolTypeRaw) ?? .openAI }
        set { protocolTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        baseURL: String = "",
        modelName: String = "",
        protocolType: APIProtocol = .openAI,
        thinkingEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.modelName = modelName
        self.protocolTypeRaw = protocolType.rawValue
        self.thinkingEnabled = thinkingEnabled
        self.createdAt = Date()
    }
}
