import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selection: Conversation?

    var body: some View {
        NavigationSplitView {
            ConversationListView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            if let conversation = selection {
                ChatView(conversation: conversation)
                    .id(conversation.id) // 切换对话时重建会话状态
            } else {
                ContentUnavailableView(
                    "选择或新建一个对话",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("在左侧列表选择历史对话，或点击 + 新开对话")
                )
            }
        }
        .navigationTitle("LoveChat")
    }
}
