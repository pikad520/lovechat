import Foundation

struct SSEEvent: Sendable {
    var event: String?
    var data: String
}

/// 轻量 SSE 解析（research R1）：手动按字节切行，空行分隔事件，
/// 兼容 \r\n；多个 data: 行按规范以换行拼接。
enum SSEParser {

    static func events(from bytes: URLSession.AsyncBytes) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            // detached：避免继承调用方的 MainActor 隔离，字节解析必须在后台（宪法 IV）
            let task = Task.detached {
                var lineBuffer: [UInt8] = []
                var eventName: String?
                var dataLines: [String] = []

                func flushEvent() {
                    guard !dataLines.isEmpty else {
                        eventName = nil
                        return
                    }
                    let event = SSEEvent(event: eventName, data: dataLines.joined(separator: "\n"))
                    continuation.yield(event)
                    eventName = nil
                    dataLines = []
                }

                func processLine(_ line: String) {
                    if line.isEmpty {
                        flushEvent()
                    } else if line.hasPrefix("event:") {
                        eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                    }
                    // 其他前缀（id:、retry:、注释行）忽略
                }

                do {
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            if lineBuffer.last == UInt8(ascii: "\r") {
                                lineBuffer.removeLast()
                            }
                            processLine(String(decoding: lineBuffer, as: UTF8.self))
                            lineBuffer.removeAll(keepingCapacity: true)
                        } else {
                            lineBuffer.append(byte)
                        }
                    }
                    // 流自然结束：冲掉残留事件
                    if !lineBuffer.isEmpty {
                        processLine(String(decoding: lineBuffer, as: UTF8.self))
                    }
                    flushEvent()
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
