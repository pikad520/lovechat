# Contract: Imagine Provider（OpenAI 标准 Images API）

- **Endpoint**: `POST {baseURL}/images/generations`（`/v1` 去重规则同 chat）
- **Headers**: `Authorization: Bearer {key}`, `Content-Type: application/json`
- **Body**:
  ```json
  {
    "model": "...",
    "prompt": "<由生图判断调用产出的英文描述>",
    "n": 1,
    "response_format": "b64_json"
  }
  ```
- **Response 处理顺序**（R6）:
  1. `data[0].b64_json` 存在 → Base64 解码得字节；
  2. 否则 `data[0].url` 存在 → 立即 `URLSession.data(from:)` 下载（URL 短期过期，
     下载失败即视为生图失败）；
  3. 字节写入 `ImageStore`（`Application Support/LoveChat/Images/{uuid}.png`），
     消息记录文件名。
- **失败语义**（FR 生图降级 / SC-006）: 任何环节失败 → 该消息不带图片，文字回复
  不受影响；对话流中以轻量提示标注「图片生成失败」。
- **超时**: 请求超时 120s（生图较慢）。
