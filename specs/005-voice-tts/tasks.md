# Tasks: 本地语音朗读（Kokoro TTS）

**Input**: specs/005-voice-tts/spec.md | 宪法 v1.1.0（原则 II 语音豁免）

技术路径（plan 摘要）：
- 推理库：sherpa-onnx 预编译 macOS 产物（C API dylib/xcframework + 官方 Swift 封装）
  vendored 进仓库 `Vendor/sherpa-onnx/`，pbxproj 手工接线（链接 + 嵌入签名）
- 模型：sherpa-onnx Releases 的 kokoro 多语言包（含 zf_*/zm_* 中文音色），
  运行时下载解压到 `Application Support/LoveChat/TTS/`
- 服务层：`VoiceEngine.swift`（唯一接触 sherpa-onnx 的文件）+
  `VoiceModelManager.swift`（检测/下载/进度/校验/删除）+ AVAudioPlayer 播放
- 朗读文本预处理：复用 ThoughtParser 跳过心理活动段

## Phase 1: Vendor 推理库

- [ ] T401 获取 sherpa-onnx macOS 预编译产物与 Swift 封装，落库 `Vendor/sherpa-onnx/`
- [ ] T402 pbxproj 接线：头文件搜索路径、链接 dylib、Copy Files 嵌入 + 运行时签名；
      entitlements 不变（无需新增权限）
- [ ] T403 编译冒烟：空调用 sherpa-onnx 版本号确认链接成功

## Phase 2: 模型管理（US1）

- [ ] T404 `VoiceModelManager.swift`：状态机（未就绪/下载中/解压中/已就绪）、
      URLSession 下载带进度、tar.bz2 解压、完整性校验、取消/重试/删除（FR-402/406）
- [ ] T405 SettingsView 新增「语音」tab：开关、状态展示、一键下载（进度条）、
      音色选择 + 试听、模型占用与删除（FR-405/406）

## Phase 3: 合成与播放（US2/US3）

- [ ] T406 `VoiceEngine.swift`：加载模型、文本→PCM、按句切分流水线（FR-401，SC-402）
- [ ] T407 播放控制：AVAudioPlayer 单路播放管理；MessageBubbleView 🔊 播放/停止/置灰态（FR-404）
- [ ] T408 朗读预处理：ThoughtParser 过滤心理活动；CharacterCard 增加 voiceID/autoSpeak
      字段（可选，轻量迁移）；自动朗读接入流式完成回调（FR-405）

## Phase 4: 外接语音服务（US4）

- [ ] T409 `VoiceProviderConfig` SwiftData 模型（名称/地址/协议类型/GPT-SoVITS 参考音频参数）+
      设置页增删改与连通性测试（FR-407）
- [ ] T410 `ExternalVoiceClient.swift`：OpenAI 兼容与 GPT-SoVITS api_v2 两种请求实现；
      角色级音色绑定（内置/外接）；失败回退内置引擎（FR-408）

## Phase 5: 收尾

- [ ] T411 全链路自查（降级路径/并发/零回归）+ quickstart 验证场景补充
- [ ] T412 构建发版：编译、打包、上传新 Release，发布说明含语音功能与模型下载说明
