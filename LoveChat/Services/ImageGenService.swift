import Foundation

/// Imagine Provider 的 Sendable 快照
struct ImagineProviderSnapshot: Sendable {
    var id: UUID
    var baseURL: String
    var modelName: String

    init(_ provider: ImagineProviderConfig) {
        id = provider.id
        baseURL = provider.baseURL
        modelName = provider.modelName
    }
}

/// OpenAI 标准 Images API（contracts/image-provider.md）：
/// b64_json 优先；返回 URL 则立即下载（短期过期）；任何失败抛出，
/// 由调用方按"生图失败不影响文字"降级（SC-006）。
enum ImageGenService {

    static func generate(prompt: String, provider: ImagineProviderSnapshot) async throws -> String {
        guard let key = KeychainStore.load(for: provider.id), !key.isEmpty else {
            throw AppError.missingAPIKey
        }
        let url = try APIURLBuilder.endpoint(base: provider.baseURL, path: "/v1/images/generations")
        let body: [String: Any] = [
            "model": provider.modelName,
            "prompt": prompt,
            "n": 1,
            "response_format": "b64_json",
        ]
        let request = try HTTPSupport.jsonRequest(
            url: url,
            apiKeyHeader: (field: "Authorization", value: "Bearer \(key)"),
            body: body,
            timeout: 120
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.network
        }
        guard http.statusCode == 200 else {
            throw AppError.from(status: http.statusCode, body: String(decoding: data, as: UTF8.self))
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = object["data"] as? [[String: Any]],
              let first = items.first
        else {
            throw AppError.unknown("生图响应格式无法解析")
        }

        let imageData: Data
        if let b64 = first["b64_json"] as? String, let decoded = Data(base64Encoded: b64) {
            imageData = decoded
        } else if let urlString = first["url"] as? String, let imageURL = URL(string: urlString) {
            // URL 短期过期，立即下载（FR-022）
            let (downloaded, downloadResponse) = try await URLSession.shared.data(from: imageURL)
            guard (downloadResponse as? HTTPURLResponse)?.statusCode == 200 else {
                throw AppError.network
            }
            imageData = downloaded
        } else {
            throw AppError.unknown("生图响应中没有图片数据")
        }
        return try ImageStore.save(imageData)
    }
}
