import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// 语音设置（FR-402/405/406）：开关 + 模型一键下载 + 音色/语速 + 删除
struct VoiceSettingsView: View {
    @AppStorage("voiceEnabled") private var voiceEnabled = false
    @AppStorage("voiceSid") private var voiceSid = 3 // 实测 #3 中文效果出色，作为出厂默认
    @AppStorage("voiceSpeed") private var voiceSpeed = 1.0
    @AppStorage("voiceChunkedStreaming") private var chunkedStreaming = true
    @State private var manager = VoiceModelManager.shared
    @State private var coordinator = SpeechCoordinator.shared
    @Environment(\.modelContext) private var context
    @Query(sort: \VoiceProviderConfig.createdAt) private var voiceProviders: [VoiceProviderConfig]
    @State private var editingProvider: VoiceProviderConfig?
    @State private var showNewProvider = false
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

                Section {
                    ForEach(voiceProviders) { provider in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.name.isEmpty ? "（未命名）" : provider.name)
                                Text(provider.protocolType.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingProvider = provider }
                        .contextMenu {
                            Button("编辑") { editingProvider = provider }
                            Button("删除", role: .destructive) {
                                KeychainStore.delete(for: provider.id)
                                context.delete(provider)
                            }
                        }
                    }
                    if voiceProviders.isEmpty {
                        Text("可外接自部署的 GPT-SoVITS（克隆专属声线）或任意 OpenAI 兼容 TTS 服务；在角色编辑中绑定后生效，失败自动回退内置引擎。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Toggle("分句流式播放", isOn: $chunkedStreaming)
                        Text("仅对外接服务生效。开启：长回复按句即时合成、首句更快出声；关闭：整段合成完一次性播放。引擎较慢（如 GPT-SoVITS）时建议开启。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text("外接语音服务（进阶，可选）")
                        Spacer()
                        Button {
                            showNewProvider = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderless)
                    }
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
        .sheet(item: $editingProvider) { provider in
            VoiceProviderEditView(provider: provider, isNew: false)
        }
        .sheet(isPresented: $showNewProvider) {
            VoiceProviderEditView(provider: VoiceProviderConfig(), isNew: true)
        }
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
