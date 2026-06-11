import SwiftUI
import SwiftData

/// 角色卡管理（FR-011）
struct CharacterListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CharacterCard.createdAt) private var characters: [CharacterCard]
    @State private var editingCharacter: CharacterCard?
    @State private var showNewCharacter = false

    var body: some View {
        List {
            Section {
                ForEach(characters) { character in
                    HStack(spacing: 10) {
                        CharacterAvatarView(fileName: character.avatarFileName, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                        Text(character.name.isEmpty ? "（未命名）" : character.name)
                        HStack(spacing: 8) {
                            if character.showInnerThoughts {
                                Label("心理活动", systemImage: "bubble.and.pencil")
                            }
                            if character.allowImages {
                                Label("可发图", systemImage: "photo")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture { editingCharacter = character }
                    .contextMenu {
                        Button("编辑") { editingCharacter = character }
                        Button("删除", role: .destructive) { delete(character) }
                    }
                }
            } header: {
                HStack {
                    Text("角色卡片")
                    Spacer()
                    Button {
                        showNewCharacter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .sheet(item: $editingCharacter) { character in
            CharacterEditView(character: character, isNew: false)
        }
        .sheet(isPresented: $showNewCharacter) {
            CharacterEditView(character: CharacterCard(), isNew: true)
        }
    }

    /// 删除角色时清理头像文件（FR-102）
    private func delete(_ character: CharacterCard) {
        if let fileName = character.avatarFileName {
            ImageStore.delete(fileName)
        }
        context.delete(character)
    }
}
