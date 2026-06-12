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

    // MARK: - 入口

    /// 播放/停止切换（消息气泡 🔊）
    func toggle(messageID: UUID, text: String, voiceSid: Int?) {
        if playingMessageID == messageID || synthesizingMessageID == messageID {
            stop()
            return
        }
        speak(messageID: messageID, text: text, voiceSid: voiceSid)
    }

    /// 自动朗读入口（角色回复完成时调用）；未开启/未就绪时静默忽略
    func autoSpeakIfEnabled(messageID: UUID, text: String, voiceSid: Int?) {
        guard isVoiceEnabled, VoiceModelManager.shared.isReady else { return }
        speak(messageID: messageID, text: text, voiceSid: voiceSid)
    }

    func stop() {
        speakTask?.cancel()
        speakTask = nil
        player?.stop()
        player = nil
        playingMessageID = nil
        synthesizingMessageID = nil
    }

    // MARK: - 实现

    private func speak(messageID: UUID, text: String, voiceSid: Int?) {
        stop()
        guard isVoiceEnabled, VoiceModelManager.shared.isReady else { return }

        // 朗读跳过心理活动括号内容（FR-404）
        let spokenText = Self.speakableText(from: text)
        guard !spokenText.isEmpty else { return }

        let sid = (voiceSid ?? -1) >= 0 ? voiceSid! : globalVoiceSid
        let speed = globalSpeed
        lastError = nil
        synthesizingMessageID = messageID

        speakTask = Task { [weak self] in
            do {
                let (samples, sampleRate) = try await SpeechSynthesizer.shared
                    .synthesize(text: spokenText, sid: sid, speed: speed)
                try Task.checkCancellation()
                guard let self else { return }
                let wav = WaveEncoder.wavData(samples: samples, sampleRate: sampleRate)
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
