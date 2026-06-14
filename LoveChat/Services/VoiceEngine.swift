import Foundation

/// sherpa-onnx 的唯一接触点（宪法 II 豁免条款：封装必须隔离在独立服务层）。
/// actor 串行化推理调用；推理为 CPU 密集，绝不在主线程进行。
actor SpeechSynthesizer {
    static let shared = SpeechSynthesizer()

    private var tts: OpaquePointer?
    /// 当前已加载模型的语种提示；语种变化时重载
    private var loadedLang: String?

    /// 保存传给 C 配置的字符串副本，生命周期随引擎
    private var configStrings: [UnsafeMutablePointer<CChar>] = []

    private func keep(_ s: String) -> UnsafePointer<CChar>? {
        guard let p = strdup(s) else { return nil }
        configStrings.append(p)
        return UnsafePointer(p)
    }

    var isLoaded: Bool { tts != nil }

    var numSpeakers: Int {
        guard let tts else { return 0 }
        return Int(SherpaOnnxOfflineTtsNumSpeakers(tts))
    }

    /// 加载模型（幂等）；语种变化时重载。失败抛错，由调用方降级处理（宪法 V）。
    func ensureLoaded(lang: String) throws {
        if tts != nil, loadedLang == lang { return }
        if tts != nil { unload() }
        let dir = VoiceModelManager.modelDir
        let fm = FileManager.default

        func path(_ name: String) -> String {
            dir.appendingPathComponent(name).path
        }
        func existing(_ name: String) -> String? {
            fm.fileExists(atPath: path(name)) ? path(name) : nil
        }

        var config = SherpaOnnxOfflineTtsConfig()
        config.model.kokoro.model = keep(path("model.onnx"))
        config.model.kokoro.voices = keep(path("voices.bin"))
        config.model.kokoro.tokens = keep(path("tokens.txt"))
        if let dataDir = existing("espeak-ng-data") {
            config.model.kokoro.data_dir = keep(dataDir)
        }
        if let dictDir = existing("dict") {
            config.model.kokoro.dict_dir = keep(dictDir)
        }
        // 中英双语词典（存在才加入）
        let lexicons = ["lexicon-zh.txt", "lexicon-us-en.txt"].compactMap(existing)
        if !lexicons.isEmpty {
            config.model.kokoro.lexicon = keep(lexicons.joined(separator: ","))
        }
        config.model.kokoro.lang = keep(lang)
        config.model.kokoro.length_scale = 1.0
        config.model.num_threads = 2
        config.model.provider = keep("cpu")
        config.model.debug = 0
        // 中文数字/日期/电话号码朗读规则（存在才加入）
        let fsts = ["date-zh.fst", "number-zh.fst", "phone-zh.fst"].compactMap(existing)
        if !fsts.isEmpty {
            config.rule_fsts = keep(fsts.joined(separator: ","))
        }
        config.max_num_sentences = 1

        guard let handle = SherpaOnnxCreateOfflineTts(&config) else {
            unload()
            throw AppError.unknown("语音模型加载失败，请尝试重新下载模型")
        }
        tts = handle
        loadedLang = lang
    }

    /// 文本 → 单声道 PCM 浮点采样
    func synthesize(text: String, sid: Int, speed: Float, lang: String) throws -> (samples: [Float], sampleRate: Int) {
        try ensureLoaded(lang: lang)
        guard let tts else {
            throw AppError.unknown("语音引擎未就绪")
        }
        let clampedSid = Int32(max(0, min(sid, numSpeakers - 1)))
        guard let audio = SherpaOnnxOfflineTtsGenerate(tts, text, clampedSid, speed) else {
            throw AppError.unknown("语音合成失败")
        }
        defer { SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio) }
        let count = Int(audio.pointee.n)
        let sampleRate = Int(audio.pointee.sample_rate)
        guard count > 0, let samplesPtr = audio.pointee.samples else {
            throw AppError.unknown("语音合成结果为空")
        }
        let samples = Array(UnsafeBufferPointer(start: samplesPtr, count: count))
        return (samples, sampleRate)
    }

    func unload() {
        if let tts {
            SherpaOnnxDestroyOfflineTts(tts)
        }
        tts = nil
        loadedLang = nil
        configStrings.forEach { free($0) }
        configStrings.removeAll()
    }
}

// MARK: - WAV 封装（16-bit PCM，供 AVAudioPlayer 播放）

enum WaveEncoder {
    static func wavData(samples: [Float], sampleRate: Int) -> Data {
        var pcm = Data(capacity: samples.count * 2)
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            var value = Int16(clamped * 32767.0)
            withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
        }
        var data = Data()
        func append(_ string: String) { data.append(contentsOf: string.utf8) }
        func append32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        func append16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }

        append("RIFF")
        append32(UInt32(36 + pcm.count))
        append("WAVE")
        append("fmt ")
        append32(16)
        append16(1) // PCM
        append16(1) // mono
        append32(UInt32(sampleRate))
        append32(UInt32(sampleRate * 2)) // byte rate
        append16(2) // block align
        append16(16) // bits
        append("data")
        append32(UInt32(pcm.count))
        data.append(pcm)
        return data
    }
}
