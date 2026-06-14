import Foundation

/// 外接语音服务客户端（FR-407）：返回可直接交给 AVAudioPlayer 的音频字节。
/// 任何失败抛错，由 SpeechCoordinator 决定回退内置引擎（FR-408）。
enum ExternalVoiceClient {

    static func synthesize(text: String, provider: VoiceProviderSnapshot, langCode: String = "zh") async throws -> Data {
        switch provider.protocolType {
        case .openAICompatible:
            try await synthesizeOpenAI(text: text, provider: provider)
        case .gptSoVITS:
            try await synthesizeGPTSoVITS(text: text, provider: provider, langCode: langCode)
        }
    }

    /// 连通性测试：合成一句短语
    static func testConnection(provider: VoiceProviderSnapshot) async throws {
        let data = try await synthesize(text: "你好。", provider: provider)
        guard !data.isEmpty else {
            throw AppError.unknown("服务返回了空音频")
        }
    }

    // MARK: - OpenAI 兼容 /v1/audio/speech

    private static func synthesizeOpenAI(text: String, provider: VoiceProviderSnapshot) async throws -> Data {
        let url = try APIURLBuilder.endpoint(base: provider.baseURL, path: "/v1/audio/speech")
        let body: [String: Any] = [
            "model": provider.modelName,
            "input": text,
            "voice": provider.voiceName,
            "response_format": "wav",
        ]
        // 密钥可选（本地服务常无鉴权）
        let key = KeychainStore.load(for: provider.id) ?? ""
        let request = try HTTPSupport.jsonRequest(
            url: url,
            apiKeyHeader: (field: "Authorization", value: "Bearer \(key)"),
            body: body,
            timeout: 120
        )
        return try await send(request)
    }

    // MARK: - GPT-SoVITS api_v2 /tts

    private static func synthesizeGPTSoVITS(text: String, provider: VoiceProviderSnapshot, langCode: String) async throws -> Data {
        // api_v2 的 /tts 端点直接挂在根路径，不走 /v1 规范化
        var base = provider.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base = String(base.dropLast()) }
        guard base.lowercased().hasPrefix("http"), let url = URL(string: base + "/tts") else {
            throw AppError.invalidURL
        }
        var body: [String: Any] = [
            "text": text,
            "text_lang": langCode,
            "prompt_lang": langCode,
            "media_type": "wav",
            "streaming_mode": false,
        ]
        if !provider.refAudioPath.isEmpty {
            body["ref_audio_path"] = provider.refAudioPath
        }
        if !provider.promptText.isEmpty {
            body["prompt_text"] = provider.promptText
        }
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request)
    }

    private static func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.network
        }
        guard http.statusCode == 200 else {
            throw AppError.from(status: http.statusCode, body: String(decoding: data.prefix(2048), as: UTF8.self))
        }
        guard !data.isEmpty else {
            throw AppError.unknown("语音服务返回了空音频")
        }
        return data
    }
}
