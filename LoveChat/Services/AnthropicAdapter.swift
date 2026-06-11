import Foundation

/// Anthropic 标准 v1/messages 适配（contracts/chat-providers.md）
struct AnthropicAdapter: ChatProtocolAdapter {

    private static let thinkingBudget = 4096
    private static let defaultMaxTokens = 8192

    private func buildBody(_ request: ChatRequest, endpoint: ProviderEndpoint, stream: Bool, includeThinking: Bool) -> [String: Any] {
        var messages: [[String: String]] = []
        for turn in request.messages {
            messages.append(["role": turn.role, "content": turn.text])
        }
        let thinkingActive = includeThinking && request.thinkingEnabled
        // max_tokens 为 Anthropic 必填；开思考时确保大于 budget（research R4）
        var maxTokens = request.maxTokens ?? Self.defaultMaxTokens
        if thinkingActive, maxTokens <= Self.thinkingBudget {
            maxTokens = Self.thinkingBudget + 2048
        }
        var body: [String: Any] = [
            "model": endpoint.modelName,
            "messages": messages,
            "max_tokens": maxTokens,
        ]
        if stream {
            body["stream"] = true
        }
        if !request.systemPrompt.isEmpty {
            body["system"] = request.systemPrompt
        }
        if thinkingActive {
            body["thinking"] = ["type": "enabled", "budget_tokens": Self.thinkingBudget]
        }
        return body
    }

    private func buildRequest(_ request: ChatRequest, endpoint: ProviderEndpoint, stream: Bool, includeThinking: Bool) throws -> URLRequest {
        let url = try APIURLBuilder.endpoint(base: endpoint.baseURL, path: "/v1/messages")
        return try HTTPSupport.jsonRequest(
            url: url,
            apiKeyHeader: (field: "x-api-key", value: endpoint.apiKey),
            extraHeaders: ["anthropic-version": "2023-06-01"],
            body: buildBody(request, endpoint: endpoint, stream: stream, includeThinking: includeThinking),
            timeout: stream ? 300 : 60
        )
    }

    // MARK: - 流式

    func streamChat(_ request: ChatRequest, endpoint: ProviderEndpoint) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            // detached：网络与解析不得继承 MainActor（宪法 IV）
            let task = Task.detached {
                do {
                    try await self.runStream(request, endpoint: endpoint, includeThinking: true, continuation: continuation)
                } catch let error as RetryWithoutThinking {
                    _ = error
                    do {
                        try await self.runStream(request, endpoint: endpoint, includeThinking: false, continuation: continuation)
                    } catch {
                        continuation.finish(throwing: AppError.wrap(error))
                    }
                } catch {
                    continuation.finish(throwing: AppError.wrap(error))
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private struct RetryWithoutThinking: Error {}

    private func runStream(_ request: ChatRequest, endpoint: ProviderEndpoint, includeThinking: Bool, continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation) async throws {
        let urlRequest = try buildRequest(request, endpoint: endpoint, stream: true, includeThinking: includeThinking)
        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.network
        }
        guard http.statusCode == 200 else {
            let body = await HTTPSupport.readBody(bytes)
            if includeThinking, HTTPSupport.shouldStripThinking(status: http.statusCode, body: body, thinkingEnabled: request.thinkingEnabled) {
                throw RetryWithoutThinking()
            }
            throw AppError.from(status: http.statusCode, body: body)
        }
        for try await event in SSEParser.events(from: bytes) {
            guard let data = event.data.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = object["type"] as? String
            else { continue }

            switch type {
            case "content_block_delta":
                if let delta = object["delta"] as? [String: Any],
                   let deltaType = delta["type"] as? String,
                   deltaType == "text_delta",
                   let text = delta["text"] as? String {
                    continuation.yield(.textDelta(text))
                }
                // thinking_delta 忽略（不展示思考过程）
            case "message_stop":
                continuation.yield(.finished)
                continuation.finish()
                return
            case "error":
                let detail = (object["error"] as? [String: Any])?["message"] as? String ?? "服务端流错误"
                throw AppError.unknown(detail)
            default:
                break
            }
        }
        continuation.yield(.finished)
        continuation.finish()
    }

    // MARK: - 非流式

    func completeOnce(_ request: ChatRequest, endpoint: ProviderEndpoint) async throws -> String {
        do {
            return try await runOnce(request, endpoint: endpoint, includeThinking: true)
        } catch let error as RetryWithoutThinking {
            _ = error
            return try await runOnce(request, endpoint: endpoint, includeThinking: false)
        }
    }

    private func runOnce(_ request: ChatRequest, endpoint: ProviderEndpoint, includeThinking: Bool) async throws -> String {
        let urlRequest = try buildRequest(request, endpoint: endpoint, stream: false, includeThinking: includeThinking)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.network
        }
        guard http.statusCode == 200 else {
            let body = String(decoding: data, as: UTF8.self)
            if includeThinking, HTTPSupport.shouldStripThinking(status: http.statusCode, body: body, thinkingEnabled: request.thinkingEnabled) {
                throw RetryWithoutThinking()
            }
            throw AppError.from(status: http.statusCode, body: body)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = object["content"] as? [[String: Any]]
        else {
            throw AppError.unknown("响应格式无法解析")
        }
        // 取首个 text 块（跳过 thinking 块）
        for block in content {
            if let type = block["type"] as? String, type == "text",
               let text = block["text"] as? String {
                return text
            }
        }
        throw AppError.unknown("响应中没有文本内容")
    }
}
