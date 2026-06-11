import SwiftUI
import SwiftData

@main
struct LoveChatApp: App {

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChatProviderConfig.self,
            ImagineProviderConfig.self,
            CharacterCard.self,
            Conversation.self,
            ChatMessage.self,
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

        Settings {
            SettingsView()
        }
        .modelContainer(sharedModelContainer)
    }
}
