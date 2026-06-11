<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan:
[specs/001-lovechat-app/plan.md](specs/001-lovechat-app/plan.md)

- Constitution: `.specify/memory/constitution.md`（零第三方依赖、密钥仅 Keychain、
  流式优先、优雅降级为不可协商原则）
- Spec: `specs/001-lovechat-app/spec.md`；需求唯一基准为根目录 `DESIGN.md`
- Tech: Swift 6 / SwiftUI / SwiftData / URLSession SSE，macOS 26+，无法本地
  xcodebuild（用户在 Xcode 中编译）
<!-- SPECKIT END -->
