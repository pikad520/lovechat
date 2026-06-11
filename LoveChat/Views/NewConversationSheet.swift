import SwiftUI
import SwiftData

/// 新开对话（FR-020）：选择角色 + Chat Provider（必选），Imagine Provider 可选
struct NewConversationSheet: View {
    var onCreate: (Conversation) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CharacterCard.createdAt) private var characters: [CharacterCard]
    @Query(sort: \ChatProviderConfig.createdAt) private var chatProviders: [ChatProviderConfig]
    @Query(sort: \ImagineProviderConfig.createdAt) private var imagineProviders: [ImagineProviderConfig]

    @State private var character: CharacterCard?
    @State private var chatProvider: ChatProviderConfig?
    @State private var imagineProvider: ImagineProviderConfig?
    @AppStorage("defaultMemoryTurns") private var defaultMemoryTurns = 10
    @AppStorage("defaultCompressThreshold") private var defaultCompressThreshold = 10

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if characters.isEmpty || chatProviders.isEmpty {
                    Section {
                        Label("请先在设置（⌘,）中添加角色和 Chat Provider", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("必选") {
                    Picker("角色", selection: $character) {
                        Text("请选择").tag(nil as CharacterCard?)
                        ForEach(characters) { item in
                            Text(item.name).tag(item as CharacterCard?)
                        }
                    }
                    Picker("Chat Provider", selection: $chatProvider) {
                        Text("请选择").tag(nil as ChatProviderConfig?)
                        ForEach(chatProviders) { item in
                            Text(item.name).tag(item as ChatProviderConfig?)
                        }
                    }
                }
                Section("可选") {
                    Picker("Imagine Provider", selection: $imagineProvider) {
                        Text("不使用").tag(nil as ImagineProviderConfig?)
                        ForEach(imagineProviders) { item in
                            Text(item.name).tag(item as ImagineProviderConfig?)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("开始对话") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(character == nil || chatProvider == nil)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            if characters.count == 1 { character = characters.first }
            if chatProviders.count == 1 { chatProvider = chatProviders.first }
        }
    }

    private func create() {
        let conversation = Conversation(
            character: character,
            chatProvider: chatProvider,
            imagineProvider: imagineProvider,
            memoryTurns: min(max(defaultMemoryTurns, 1), 20),
            compressThreshold: min(max(defaultCompressThreshold, 1), 20)
        )
        context.insert(conversation)
        dismiss()
        onCreate(conversation)
    }
}
