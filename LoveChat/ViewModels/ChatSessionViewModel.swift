import Foundation
import SwiftData
import Observation

/// 单个对话会话的流式状态机（FR-006/008/009/010）。
/// @MainActor：所有 @Model 读写在主线程；网络在服务层后台执行。
@MainActor
@Observable
final class ChatSessionViewModel {

    private(set) var isStreaming = false
    private var streamTask: Task<Void, Never>?

    // MARK: - 发送

    func send(text: String, narration: String = "", in conversation: Conversation, context: ModelContext) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        let userMessage = ChatMessage(role: .user, text: trimmed, status: .complete)
        let trimmedNarration = narration.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNarration.isEmpty {
            userMessage.narration = trimmedNarration // 随消息持久化（FR-106）
        }
        userMessage.conversation = conversation
        context.insert(userMessage)
        if conversation.sortedMessages.filter({ $0.role == .user }).count == 1 {
            conversation.title = String(trimmed.prefix(20))
        }
        conversation.updatedAt = Date()

        startReply(in: conversation, context: context)
    }

    /// 重新生成最后一条回复（FR-009）：删旧 assistant 消息 → 重走流式
    func regenerate(in conversation: Conversation, context: ModelContext) {
        guard !isStreaming else { return }
        removeTrailingNotices(in: conversation, context: context)
        if let last = conversation.sortedMessages.last, last.role == .assistant {
            if let fileName = last.imageFileName {
                ImageStore.delete(fileName)
            }
            context.delete(last)
        }
        startReply(in: conversation, context: context)
    }

    /// 错误后的重试（FR-010）：移除错误提示，重走流式
    func retry(in conversation: Conversation, context: ModelContext) {
        guard !isStreaming else { return }
        removeTrailingNotices(in: conversation, context: context)
        startReply(in: conversation, context: context)
    }

    /// 停止生成（FR-008）：内容保留，状态 stopped
    func stop() {
        streamTask?.cancel()
    }

    // MARK: - 核心流程

    private func startReply(in conversation: Conversation, context: ModelContext) {
        guard let providerModel = conversation.chatProvider else {
            appendNotice(AppError.missingProvider, in: conversation, context: context)
            return
        }
        guard let characterModel = conversation.character else {
            appendNotice(AppError.missingCharacter, in: conversation, context: context)
            return
        }

        let provider = ChatProviderSnapshot(providerModel)
        let character = CharacterSnapshot(characterModel)
        let imagineProvider = conversation.imagineProvider.map(ImagineProviderSnapshot.init)
        let turns = contextTurns(in: conversation)
        let systemPrompt = PromptLibrary.systemPrompt(for: character, summary: conversation.memorySummary)

        let reply = ChatMessage(role: .assistant, text: "", status: .pending)
        reply.conversation = conversation
        context.insert(reply)

        isStreaming = true

        // 生图判断并行进行，不阻塞文字流（FR-013，宪法 IV）
        if character.allowImages, let imagineProvider {
            launchImagePipeline(
                turns: turns,
                provider: provider,
                imagineProvider: imagineProvider,
                appearance: character.appearance,
                style: character.imageStyle,
                replyID: reply.id,
                conversation: conversation
            )
        }

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = try ChatService.streamReply(systemPrompt: systemPrompt, turns: turns, provider: provider)
                reply.status = .streaming
                for try await event in stream {
                    if Task.isCancelled { break }
                    if case .textDelta(let delta) = event {
                        reply.text += delta
                    }
                }
                if Task.isCancelled {
                    reply.status = reply.text.isEmpty ? .failed : .stopped
                } else {
                    reply.status = .complete
                }
            } catch {
                let appError = AppError.wrap(error)
                // 已有部分内容则保留为 failed（FR-010 流中断可恢复）
                reply.status = .failed
                if reply.text.isEmpty {
                    context.delete(reply)
                }
                self.appendNotice(appError, in: conversation, context: context)
            }
            conversation.updatedAt = Date()
            self.isStreaming = false
            self.streamTask = nil
            // 回复完成后触发后台压缩（FR-016/017）
            if reply.status == .complete {
                self.scheduleCompression(for: conversation, provider: provider)
            }
        }
    }

    // MARK: - 上下文窗口（data-model 派生规则）

    /// 取最近 memoryTurns 轮、未被截断排除的 user/assistant 消息
    private func contextTurns(in conversation: Conversation) -> [ChatTurn] {
        let eligible = conversation.sortedMessages.filter {
            !$0.excludedFromContext
                && ($0.role == .user || $0.role == .assistant)
                && ($0.role == .user || $0.status == .complete || $0.status == .stopped)
                && !$0.text.isEmpty
        }
        var turnCount = 0
        var window: [ChatMessage] = []
        for message in eligible.reversed() {
            if message.role == .user { turnCount += 1 }
            window.append(message)
            if turnCount >= conversation.memoryTurns { break }
        }
        return window.reversed().map(Self.makeTurn)
    }

    /// 消息 → ChatTurn：用户消息携带旁白时合并标记（FR-105）
    private static func makeTurn(_ message: ChatMessage) -> ChatTurn {
        if message.role == .user {
            return ChatTurn(role: "user", text: PromptLibrary.composeUserTurn(narration: message.narration, text: message.text))
        }
        return ChatTurn(role: "assistant", text: message.text)
    }

    // MARK: - 压缩（research R8）

    private func scheduleCompression(for conversation: Conversation, provider: ChatProviderSnapshot) {
        let eligible = conversation.sortedMessages.filter {
            !$0.excludedFromContext && ($0.role == .user || $0.role == .assistant)
        }
        // 找出滑出记忆窗口的旧消息
        var turnCount = 0
        var windowStartIndex = eligible.count
        for (index, message) in eligible.enumerated().reversed() {
            if message.role == .user { turnCount += 1 }
            windowStartIndex = index
            if turnCount >= conversation.memoryTurns { break }
        }
        guard turnCount >= conversation.memoryTurns, windowStartIndex > 0 else { return }
        let slidOut = Array(eligible[0..<windowStartIndex])
        let slidOutTurnCount = slidOut.filter { $0.role == .user }.count
        guard slidOutTurnCount >= max(1, conversation.compressThreshold) else { return }

        let slidOutIDs = slidOut.map(\.id)
        let slidOutTurns = slidOut.map(Self.makeTurn) // 旁白随压缩输入保留（FR-106）
        let oldSummary = conversation.memorySummary
        let conversationID = conversation.id

        Task { [weak self] in
            // 网络压缩在 actor 内后台执行，不阻塞发消息（宪法 IV）
            let summary = await ContextCompressor.shared.compress(
                conversationID: conversationID,
                oldSummary: oldSummary,
                slidOutTurns: slidOutTurns,
                provider: provider
            )
            guard self != nil else { return }
            if let summary {
                conversation.memorySummary = summary
            }
            // 成功：消息已并入摘要；失败：降级为截断（FR-017）——两种情况都排除出上下文
            for message in conversation.sortedMessages where slidOutIDs.contains(message.id) {
                message.excludedFromContext = true
            }
        }
    }

    // MARK: - 生图管线（FR-013）

    private func launchImagePipeline(
        turns: [ChatTurn],
        provider: ChatProviderSnapshot,
        imagineProvider: ImagineProviderSnapshot,
        appearance: String,
        style: ImageStyle,
        replyID: UUID,
        conversation: Conversation
    ) {
        Task { [weak self] in
            let decision = await ChatService.decideImage(recentTurns: turns, provider: provider)
            guard decision.generate, !decision.prompt.isEmpty else { return }
            guard self != nil else { return }
            let prompt = PromptLibrary.imagePrompt(appearance: appearance, scenePrompt: decision.prompt, style: style)
            do {
                let fileName = try await ImageGenService.generate(prompt: prompt, provider: imagineProvider)
                if let reply = conversation.sortedMessages.first(where: { $0.id == replyID }) {
                    reply.imageFileName = fileName
                } else {
                    ImageStore.delete(fileName) // 回复已被删除（如重新生成），丢弃图片
                }
            } catch {
                // 生图失败不影响文字回复（SC-006）
                if let reply = conversation.sortedMessages.first(where: { $0.id == replyID }) {
                    reply.imageFailed = true
                }
            }
        }
    }

    // MARK: - 辅助

    private func appendNotice(_ error: AppError, in conversation: Conversation, context: ModelContext) {
        let notice = ChatMessage(role: .systemNotice, text: error.userMessage, status: .complete)
        notice.conversation = conversation
        context.insert(notice)
        isStreaming = false
    }

    private func removeTrailingNotices(in conversation: Conversation, context: ModelContext) {
        for message in conversation.sortedMessages.reversed() {
            if message.role == .systemNotice {
                context.delete(message)
            } else {
                break
            }
        }
    }
}
