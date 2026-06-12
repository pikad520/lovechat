import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 语音设置（FR-402/405/406）：开关 + 模型一键下载 + 音色/语速 + 删除
struct VoiceSettingsView: View {
    @AppStorage("voiceEnabled") private var voiceEnabled = false
    @AppStorage("voiceSid") private var voiceSid = 0
    @AppStorage("voiceSpeed") private var voiceSpeed = 1.0
    @State private var manager = VoiceModelManager.shared
    @State private var coordinator = SpeechCoordinator.shared
    private let previewID = UUID()

    var body: some View {
        Form {
            Section {
                Toggle("启用语音朗读", isOn: $voiceEnabled)
                Text("基于本地 Kokoro 模型合成，完全离线，不产生任何网络调用与费用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if voiceEnabled {
                Section("语音模型") {
                    modelStatusRow
                }

                if manager.isReady {
                    Section("音色与语速") {
                        Stepper(value: $voiceSid, in: 0...102) {
                            Text("默认音色：#\(voiceSid)")
                        }
                        Text("不同编号对应不同声线（含中文男女声），用试听找到喜欢的；角色编辑中可为角色单独指定。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("语速")
                            Slider(value: $voiceSpeed, in: 0.5...2.0, step: 0.1)
                            Text(String(format: "%.1fx", voiceSpeed))
                                .monospacedDigit()
                        }
                        Button {
                            coordinator.toggle(
                                messageID: previewID,
                                text: "你好呀，今天过得怎么样？我是你的专属聊天伙伴。",
                                voiceSid: voiceSid
                            )
                        } label: {
                            if coordinator.synthesizingMessageID == previewID {
                                Label("合成中…", systemImage: "waveform")
                            } else if coordinator.playingMessageID == previewID {
                                Label("停止", systemImage: "stop.fill")
                            } else {
                                Label("试听", systemImage: "play.fill")
                            }
                        }
                        if let error = coordinator.lastError {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var modelStatusRow: some View {
        switch manager.state {
        case .notInstalled:
            VStack(alignment: .leading, spacing: 8) {
                Label("语音模型未安装", systemImage: "arrow.down.circle")
                Text("约 \(VoiceModelManager.approximateSizeMB)MB，下载一次永久可用（来源：sherpa-onnx 官方发布）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("下载（加速镜像）") { manager.startDownload(useMirror: true) }
                        .buttonStyle(.borderedProminent)
                        .help("通过 GitHub 反代镜像下载，中国大陆网络推荐")
                    Button("下载（官方源）") { manager.startDownload() }
                    Button("导入本地模型包…") { importArchive() }
                        .help("已自行下载 kokoro-multi-lang-v1_1.tar.bz2 时使用")
                }
                Text("下载慢？可用浏览器/下载工具自行下载后点「导入本地模型包」：\n\(VoiceModelManager.modelURL.absoluteString)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        case .downloading(let progress):
            HStack {
                if progress >= 0 {
                    ProgressView(value: progress) {
                        Text("下载中… \(Int(progress * 100))%")
                    }
                } else {
                    ProgressView { Text("下载中…") }
                }
                Button("取消") { manager.cancelDownload() }
            }
        case .extracting:
            HStack {
                ProgressView().controlSize(.small)
                Text("解压安装中…")
            }
        case .ready:
            HStack {
                Label("已就绪", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(ByteCountFormatter.string(fromByteCount: manager.diskUsage, countStyle: .file))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("删除模型", role: .destructive) {
                    coordinator.stop()
                    manager.deleteModel()
                }
            }
        case .failed(let reason):
            VStack(alignment: .leading, spacing: 8) {
                Label(reason, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .lineLimit(2)
                HStack {
                    Button("重试（加速镜像）") { manager.startDownload(useMirror: true) }
                    Button("重试（官方源）") { manager.startDownload() }
                    Button("导入本地模型包…") { importArchive() }
                }
            }
        }
    }

    private func importArchive() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "bz2") ?? .archive, .archive]
        panel.allowsMultipleSelection = false
        panel.message = "选择已下载的 kokoro-multi-lang-v1_1.tar.bz2"
        if panel.runModal() == .OK, let url = panel.url {
            manager.importArchive(at: url)
        }
    }
}
