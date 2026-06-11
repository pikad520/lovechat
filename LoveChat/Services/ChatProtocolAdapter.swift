import Foundation

// MARK: - 统一请求/事件模型（contracts/chat-providers.md）

struct ChatTurn: Sendable {
    var role: String // "user" | "assistant"
    var text: String
}

struct ChatRequest: Sendable {
    var systemPrompt: String
    var messages: [ChatTurn]
    /// 内部调用（生图判断/压缩/连通性测试）必填（FR-007）
    var maxTokens: Int?
    var thinkingEnabled: Bool

    init(systemPrompt: String = "", messages: [ChatTurn], maxTokens: Int? = nil, thinkingEnabled: Bool = false) {
        self.systemPrompt = systemPrompt
        self.messages = messages
        self.maxTokens = maxTokens
        self.thinkingEnabled = thinkingEnabled
    }
}

/// Provider 调用凭据快照（@Model 不跨并发域，Key 现取自 Keychain）
struct ProviderEndpoint: Sendable {
    var baseURL: String
    var apiKey: String
    var modelName: String
}

enum StreamEvent: Sendable {
    case textDelta(String)
    case finished
}

protocol ChatProtocolAdapter: Sendable {
    func streamChat(_ request: ChatRequest, endpoint: ProviderEndpoint) -> AsyncThrowingStream<StreamEvent, Error>
    func completeOnce(_ request: ChatRequest, endpoint: ProviderEndpoint) async throws -> String
}

// MARK: - Base URL 规范化（research R3）

enum APIURLBuilder {
    /// 已知端点路径后缀：用户把完整接口地址当 Base URL 填进来时自动剥掉
    private static let knownEndpointSuffixes = [
        "/chat/completions",
        "/messages",
        "/images/generations",
    ]

    /// 规范化 Base URL 后拼标准路径，兼容三种填法：
    /// 纯主机、含 /v1、误填完整接口地址（如 …/v1/chat/completions）。
    /// path 形如 "/v1/chat/completions"。
    static func endpoint(base: String, path: String) throws -> URL {
        var normalized = base.trimmingCharacters(in: .whitespacesAndNewlines)

        func trimTrailingSlashes() {
            while normalized.hasSuffix("/") {
                normalized = String(normalized.dropLast())
            }
        }

        trimTrailingSlashes()
        for suffix in knownEndpointSuffixes where normalized.lowercased().hasSuffix(suffix) {
            normalized = String(normalized.dropLast(suffix.count))
            trimTrailingSlashes()
            break
        }
        if normalized.lowercased().hasSuffix("/v1") {
            normalized = String(normalized.dropLast(3))
            trimTrailingSlashes()
        }
        guard !normalized.isEmpty,
              normalized.lowercased().hasPrefix("http"),
              let url = URL(string: normalized + path)
        else {
            throw AppError.invalidURL
        }
        return url
    }
}

// MARK: - 共享 HTTP 工具

enum HTTPSupport {
    static func jsonRequest(url: URL, apiKeyHeader: (field: String, value: String), extraHeaders: [String: String] = [:], body: [String: Any], timeout: TimeInterval = 60) throws -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKeyHeader.value, forHTTPHeaderField: apiKeyHeader.field)
        for (field, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// 读取错误响应体（用于错误映射与思考参数降级判断），上限 64KB
    static func readBody(_ bytes: URLSession.AsyncBytes) async -> String {
        var data = Data()
        do {
            for try await byte in bytes {
                data.append(byte)
                if data.count > 65536 { break }
            }
        } catch {}
        return String(decoding: data, as: UTF8.self)
    }

    /// 思考模式静默降级判定（research R4）：400 且 body 指名思考参数
    static func shouldStripThinking(status: Int, body: String, thinkingEnabled: Bool) -> Bool {
        guard thinkingEnabled, status == 400 else { return false }
        let lower = body.lowercased()
        return lower.contains("reasoning_effort") || lower.contains("reasoning") || lower.contains("thinking")
    }
}
