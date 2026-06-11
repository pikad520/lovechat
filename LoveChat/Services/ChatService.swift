import Foundation

/// Chat Provider 的 Sendable 快照（@Model 不跨并发域）
struct ChatProviderSnapshot: Sendable {
    var id: UUID
    var baseURL: String
    var modelName: String
    var protocolType: APIProtocol
    var thinkingEnabled: Bool

    init(_ provider: ChatProviderConfig) {
        id = provider.id
        baseURL = provider.baseURL
        modelName = provider.modelName
        protocolType = provider.protocolType
        thinkingEnabled = provider.thinkingEnabled
    }
}

/// 生图判断结果（contracts/internal-prompts.md P2）
struct ImageDecision: Sendable {
    var generate: Bool
    var prompt: String
}

/// 无状态编排层：适配器分发、连通性测试、生图判断。
/// 上下文窗口构建与 system prompt 组装见各调用点 + PromptLibrary。
enum ChatService {

    static func adapter(for protocolType: APIProtocol) -> any ChatProtocolAdapter {
        switch protocolType {
        case .openAI: OpenAIAdapter()
        case .anthropic: AnthropicAdapter()
        }
    }

    /// Key 现取自 Keychain，绝不落入模型/日志（宪法 III）
    static func endpoint(for provider: ChatProviderSnapshot) throws -> ProviderEndpoint {
        guard let key = KeychainStore.load(for: provider.id), !key.isEmpty else {
            throw AppError.missingAPIKey
        }
        return ProviderEndpoint(baseURL: provider.baseURL, apiKey: key, modelName: provider.modelName)
    }

    /// 聊天流式回复（FR-006）
    static func streamReply(systemPrompt: String, turns: [ChatTurn], provider: ChatProviderSnapshot) throws -> AsyncThrowingStream<StreamEvent, Error> {
        let endpoint = try endpoint(for: provider)
        let request = ChatRequest(
            systemPrompt: systemPrompt,
            messages: turns,
            maxTokens: nil,
            thinkingEnabled: provider.thinkingEnabled
        )
        return adapter(for: provider.protocolType).streamChat(request, endpoint: endpoint)
    }

    /// 连通性测试（FR-004）：completeOnce ping，maxTokens 5
    static func testConnection(provider: ChatProviderSnapshot) async throws {
        let endpoint = try endpoint(for: provider)
        let request = ChatRequest(
            messages: [ChatTurn(role: "user", text: "ping")],
            maxTokens: 5,
            thinkingEnabled: false
        )
        _ = try await adapter(for: provider.protocolType).completeOnce(request, endpoint: endpoint)
    }

    /// 生图判断（FR-013）：非流式、maxTokens 200、解析失败 ⇒ 不生图（宪法 V）
    static func decideImage(recentTurns: [ChatTurn], provider: ChatProviderSnapshot) async -> ImageDecision {
        let recentText = recentTurns.suffix(6)
            .map { "\($0.role == "user" ? "用户" : "角色")：\($0.text)" }
            .joined(separator: "\n")
        let request = ChatRequest(
            messages: [ChatTurn(role: "user", text: PromptLibrary.imageDecisionPrompt(recentMessages: recentText))],
            maxTokens: 200,
            thinkingEnabled: false
        )
        do {
            let endpoint = try endpoint(for: provider)
            let raw = try await adapter(for: provider.protocolType).completeOnce(request, endpoint: endpoint)
            return parseDecision(raw)
        } catch {
            return ImageDecision(generate: false, prompt: "")
        }
    }

    /// JSON 容错解析：整体解码 → 抽取首个 {...} → 默认不生图
    static func parseDecision(_ raw: String) -> ImageDecision {
        if let decision = decodeDecision(raw) {
            return decision
        }
        if let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}"), start < end {
            let fragment = String(raw[start...end])
            if let decision = decodeDecision(fragment) {
                return decision
            }
        }
        return ImageDecision(generate: false, prompt: "")
    }

    private static func decodeDecision(_ text: String) -> ImageDecision? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let generate = object["generate"] as? Bool
        else { return nil }
        let prompt = object["prompt"] as? String ?? ""
        return ImageDecision(generate: generate, prompt: prompt)
    }
}
