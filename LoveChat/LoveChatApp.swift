import SwiftUI
import SwiftData
import AppKit

@main
struct LoveChatApp: App {

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChatProviderConfig.self,
            ImagineProviderConfig.self,
            CharacterCard.self,
            Conversation.self,
            ChatMessage.self,
            VoiceProviderConfig.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("无法创建数据容器: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .commands {
            // 隐藏应用菜单中的「服务」子菜单
            CommandGroup(replacing: .systemServices) {}
            // About 面板：作者署名（FR-303）
            CommandGroup(replacing: .appInfo) {
                Button("关于 LoveChat") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(
                            string: "作者：pikad",
                            attributes: [.font: NSFont.systemFont(ofSize: 12)]
                        ),
                    ])
                }
            }
            // Help 菜单：中文使用指引（FR-302）
            HelpCommands()
        }

        // 使用指引窗口：重复触发只聚焦既有窗口
        Window("LoveChat 使用指引", id: "help-guide") {
            HelpGuideView()
        }
        .defaultSize(width: 640, height: 640)

        Settings {
            SettingsView()
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("LoveChat 使用指引") {
                openWindow(id: "help-guide")
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}
