import SwiftUI
import SwiftData

/// Chat Provider 编辑（FR-001/003/004/005）。
/// API Key 只走 Keychain：表单内存中暂存，保存时写入，绝不入 SwiftData。
struct ChatProviderEditView: View {
    @Bindable var provider: ChatProviderConfig
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var testState: TestState = .idle

    private enum TestState: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    private var isValid: Bool {
        !provider.name.trimmingCharacters(in: .whitespaces).isEmpty
            && URL(string: provider.baseURL) != nil
            && !provider.baseURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !provider.modelName.trimmingCharacters(in: .whitespaces).isEmpty
            && !apiKey.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $provider.name, prompt: Text("如 我的 OpenAI"))
                    TextField("Base URL", text: $provider.baseURL, prompt: Text("https://api.openai.com/v1"))
                    SecureField("API Key", text: $apiKey, prompt: Text("sk-…"))
                    TextField("模型名", text: $provider.modelName, prompt: Text("如 gpt-4o"))
                    Picker("协议类型", selection: $provider.protocolType) {
                        ForEach(APIProtocol.allCases, id: \.self) { proto in
                            Text(proto.displayName).tag(proto)
                        }
                    }
                }
                Section("高级") {
                    Toggle("思考模式", isOn: $provider.thinkingEnabled)
                    Text("Anthropic → extended thinking；OpenAI → reasoning effort。模型不支持时自动静默忽略。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    HStack {
                        Button("测试连接") {
                            testConnection()
                        }
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
        .frame(minWidth: 460, minHeight: 420)
        .onAppear {
            if !isNew {
                apiKey = KeychainStore.load(for: provider.id) ?? ""
            }
        }
    }

    private func save() {
        KeychainStore.save(key: apiKey, for: provider.id)
        if isNew {
            context.insert(provider)
        }
        dismiss()
    }

    private func testConnection() {
        testState = .testing
        // 用当前表单值测试（可能尚未保存）
        KeychainStore.save(key: apiKey, for: provider.id)
        let snapshot = ChatProviderSnapshot(provider)
        Task {
            do {
                try await ChatService.testConnection(provider: snapshot)
                testState = .success
            } catch {
                testState = .failure(AppError.wrap(error).userMessage)
            }
            // 新建未保存时不留下孤儿密钥
            if isNew {
                KeychainStore.delete(for: provider.id)
            }
        }
    }
}
