import SwiftUI
import AppKit

/// 消息气泡：用户右侧、角色左侧、错误提示居中胶囊（FR-010/012）。
/// 心理活动渲染：流式期间纯文本，complete 后经 ThoughtParser 解析（research R9）。
struct MessageBubbleView: View {
    let message: ChatMessage
    let characterName: String
    /// 角色头像文件名（FR-103）；nil 显示占位
    var avatarFileName: String?
    /// 角色未开启心理活动时按普通文本渲染（FR-012）
    var parseThoughts: Bool = false
    var onRetry: (() -> Void)?

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                VStack(alignment: .trailing, spacing: 4) {
                    narrationContent
                    bubbleContent
                        .padding(10)
                        .background(.tint.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
            }
        case .assistant:
            HStack(alignment: .top, spacing: 8) {
                CharacterAvatarView(fileName: avatarFileName, size: 32)
                VStack(alignment: .leading, spacing: 6) {
                    Text(characterName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    bubbleContent
                        .padding(10)
                        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                }
                Spacer(minLength: 60)
            }
        case .systemNotice:
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Label(message.text, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let onRetry {
                        Button("重试", action: onRetry)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(8)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                Spacer()
            }
        }
    }

    /// 旁白展示（FR-106）：用户气泡上方的区别样式
    @ViewBuilder
    private var narrationContent: some View {
        if let narration = message.narration,
           !narration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text("旁白：\(narration)")
                .font(.callout.italic())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            textContent
            imageContent
            statusFooter
        }
    }

    @ViewBuilder
    private var textContent: some View {
        if message.role == .assistant, parseThoughts, message.status == .complete || message.status == .stopped {
            // 流结束后解析心理活动（FR-012；解析失败容错为普通文本）
            let segments = ThoughtParser.parse(message.text)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .normal(let text):
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                                .textSelection(.enabled)
                        }
                    case .thought(let text):
                        Text("（\(text)）")
                            .font(.callout.italic())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                            .textSelection(.enabled)
                    }
                }
            }
        } else if message.text.isEmpty, message.status == .pending || message.status == .streaming {
            ProgressView()
                .controlSize(.small)
        } else {
            Text(message.text)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let fileName = message.imageFileName,
           let nsImage = NSImage(contentsOf: ImageStore.url(for: fileName)) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 320, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    NSWorkspace.shared.open(ImageStore.url(for: fileName))
                }
                .help("点击用默认应用打开")
        } else if message.imageFailed {
            Label("图片生成失败", systemImage: "photo.badge.exclamationmark")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        switch message.status {
        case .stopped:
            Text("已停止")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        case .failed:
            Text("生成中断")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        default:
            EmptyView()
        }
    }
}
