import Foundation

/// 上下文压缩（research R8）：actor 串行执行，永不阻塞发消息（宪法 IV）。
/// 只做网络计算并返回新摘要；SwiftData 写回由调用方在 MainActor 完成。
/// 返回 nil 表示压缩失败 → 调用方降级为截断（FR-017）。
actor ContextCompressor {
    static let shared = ContextCompressor()

    private var inFlight: Set<UUID> = []

    /// 同一对话的压缩去重：已在压缩中则直接返回 nil 且不发起新请求
    func compress(conversationID: UUID, oldSummary: String, slidOutTurns: [ChatTurn], provider: ChatProviderSnapshot) async -> String? {
        guard !inFlight.contains(conversationID) else { return nil }
        inFlight.insert(conversationID)
        defer { inFlight.remove(conversationID) }

        let transcript = slidOutTurns
            .map { "\($0.role == "user" ? "用户" : "角色")：\($0.text)" }
            .joined(separator: "\n")
        let request = ChatRequest(
            messages: [ChatTurn(role: "user", text: PromptLibrary.compressionPrompt(oldSummary: oldSummary, slidOutMessages: transcript))],
            maxTokens: 1000,
            thinkingEnabled: false
        )
        do {
            let endpoint = try ChatService.endpoint(for: provider)
            let summary = try await ChatService.adapter(for: provider.protocolType)
                .completeOnce(request, endpoint: endpoint)
            let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }
}
