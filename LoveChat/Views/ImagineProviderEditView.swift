import SwiftUI
import SwiftData

/// Imagine Provider 编辑（FR-002/003）
struct ImagineProviderEditView: View {
    @Bindable var provider: ImagineProviderConfig
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""

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
                    TextField("名称", text: $provider.name, prompt: Text("如 我的生图服务"))
                    TextField("Base URL", text: $provider.baseURL, prompt: Text("https://api.openai.com/v1"))
                    SecureField("API Key", text: $apiKey, prompt: Text("sk-…"))
                    TextField("模型名", text: $provider.modelName, prompt: Text("如 dall-e-3"))
                }
                Section {
                    Text("使用 OpenAI 标准 Images API。生成的图片会立即下载保存到本地。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .frame(minWidth: 460, minHeight: 320)
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
}
