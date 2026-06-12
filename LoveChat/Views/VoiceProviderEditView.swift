import SwiftUI
import SwiftData

/// 外接语音服务编辑（FR-407）
struct VoiceProviderEditView: View {
    @Bindable var provider: VoiceProviderConfig
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var testState: TestState = .idle

    private enum TestState: Equatable {
        case idle, testing, success
        case failure(String)
    }

    private var isValid: Bool {
        !provider.name.trimmingCharacters(in: .whitespaces).isEmpty
            && provider.baseURL.lowercased().hasPrefix("http")
            && (provider.protocolType == .openAICompatible || !provider.refAudioPath.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $provider.name, prompt: Text("如 我的 GPT-SoVITS"))
                    Picker("协议", selection: $provider.protocolType) {
                        ForEach(VoiceProtocol.allCases, id: \.self) { proto in
                            Text(proto.displayName).tag(proto)
                        }
                    }
                    TextField("服务地址", text: $provider.baseURL, prompt: Text(
                        provider.protocolType == .gptSoVITS ? "http://127.0.0.1:9880" : "https://api.openai.com/v1"
                    ))
                }
                switch provider.protocolType {
                case .openAICompatible:
                    Section("OpenAI 兼容参数") {
                        TextField("模型名", text: $provider.modelName, prompt: Text("tts-1"))
                        TextField("音色名", text: $provider.voiceName, prompt: Text("alloy"))
                        SecureField("API Key（可选，本地服务常无需）", text: $apiKey)
                    }
                case .gptSoVITS:
                    Section("GPT-SoVITS 参数（api_v2）") {
                        TextField("参考音频路径（服务端路径，必填）", text: $provider.refAudioPath, prompt: Text("/path/to/ref.wav"))
                        TextField("参考音频文本", text: $provider.promptText, prompt: Text("参考音频里说的话"))
                        Text("参考音频决定克隆出的音色：在部署 GPT-SoVITS 的机器上放一段 3–10 秒的清晰人声，填它的路径与对应文本。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section {
                    HStack {
                        Button("测试连接") { testConnection() }
                            .disabled(!isValid || testState == .testing)
                        switch testState {
                        case .idle:
                            EmptyView()
                        case .testing:
                            ProgressView().controlSize(.small)
                        case .success:
                            Label("连接成功", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let reason):
                            Label(reason, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button(isNew ? "添加" : "保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 420)
        .onAppear {
            if !isNew {
                apiKey = KeychainStore.load(for: provider.id) ?? ""
            }
        }
    }

    private func save() {
        if !apiKey.isEmpty {
            KeychainStore.save(key: apiKey, for: provider.id)
        }
        if isNew {
            context.insert(provider)
        }
        dismiss()
    }

    private func testConnection() {
        testState = .testing
        if !apiKey.isEmpty {
            KeychainStore.save(key: apiKey, for: provider.id)
        }
        let snapshot = VoiceProviderSnapshot(provider)
        Task {
            do {
                try await ExternalVoiceClient.testConnection(provider: snapshot)
                testState = .success
            } catch {
                testState = .failure(AppError.wrap(error).userMessage)
            }
            if isNew, apiKey.isEmpty == false, testState != .success {
                KeychainStore.delete(for: provider.id)
            }
        }
    }
}
