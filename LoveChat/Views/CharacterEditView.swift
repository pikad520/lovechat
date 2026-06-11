import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// 角色卡编辑（FR-011/012/013 + 头像 FR-101/102）
struct CharacterEditView: View {
    @Bindable var character: CharacterCard
    let isNew: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ImagineProviderConfig.createdAt) private var imagineProviders: [ImagineProviderConfig]
    @State private var isGeneratingAvatar = false
    @State private var avatarError: String?

    private var isValid: Bool {
        !character.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("头像") {
                    avatarSection
                }
                Section("基本") {
                    TextField("名称（必填）", text: $character.name)
                    TextField("性别", text: $character.gender)
                    TextField("对用户的称呼", text: $character.userAddressing, prompt: Text("如 亲爱的"))
                }
                Section("人设") {
                    VStack(alignment: .leading) {
                        Text("外貌").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $character.appearance).frame(minHeight: 48)
                    }
                    VStack(alignment: .leading) {
                        Text("灵魂（性格内核）").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $character.soul).frame(minHeight: 48)
                    }
                    VStack(alignment: .leading) {
                        Text("说话风格").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $character.speakingStyle).frame(minHeight: 48)
                    }
                    VStack(alignment: .leading) {
                        Text("其他补充设定").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $character.extraNotes).frame(minHeight: 48)
                    }
                }
                if !imagineProviders.isEmpty {
                    Section("图片生成风格") {
                        Picker("预置风格", selection: $character.imageStyle) {
                            ForEach(ImageStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("同时作用于头像生成与对话中的情境生图。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("开关") {
                    Toggle("展示心理活动", isOn: $character.showInnerThoughts)
                    Text("开启后角色会用（小括号）穿插心理活动，以特殊样式展示。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("允许发送图片", isOn: $character.allowImages)
                    Text("开启后将根据对话情境自动判断并生成图片（需要为对话配置 Imagine Provider）。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button(isNew ? "创建" : "保存") {
                    if isNew {
                        context.insert(character)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 560)
    }

    // MARK: - 头像（FR-101/102）

    @ViewBuilder
    private var avatarSection: some View {
        HStack(spacing: 16) {
            CharacterAvatarView(fileName: character.avatarFileName, size: 64)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("上传图片…") { uploadAvatar() }
                        .disabled(isGeneratingAvatar)

                    if imagineProviders.isEmpty {
                        Button("生成头像") {}
                            .disabled(true)
                            .help("需要先在 Provider 设置中添加 Imagine Provider")
                    } else if character.appearance.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("生成头像") {}
                            .disabled(true)
                            .help("请先填写角色外貌，生成基于外貌设定")
                    } else {
                        Menu("生成头像") {
                            ForEach(imagineProviders) { provider in
                                Button(provider.name) { generateAvatar(with: provider) }
                            }
                        }
                        .fixedSize()
                        .disabled(isGeneratingAvatar)
                    }

                    if character.avatarFileName != nil {
                        Button("移除", role: .destructive) { removeAvatar() }
                            .disabled(isGeneratingAvatar)
                    }

                    if isGeneratingAvatar {
                        ProgressView().controlSize(.small)
                    }
                }
                if let avatarError {
                    Label(avatarError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text("可上传本地图片，或用 Imagine Provider 基于外貌设定生成。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func uploadAvatar() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url)
        else { return }
        do {
            let fileName = try ImageStore.save(data)
            replaceAvatar(with: fileName)
            avatarError = nil
        } catch {
            avatarError = "图片保存失败，请重试。"
        }
    }

    private func generateAvatar(with provider: ImagineProviderConfig) {
        isGeneratingAvatar = true
        avatarError = nil
        let snapshot = ImagineProviderSnapshot(provider)
        let prompt = PromptLibrary.avatarPrompt(appearance: character.appearance, style: character.imageStyle)
        Task {
            do {
                let fileName = try await ImageGenService.generate(prompt: prompt, provider: snapshot)
                replaceAvatar(with: fileName)
            } catch {
                // 生成失败不影响角色保存（SC-103）
                avatarError = AppError.wrap(error).userMessage
            }
            isGeneratingAvatar = false
        }
    }

    private func removeAvatar() {
        replaceAvatar(with: nil)
    }

    /// 统一替换路径：旧文件一并清理（FR-102）
    private func replaceAvatar(with fileName: String?) {
        if let old = character.avatarFileName {
            ImageStore.delete(old)
        }
        character.avatarFileName = fileName
    }
}

/// 圆形头像/占位（FR-103 复用）
struct CharacterAvatarView: View {
    let fileName: String?
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let fileName, let image = NSImage(contentsOf: ImageStore.url(for: fileName)) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
