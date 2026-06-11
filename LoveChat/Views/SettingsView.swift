import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            ProviderListView()
                .tabItem { Label("Provider", systemImage: "server.rack") }
            CharacterListView()
                .tabItem { Label("角色", systemImage: "person.2") }
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }
        }
        .frame(minWidth: 560, minHeight: 440)
    }
}

/// 新对话的默认记忆设置（FR-015：1–20，默认 10）
struct GeneralSettingsView: View {
    @AppStorage("defaultMemoryTurns") private var defaultMemoryTurns = 10
    @AppStorage("defaultCompressThreshold") private var defaultCompressThreshold = 10

    var body: some View {
        Form {
            Stepper(value: $defaultMemoryTurns, in: 1...20) {
                Text("新对话默认记忆轮数：\(defaultMemoryTurns)")
            }
            .onChange(of: defaultMemoryTurns) {
                if defaultCompressThreshold > defaultMemoryTurns {
                    defaultCompressThreshold = defaultMemoryTurns
                }
            }
            Stepper(value: $defaultCompressThreshold, in: 1...defaultMemoryTurns) {
                Text("新对话默认压缩阈值：\(defaultCompressThreshold)")
            }
            Text("压缩阈值不能大于记忆轮数；对话内可单独调整。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }
}
