import Foundation

/// 全部硬编码提示词的唯一所在地（宪法 VI / FR-014）。
/// 任何提示词不得暴露给用户或角色自定义。
enum PromptLibrary {

    // MARK: - P1 心理活动提示词

    static let innerThoughtsInstruction = """
    【心理活动要求】
    在你的回复中，自然地穿插你此刻真实的心理活动。心理活动必须用半角小括号 ( ) 包裹，\
    独立成句，使用第一人称内心独白的口吻。括号内只写心理活动；正文叙述中不要将小括号\
    用于其他用途。每条回复至少包含一处心理活动，但不要过多，以免破坏对话节奏。
    """

    // MARK: - P2 生图判断提示词

    /// 非流式调用，maxTokens 限制 200，温度 0（contracts/internal-prompts.md）
    static func imageDecisionPrompt(recentMessages: String) -> String {
        """
        你是一个判断器。根据下面最近的对话内容，判断"角色此刻是否应该给用户发送一张图片"。\
        只有当用户明确求图，或情境强烈适合用画面表达（如描述自己的样子、展示场景）时才判定为是。

        最近对话：
        ---
        \(recentMessages)
        ---

        只输出一个 JSON 对象，不要输出任何其他文字、解释或代码块标记，格式：
        {"generate": true 或 false, "prompt": "若 generate 为 true，给出英文的画面描述；否则为空字符串"}
        """
    }

    // MARK: - P3 生图提示词模板

    static func imagePrompt(appearance: String, scenePrompt: String) -> String {
        var parts: [String] = []
        if !appearance.isEmpty {
            parts.append("Character appearance: \(appearance).")
        }
        parts.append("Scene: \(scenePrompt).")
        parts.append("High quality, detailed, soft lighting, single character portrait composition.")
        return parts.joined(separator: " ")
    }

    // MARK: - P5 头像生成提示词

    static func avatarPrompt(appearance: String) -> String {
        "Character appearance: \(appearance). Portrait avatar, head and shoulders, "
            + "facing viewer, high quality, detailed, soft lighting, clean background."
    }

    // MARK: - 旁白合并（FR-105，标记格式硬编码）

    /// 旁白非空时把旁白与用户发言合并为一条带标记的用户消息；
    /// 为空时原样返回用户文本（零回归，SC-102）。
    static func composeUserTurn(narration: String?, text: String) -> String {
        guard let narration = narration?.trimmingCharacters(in: .whitespacesAndNewlines),
              !narration.isEmpty
        else { return text }
        return """
        【旁白｜场景与情节描述，不是用户对你说的话】
        \(narration)
        【用户发言】
        \(text)
        """
    }

    // MARK: - P4 压缩提示词

    /// 非流式调用，maxTokens 限制 1000（research R8）
    static func compressionPrompt(oldSummary: String, slidOutMessages: String) -> String {
        var prompt = """
        你是对话记忆的整理者。请把下面的内容压缩成一段第三人称的剧情摘要，\
        保留：人物事实、双方约定、关键事件、情感关系进展。摘要不超过 500 字，\
        只输出摘要本身，不要任何前后缀说明。
        """
        if !oldSummary.isEmpty {
            prompt += "\n\n已有摘要（需要与新内容合并）：\n---\n\(oldSummary)\n---"
        }
        prompt += "\n\n新滑出记忆窗口的对话：\n---\n\(slidOutMessages)\n---"
        return prompt
    }

    // MARK: - System Prompt 组装（FR-018）

    /// 顺序固定：角色设定 → 心理活动提示词（若开启）→ 压缩历史摘要（若有）
    static func systemPrompt(for character: CharacterSnapshot, summary: String) -> String {
        var sections: [String] = []

        var card = "【角色设定】\n你将完全扮演以下角色，以第一人称与用户对话，绝不跳出角色：\n"
        card += "姓名：\(character.name)\n"
        if !character.gender.isEmpty { card += "性别：\(character.gender)\n" }
        if !character.appearance.isEmpty { card += "外貌：\(character.appearance)\n" }
        if !character.soul.isEmpty { card += "性格内核：\(character.soul)\n" }
        if !character.userAddressing.isEmpty { card += "对用户的称呼：\(character.userAddressing)\n" }
        if !character.speakingStyle.isEmpty { card += "说话风格：\(character.speakingStyle)\n" }
        if !character.extraNotes.isEmpty { card += "补充设定：\(character.extraNotes)\n" }
        sections.append(card)

        if character.showInnerThoughts {
            sections.append(innerThoughtsInstruction)
        }

        if !summary.isEmpty {
            sections.append("【过往剧情摘要】\n\(summary)")
        }

        return sections.joined(separator: "\n\n")
    }
}
