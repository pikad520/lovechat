import SwiftUI
import SwiftData

/// 卡片式历史对话列表（FR-019/020）
struct ConversationListView: View {
    @Binding var selection: Conversation?
    @Environment(\.modelContext) private var context
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @State private var showNewConversation = false

    var body: some View {
        List(selection: $selection) {
            ForEach(conversations) { conversation in
                ConversationCard(conversation: conversation)
                    .tag(conversation)
                    .contextMenu {
                        Button("删除对话", role: .destructive) {
                            delete(conversation)
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewConversation = true
                } label: {
                    Label("新对话", systemImage: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showNewConversation) {
            NewConversationSheet { conversation in
                selection = conversation
            }
        }
        .safeAreaInset(edge: .bottom) {
            // 左下角设置入口，兼容 Windows 用户操作习惯（FR-301）
            HStack {
                SettingsLink {
                    Label("设置", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("打开设置（⌘,）")
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .overlay {
            if conversations.isEmpty {
                ContentUnavailableView(
                    "还没有对话",
                    systemImage: "heart.text.square",
                    description: Text("点击右上角 + 新开一个对话\n（需要先在设置 ⌘, 中配置 Provider 和角色）")
                )
            }
        }
    }

    private func delete(_ conversation: Conversation) {
        // 先清理关联图片文件，再级联删除（data-model 校验规则）
        for message in conversation.messages {
            if let fileName = message.imageFileName {
                ImageStore.delete(fileName)
            }
        }
        if selection == conversation {
            selection = nil
        }
        context.delete(conversation)
    }
}

private struct ConversationCard: View {
    let conversation: Conversation

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CharacterAvatarView(fileName: conversation.character?.avatarFileName, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.character?.name ?? "（角色已删除）")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(conversation.updatedAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(conversation.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let last = conversation.sortedMessages.last(where: { $0.role != .systemNotice }) {
                    Text(last.text)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
