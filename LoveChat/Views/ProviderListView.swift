import SwiftUI
import SwiftData

/// Provider 管理（FR-001/002/003/004）
struct ProviderListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ChatProviderConfig.createdAt) private var chatProviders: [ChatProviderConfig]
    @Query(sort: \ImagineProviderConfig.createdAt) private var imagineProviders: [ImagineProviderConfig]
    @State private var editingChatProvider: ChatProviderConfig?
    @State private var editingImagineProvider: ImagineProviderConfig?
    @State private var showNewChatProvider = false
    @State private var showNewImagineProvider = false

    var body: some View {
        List {
            Section {
                ForEach(chatProviders) { provider in
                    row(name: provider.name, detail: "\(provider.protocolType.displayName) · \(provider.modelName)")
                        .contentShape(Rectangle())
                        .onTapGesture { editingChatProvider = provider }
                        .contextMenu {
                            Button("编辑") { editingChatProvider = provider }
                            Button("删除", role: .destructive) { delete(provider) }
                        }
                }
            } header: {
                HStack {
                    Text("AI Chat Provider")
                    Spacer()
                    Button {
                        showNewChatProvider = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Section {
                ForEach(imagineProviders) { provider in
                    row(name: provider.name, detail: "Images API · \(provider.modelName)")
                        .contentShape(Rectangle())
                        .onTapGesture { editingImagineProvider = provider }
                        .contextMenu {
                            Button("编辑") { editingImagineProvider = provider }
                            Button("删除", role: .destructive) { delete(provider) }
                        }
                }
            } header: {
                HStack {
                    Text("AI Imagine Provider")
                    Spacer()
                    Button {
                        showNewImagineProvider = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .sheet(item: $editingChatProvider) { provider in
            ChatProviderEditView(provider: provider, isNew: false)
        }
        .sheet(isPresented: $showNewChatProvider) {
            ChatProviderEditView(provider: ChatProviderConfig(), isNew: true)
        }
        .sheet(item: $editingImagineProvider) { provider in
            ImagineProviderEditView(provider: provider, isNew: false)
        }
        .sheet(isPresented: $showNewImagineProvider) {
            ImagineProviderEditView(provider: ImagineProviderConfig(), isNew: true)
        }
    }

    private func row(name: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name.isEmpty ? "（未命名）" : name)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func delete(_ provider: ChatProviderConfig) {
        KeychainStore.delete(for: provider.id) // 同步清理密钥（宪法 III）
        context.delete(provider)
    }

    private func delete(_ provider: ImagineProviderConfig) {
        KeychainStore.delete(for: provider.id)
        context.delete(provider)
    }
}
