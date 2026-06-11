# Contract: Chat Provider 协议适配

统一抽象（Swift 侧）：

```swift
enum StreamEvent { case textDelta(String); case finished }

protocol ChatProtocolAdapter {
    /// 流式聊天；事件序列以 .finished 正常收尾，错误经 throw 传播
    func streamChat(_ req: ChatRequest) -> AsyncThrowingStream<StreamEvent, Error>
    /// 非流式单次调用（生图判断 / 压缩 / 连通性测试）
    func completeOnce(_ req: ChatRequest) async throws -> String
}

struct ChatRequest {
    var systemPrompt: String
    var messages: [(role: String, text: String)] // "user" | "assistant"
    var maxTokens: Int?          // 内部调用必填（FR-007）
    var thinkingEnabled: Bool
}
```

## OpenAI 适配（protocolType == .openAI）

- **Endpoint**: `POST {baseURL}/chat/completions`（baseURL 末尾已含 `/v1` 不重复补）
- **Headers**: `Authorization: Bearer {key}`, `Content-Type: application/json`
- **Body（流式）**:
  ```json
  {
    "model": "...",
    "stream": true,
    "messages": [{"role": "system", "content": "..."}, {"role": "user", "content": "..."}],
    "reasoning_effort": "medium"   // 仅 thinkingEnabled
  }
  ```
- **SSE**: 每个 `data:` 行为 JSON chunk，取 `choices[0].delta.content` 为
  `.textDelta`；`data: [DONE]` → `.finished`。
- **非流式**: `stream: false` + `max_tokens`，取 `choices[0].message.content`。

## Anthropic 适配（protocolType == .anthropic）

- **Endpoint**: `POST {baseURL}/v1/messages`
- **Headers**: `x-api-key: {key}`, `anthropic-version: 2023-06-01`,
  `Content-Type: application/json`
- **Body（流式）**:
  ```json
  {
    "model": "...",
    "stream": true,
    "max_tokens": 8192,
    "system": "...",
    "messages": [{"role": "user", "content": "..."}],
    "thinking": {"type": "enabled", "budget_tokens": 4096}   // 仅 thinkingEnabled
  }
  ```
- **SSE**: 事件 `content_block_delta` 且 `delta.type == "text_delta"` →
  `.textDelta(delta.text)`；`message_stop` → `.finished`；`thinking_delta` 忽略。
- **非流式**: 去掉 `stream`，取 `content[]` 中首个 `type=="text"` 的 `text`。

## 思考模式降级（两协议通用，R4）

HTTP 400 且响应 body 包含被拒参数名（`reasoning_effort` / `thinking`）→ 剥离该参数
原样重试一次；仍失败按常规错误处理。

## 错误映射（→ AppError → 友好文案，FR-010）

| 上游表现 | AppError | 文案要点 |
|----------|----------|----------|
| HTTP 401/403 | `.authFailed` | 密钥无效，请检查配置 |
| HTTP 429 | `.rateLimited` | 太频繁，稍后重试 |
| 审核拒绝（400/`content_policy` 类标识 或 Anthropic `stop_reason == "refusal"`） | `.contentRefused` | 内容被服务方拒绝 |
| URLError | `.network` | 网络异常，可重试 |
| 流中途断开 | `.streamInterrupted` | 已保留部分内容，可恢复/重新生成 |
| 其他 | `.unknown(status)` | 通用失败文案 |

## 连通性测试（FR-004）

`completeOnce`：messages 仅 `[user: "ping"]`，`maxTokens: 5`。成功（任意文本返回）
→ 测试通过；失败展示 AppError 文案。
