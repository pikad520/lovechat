import Foundation

/// 统一错误类型，userMessage 为对话流中的友好文案（FR-010）。
/// 注意：文案与 debug 描述中绝不包含 API Key（宪法 III）。
enum AppError: Error, Sendable {
    case authFailed
    case rateLimited
    case contentRefused
    case network
    case streamInterrupted
    case invalidURL
    case missingAPIKey
    case missingProvider
    case missingCharacter
    case badResponse(Int)
    case unknown(String)

    var userMessage: String {
        switch self {
        case .authFailed:
            "密钥无效或无权限，请检查 Provider 配置。"
        case .rateLimited:
            "请求太频繁，被服务方限流了，稍等片刻再试。"
        case .contentRefused:
            "这条内容被服务方的内容审核拒绝了，换个说法试试。"
        case .network:
            "网络好像不太顺畅，请检查连接后重试。"
        case .streamInterrupted:
            "回复中断了，已保留收到的部分，可以重试或重新生成。"
        case .invalidURL:
            "Provider 的 Base URL 无效，请检查配置。"
        case .missingAPIKey:
            "未找到该 Provider 的 API Key，请重新填写。"
        case .missingProvider:
            "该对话没有可用的 Chat Provider，请在对话设置中重新关联。"
        case .missingCharacter:
            "该对话的角色已被删除，请在对话设置中重新关联角色。"
        case .badResponse(let code):
            "服务返回了错误（HTTP \(code)），请稍后重试。"
        case .unknown(let detail):
            "出了点小问题：\(detail)，请重试。"
        }
    }

    /// HTTP 状态码 + 响应体 → AppError（contracts/chat-providers.md 错误映射）
    static func from(status: Int, body: String) -> AppError {
        switch status {
        case 401, 403:
            return .authFailed
        case 429:
            return .rateLimited
        case 400:
            let lower = body.lowercased()
            if lower.contains("content_policy") || lower.contains("content policy")
                || lower.contains("refusal") || lower.contains("moderation") {
                return .contentRefused
            }
            return .badResponse(400)
        default:
            return .badResponse(status)
        }
    }

    static func wrap(_ error: Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if error is URLError { return .network }
        if error is CancellationError { return .streamInterrupted }
        return .unknown((error as NSError).localizedDescription)
    }
}
