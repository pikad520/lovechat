import Foundation

/// 心理活动括号解析（research R9）：单遍扫描，匹配成对半角 ( ) 与全角 （ ），
/// 任何异常（嵌套、不闭合）整体回退为普通文本（宪法 V / FR-012）。
enum ThoughtParser {

    enum Segment: Equatable {
        case normal(String)
        case thought(String)
    }

    static func parse(_ text: String) -> [Segment] {
        var segments: [Segment] = []
        var normalBuffer = ""
        var thoughtBuffer = ""
        var inThought = false

        for character in text {
            switch character {
            case "(", "（":
                if inThought {
                    // 嵌套括号：整体回退
                    return [.normal(text)]
                }
                inThought = true
                if !normalBuffer.isEmpty {
                    segments.append(.normal(normalBuffer))
                    normalBuffer = ""
                }
            case ")", "）":
                if !inThought {
                    // 孤立右括号：整体回退
                    return [.normal(text)]
                }
                inThought = false
                let trimmed = thoughtBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    segments.append(.thought(trimmed))
                }
                thoughtBuffer = ""
            default:
                if inThought {
                    thoughtBuffer.append(character)
                } else {
                    normalBuffer.append(character)
                }
            }
        }

        if inThought {
            // 未闭合：整体回退
            return [.normal(text)]
        }
        if !normalBuffer.isEmpty {
            segments.append(.normal(normalBuffer))
        }
        return segments.isEmpty ? [.normal(text)] : segments
    }
}
