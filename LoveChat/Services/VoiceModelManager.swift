import Foundation
import Observation

/// 内置语音模型的检测/下载/解压/删除（FR-402/406）。
/// 模型不随安装包分发，仅在用户显式触发时下载。
@MainActor
@Observable
final class VoiceModelManager {
    static let shared = VoiceModelManager()

    enum State: Equatable {
        case notInstalled
        case downloading(progress: Double) // 0...1，未知总量时为 -1
        case extracting
        case ready
        case failed(String)
    }

    private(set) var state: State = .notInstalled
    private var downloadTask: Task<Void, Never>?

    /// kokoro 多语言模型包（含中文音色），sherpa-onnx 官方托管
    nonisolated static let modelURL = URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_1.tar.bz2")!
    /// 加速镜像（GitHub 反代，中国大陆网络推荐）
    nonisolated static let mirrorURL = URL(string: "https://ghfast.top/https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-multi-lang-v1_1.tar.bz2")!
    nonisolated static let modelDirName = "kokoro-multi-lang-v1_1"
    nonisolated static let approximateSizeMB = 320

    nonisolated static var ttsRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LoveChat/TTS", isDirectory: true)
    }

    nonisolated static var modelDir: URL {
        ttsRoot.appendingPathComponent(modelDirName, isDirectory: true)
    }

    private init() {
        state = Self.isModelReady ? .ready : .notInstalled
    }

    /// 就绪判定：核心三件套存在
    nonisolated static var isModelReady: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: modelDir.appendingPathComponent("model.onnx").path)
            && fm.fileExists(atPath: modelDir.appendingPathComponent("voices.bin").path)
            && fm.fileExists(atPath: modelDir.appendingPathComponent("tokens.txt").path)
    }

    var isReady: Bool { state == .ready }

    /// 模型占用（字节），未安装为 0
    var diskUsage: Int64 {
        guard Self.isModelReady else { return 0 }
        let fm = FileManager.default
        guard let files = fm.enumerator(at: Self.modelDir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in files {
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    // MARK: - 下载

    func startDownload(useMirror: Bool = false) {
        guard downloadTask == nil else { return }
        state = .downloading(progress: 0)
        let url = useMirror ? Self.mirrorURL : Self.modelURL
        downloadTask = Task { [weak self] in
            await self?.runDownload(from: url)
            self?.downloadTask = nil
        }
    }

    /// 导入用户自行下载的模型包（kokoro-multi-lang-v1_1.tar.bz2）
    func importArchive(at url: URL) {
        guard downloadTask == nil else { return }
        state = .extracting
        Task { [weak self] in
            do {
                try FileManager.default.createDirectory(at: Self.ttsRoot, withIntermediateDirectories: true)
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                try await Self.extract(archive: url, to: Self.ttsRoot)
                guard Self.isModelReady else {
                    throw AppError.unknown("文件不完整或不是 kokoro-multi-lang-v1_1 模型包")
                }
                self?.state = .ready
            } catch {
                self?.cleanupPartial()
                self?.state = .failed(AppError.wrap(error).userMessage)
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        cleanupPartial()
        state = .notInstalled
    }

    private func runDownload(from url: URL) async {
        let fm = FileManager.default
        let archive = Self.ttsRoot.appendingPathComponent("model-download.tar.bz2")
        do {
            try fm.createDirectory(at: Self.ttsRoot, withIntermediateDirectories: true)
            fm.createFile(atPath: archive.path, contents: nil)
            let handle = try FileHandle(forWritingTo: archive)
            defer { try? handle.close() }

            let (bytes, response) = try await URLSession.shared.bytes(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw AppError.network
            }
            let total = http.expectedContentLength // -1 表示未知
            var received: Int64 = 0
            var buffer = Data()
            buffer.reserveCapacity(1 << 20)
            var lastReported: Double = 0

            for try await byte in bytes {
                buffer.append(byte)
                if buffer.count >= 1 << 20 {
                    try Task.checkCancellation()
                    try handle.write(contentsOf: buffer)
                    received += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    if total > 0 {
                        let progress = Double(received) / Double(total)
                        if progress - lastReported >= 0.01 {
                            lastReported = progress
                            state = .downloading(progress: progress)
                        }
                    } else {
                        state = .downloading(progress: -1)
                    }
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
            }
            try? handle.close()

            // 解压（/usr/bin/tar 为系统平台二进制，沙箱内可执行）
            state = .extracting
            try await Self.extract(archive: archive, to: Self.ttsRoot)
            try? fm.removeItem(at: archive)

            guard Self.isModelReady else {
                throw AppError.unknown("模型文件不完整")
            }
            state = .ready
        } catch is CancellationError {
            cleanupPartial()
            state = .notInstalled
        } catch {
            cleanupPartial()
            state = .failed(AppError.wrap(error).userMessage)
        }
    }

    private nonisolated static func extract(archive: URL, to dir: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            process.arguments = ["-xjf", archive.path, "-C", dir.path]
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AppError.unknown("模型解压失败（tar \(proc.terminationStatus)）"))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func cleanupPartial() {
        let fm = FileManager.default
        try? fm.removeItem(at: Self.ttsRoot.appendingPathComponent("model-download.tar.bz2"))
        if !Self.isModelReady {
            try? fm.removeItem(at: Self.modelDir)
        }
    }

    // MARK: - 删除（FR-406）

    func deleteModel() {
        Task { await SpeechSynthesizer.shared.unload() }
        try? FileManager.default.removeItem(at: Self.modelDir)
        state = .notInstalled
    }
}
