import Foundation

/// OpenAI 标准 chat/completions 适配（contracts/chat-providers.md）
struct OpenAIAdapter: ChatProtocolAdapter {

    private func buildBody(_ request: ChatRequest, endpoint: ProviderEndpoint, stream: Bool, includeThinking: Bool) -> [String: Any] {
        var messages: [[String: String]] = []
        if !request.systemPrompt.isEmpty {
            messages.append(["role": "system", "content": request.systemPrompt])
        }
        for turn in request.messages {
            messages.append(["role": turn.role, "content": turn.text])
        }
        var body: [String: Any] = [
            "model": endpoint.modelName,
            "messages": messages,
            "stream": stream,
        ]
        if let maxTokens = request.maxTokens {
            body["max_tokens"] = maxTokens
        }
        if includeThinking && request.thinkingEnabled {
            body["reasoning_effort"] = "medium"
        }
        return body
    }

    private func buildRequest(_ request: ChatRequest, endpoint: ProviderEndpoint, stream: Bool, includeThinking: Bool) throws -> URLRequest {
        let url = try APIURLBuilder.endpoint(base: endpoint.baseURL, path: "/v1/chat/completions")
        return try HTTPSupport.jsonRequest(
            url: url,
            apiKeyHeader: (field: "Authorization", value: "Bearer \(endpoint.apiKey)"),
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
                    // 思考参数被拒：剥离后静默重试一次（FR-005）
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
            if event.data == "[DONE]" {
                continuation.yield(.finished)
                continuation.finish()
                return
            }
            if let delta = Self.extractDelta(from: event.data) {
                continuation.yield(.textDelta(delta))
            }
        }
        // 未收到 [DONE] 即结束也按正常完成处理（部分网关不发 DONE）
        continuation.yield(.finished)
        continuation.finish()
    }

    private static func extractDelta(from json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any],
              let content = delta["content"] as? String
        else { return nil }
        return content
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
              let choices = object["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw AppError.unknown("响应格式无法解析")
        }
        return content
    }
}
