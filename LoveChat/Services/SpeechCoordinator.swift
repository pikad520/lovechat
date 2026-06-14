import Foundation
import AVFoundation
import Observation

/// 朗读协调器（FR-404）：同一时刻仅一路播放；合成在 SpeechSynthesizer actor 内
/// 后台执行；任何失败仅置错误态，不影响文字对话（宪法 V）。
@MainActor
@Observable
final class SpeechCoordinator: NSObject, AVAudioPlayerDelegate {
    static let shared = SpeechCoordinator()

    /// 正在合成的消息
    private(set) var synthesizingMessageID: UUID?
    /// 正在播放的消息
    private(set) var playingMessageID: UUID?
    private(set) var lastError: String?

    private var player: AVAudioPlayer?
    private var speakTask: Task<Void, Never>?

    var isVoiceEnabled: Bool {
        UserDefaults.standard.bool(forKey: "voiceEnabled")
    }

    /// 全局默认音色编号（#3 为实测优选的出厂默认，与 VoiceSettingsView 保持一致）
    var globalVoiceSid: Int {
        UserDefaults.standard.object(forKey: "voiceSid") as? Int ?? 3
    }

    var globalSpeed: Float {
        UserDefaults.standard.object(forKey: "voiceSpeed") as? Float ?? 1.0
    }

    /// 外接服务分句流式播放开关（默认开，FR-501）
    var chunkedStreamingEnabled: Bool {
        UserDefaults.standard.object(forKey: "voiceChunkedStreaming") as? Bool ?? true
    }

    /// 分句流式专用的逐段播放器
    private let clipPlayer = ClipPlayer()

    // MARK: - 入口

    /// 播放/停止切换（消息气泡 🔊）
    func toggle(messageID: UUID, text: String, voiceSid: Int?, external: VoiceProviderSnapshot? = nil, language: CharacterLanguage = .chinese) {
        if playingMessageID == messageID || synthesizingMessageID == messageID {
            stop()
            return
        }
        speak(messageID: messageID, text: text, voiceSid: voiceSid, external: external, language: language)
    }

    /// 自动朗读入口（角色回复完成时调用）；未开启/不可用时静默忽略
    func autoSpeakIfEnabled(messageID: UUID, text: String, voiceSid: Int?, external: VoiceProviderSnapshot? = nil, language: CharacterLanguage = .chinese) {
        guard isVoiceEnabled, external != nil || VoiceModelManager.shared.isReady else { return }
        speak(messageID: messageID, text: text, voiceSid: voiceSid, external: external, language: language)
    }

    func stop() {
        speakTask?.cancel()
        speakTask = nil
        player?.stop()
        player = nil
        clipPlayer.stop()
        playingMessageID = nil
        synthesizingMessageID = nil
    }

    // MARK: - 实现

    private func speak(messageID: UUID, text: String, voiceSid: Int?, external: VoiceProviderSnapshot?, language: CharacterLanguage) {
        stop()
        guard isVoiceEnabled, external != nil || VoiceModelManager.shared.isReady else { return }

        // 朗读跳过心理活动括号内容（FR-404）
        let spokenText = Self.speakableText(from: text)
        guard !spokenText.isEmpty else { return }

        let sid = (voiceSid ?? -1) >= 0 ? voiceSid! : globalVoiceSid
        let speed = globalSpeed
        lastError = nil
        synthesizingMessageID = messageID

        // 外接服务 + 开关开启 → 分句流式；否则整段一次性播放（FR-501）
        if external != nil && chunkedStreamingEnabled {
            speakChunked(messageID: messageID, text: spokenText, sid: sid, speed: speed, external: external, language: language)
        } else {
            speakOneShot(messageID: messageID, text: spokenText, sid: sid, speed: speed, external: external, language: language)
        }
    }

    /// 整段合成后一次性播放（Kokoro，或外接·开关关闭）
    private func speakOneShot(messageID: UUID, text: String, sid: Int, speed: Float, external: VoiceProviderSnapshot?, language: CharacterLanguage) {
        speakTask = Task { [weak self] in
            do {
                let wav = try await Self.synthesizeAudio(text: text, sid: sid, speed: speed, external: external, language: language)
                try Task.checkCancellation()
                guard let self else { return }
                let player = try AVAudioPlayer(data: wav)
                player.delegate = self
                self.player = player
                self.synthesizingMessageID = nil
                self.playingMessageID = messageID
                player.play()
            } catch is CancellationError {
                self?.synthesizingMessageID = nil
            } catch {
                guard let self else { return }
                self.synthesizingMessageID = nil
                self.lastError = AppError.wrap(error).userMessage
            }
        }
    }

    /// 分句流式：逐句合成、首句就绪即播，生产者后台预取后续句（FR-502/503）
    private func speakChunked(messageID: UUID, text: String, sid: Int, speed: Float, external: VoiceProviderSnapshot?, language: CharacterLanguage) {
        let sentences = Self.splitSentences(text)
        guard !sentences.isEmpty else {
            synthesizingMessageID = nil
            return
        }
        speakTask = Task { [weak self] in
            guard let self else { return }
            // 生产者：按序合成各句并放入缓冲（AsyncStream 默认无界，自然预取）
            let stream = AsyncStream<Data> { continuation in
                let producer = Task {
                    for sentence in sentences {
                        if Task.isCancelled { break }
                        do {
                            let data = try await Self.synthesizeAudio(text: sentence, sid: sid, speed: speed, external: external, language: language)
                            continuation.yield(data)
                        } catch {
                            await MainActor.run { self.lastError = AppError.wrap(error).userMessage }
                            break
                        }
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in producer.cancel() }
            }
            // 消费者：顺序播放，首段起播即切换状态
            var started = false
            for await data in stream {
                if Task.isCancelled { break }
                if !started {
                    self.synthesizingMessageID = nil
                    self.playingMessageID = messageID
                    started = true
                }
                await self.clipPlayer.play(data)
                if Task.isCancelled { break }
            }
            self.playingMessageID = nil
            self.synthesizingMessageID = nil
        }
    }

    /// 按句末标点切分；过短片段并入相邻句，避免碎片化（FR-504）
    static func splitSentences(_ text: String) -> [String] {
        let enders: Set<Character> = ["。", "！", "？", "!", "?", "…", "\n", "；", ";"]
        var parts: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if enders.contains(ch) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { parts.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { parts.append(tail) }

        var merged: [String] = []
        for part in parts {
            if let last = merged.last, last.count < 8 {
                merged[merged.count - 1] = last + part
            } else {
                merged.append(part)
            }
        }
        return merged
    }

    /// 外接优先，失败回退内置（FR-408）；纯内置路径直接合成
    private static func synthesizeAudio(text: String, sid: Int, speed: Float, external: VoiceProviderSnapshot?, language: CharacterLanguage) async throws -> Data {
        if let external {
            do {
                return try await ExternalVoiceClient.synthesize(text: text, provider: external, langCode: language.langCode)
            } catch {
                guard VoiceModelManager.isModelReady else { throw error }
                // 外接不可达 → 回退内置引擎
            }
        }
        let (samples, sampleRate) = try await SpeechSynthesizer.shared
            .synthesize(text: text, sid: sid, speed: speed, lang: language.langCode)
        return WaveEncoder.wavData(samples: samples, sampleRate: sampleRate)
    }

    /// 过滤心理活动段，仅朗读正文
    static func speakableText(from text: String) -> String {
        ThoughtParser.parse(text).compactMap { segment in
            if case .normal(let content) = segment {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            return nil
        }
        .joined(separator: " ")
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.playingMessageID = nil
            self?.player = nil
        }
    }
}

/// 分句流式专用：播放单段音频并在播完（或被停止）后返回，用于顺序衔接。
@MainActor
private final class ClipPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Never>?

    func play(_ data: Data) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            continuation = cont
            do {
                let p = try AVAudioPlayer(data: data)
                p.delegate = self
                player = p
                p.play()
            } catch {
                finish()
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        finish()
    }

    /// 恢复等待中的 continuation（幂等：停止与自然播完都可能触发）
    private func finish() {
        continuation?.resume()
        continuation = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.finish()
        }
    }
}
