import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct ChatView: View {
    @Bindable var conversation: Conversation
    @Environment(\.modelContext) private var context
    @State private var viewModel = ChatSessionViewModel()
    @State private var draft = ""
    @State private var narrationDraft = ""
    @State private var editingMessage: ChatMessage?
    @State private var showConversationSettings = false

    private var sortedMessages: [ChatMessage] {
        conversation.sortedMessages
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            inputBar
        }
        .navigationTitle(conversation.title)
        .navigationSubtitle(conversation.character?.name ?? "角色已删除")
        .toolbar {
            ToolbarItem {
                Button {
                    exportMarkdown()
                } label: {
                    Label("导出 Markdown", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem {
                Button {
                    showConversationSettings = true
                } label: {
                    Label("对话设置", systemImage: "slider.horizontal.3")
                }
            }
        }
        .sheet(item: $editingMessage) { message in
            MessageEditSheet(message: message)
        }
        .sheet(isPresented: $showConversationSettings) {
            ConversationSettingsSheet(conversation: conversation)
        }
    }

    // MARK: - 消息流

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sortedMessages) { message in
                        MessageBubbleView(
                            message: message,
                            characterName: conversation.character?.name ?? "角色",
                            avatarFileName: conversation.character?.avatarFileName,
                            parseThoughts: conversation.character?.showInnerThoughts ?? false,
                            onRetry: message.role == .systemNotice ? {
                                viewModel.retry(in: conversation, context: context)
                            } : nil
                        )
                        .contextMenu { contextMenu(for: message) }
                        .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: sortedMessages.last?.text) {
                if let lastID = sortedMessages.last?.id {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .onChange(of: sortedMessages.count) {
                if let lastID = sortedMessages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for message: ChatMessage) -> some View {
        if message.role != .systemNotice {
            Button("编辑") { editingMessage = message }
            Button("删除", role: .destructive) { delete(message) }
        }
        if message.role == .assistant, message.id == lastAssistantMessageID, !viewModel.isStreaming {
            Button("重新生成") {
                viewModel.regenerate(in: conversation, context: context)
            }
        }
    }

    private var lastAssistantMessageID: UUID? {
        sortedMessages.last(where: { $0.role == .assistant })?.id
    }

    private func delete(_ message: ChatMessage) {
        if let fileName = message.imageFileName {
            ImageStore.delete(fileName)
        }
        context.delete(message)
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        VStack(spacing: 6) {
            // 旁白输入框：非必填，描述场景/情节（FR-104）
            HStack(spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField("旁白（可选）：描述场景或情节，如「夜晚，两人走在江边」", text: $narrationDraft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .lineLimit(1...3)
                    .disabled(viewModel.isStreaming)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))

            mainInputRow
        }
        .padding(10)
    }

    private var mainInputRow: some View {
        HStack(spacing: 8) {
            TextField("说点什么…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                .onSubmit { sendDraft() }
                .disabled(viewModel.isStreaming)

            if viewModel.isStreaming {
                Button {
                    viewModel.stop()
                } label: {
                    Label("停止", systemImage: "stop.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help("停止生成")
            } else {
                Button {
                    sendDraft()
                } label: {
                    Label("发送", systemImage: "arrow.up.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("发送")
            }
        }
    }

    private func sendDraft() {
        let text = draft
        let narration = narrationDraft
        draft = ""
        narrationDraft = ""
        viewModel.send(text: text, narration: narration, in: conversation, context: context)
    }

    // MARK: - 导出（FR-021）

    private func exportMarkdown() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = conversation.title + ".md"
        if panel.runModal() == .OK, let url = panel.url {
            let markdown = MarkdownExporter.export(conversation)
            try? markdown.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - 消息编辑（FR-009）

private struct MessageEditSheet: View {
    @Bindable var message: ChatMessage
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("编辑消息").font(.headline)
            TextEditor(text: $text)
                .font(.body)
                .frame(minWidth: 360, minHeight: 160)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") {
                    message.text = text
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .onAppear { text = message.text }
    }
}

// MARK: - 对话设置（FR-015/016 + T023 重新关联）

private struct ConversationSettingsSheet: View {
    @Bindable var conversation: Conversation
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CharacterCard.createdAt) private var characters: [CharacterCard]
    @Query(sort: \ChatProviderConfig.createdAt) private var chatProviders: [ChatProviderConfig]
    @Query(sort: \ImagineProviderConfig.createdAt) private var imagineProviders: [ImagineProviderConfig]

    var body: some View {
        Form {
            Section("记忆") {
                Stepper(value: $conversation.memoryTurns, in: 1...20) {
                    Text("记忆对话轮数：\(conversation.memoryTurns)")
                }
                .onChange(of: conversation.memoryTurns) {
                    // 压缩阈值 ≤ 记忆轮数，UI 强制（FR-016）
                    if conversation.compressThreshold > conversation.memoryTurns {
                        conversation.compressThreshold = conversation.memoryTurns
                    }
                }
                Stepper(value: $conversation.compressThreshold, in: 1...conversation.memoryTurns) {
                    Text("压缩阈值（滑出 \(conversation.compressThreshold) 轮后压缩）")
                }
            }
            Section("关联") {
                Picker("角色", selection: $conversation.character) {
                    Text("未选择").tag(nil as CharacterCard?)
                    ForEach(characters) { character in
                        Text(character.name).tag(character as CharacterCard?)
                    }
                }
                Picker("Chat Provider", selection: $conversation.chatProvider) {
                    Text("未选择").tag(nil as ChatProviderConfig?)
                    ForEach(chatProviders) { provider in
                        Text(provider.name).tag(provider as ChatProviderConfig?)
                    }
                }
                Picker("Imagine Provider（可选）", selection: $conversation.imagineProvider) {
                    Text("不使用").tag(nil as ImagineProviderConfig?)
                    ForEach(imagineProviders) { provider in
                        Text(provider.name).tag(provider as ImagineProviderConfig?)
                    }
                }
            }
            if !conversation.memorySummary.isEmpty {
                Section("当前记忆摘要") {
                    Text(conversation.memorySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 360)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
}
