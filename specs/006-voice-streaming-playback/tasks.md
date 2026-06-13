# Tasks: 外接语音分句流式播放开关

**Input**: specs/006-voice-streaming-playback/spec.md | 架构沿用 005

- [x] T601 SpeechCoordinator：splitSentences 切句（句末标点 + 过短片段合并）（FR-504）
- [x] T602 ClipPlayer：单段 await 播放（AVAudioPlayer + continuation），供顺序衔接
- [x] T603 speakChunked：AsyncStream 生产者逐句合成预取 + 消费者顺序播放；首句起播切状态；停止即中断（FR-502/503）
- [x] T604 speak 分流：外接 && 开关开 → speakChunked，否则 speakOneShot（原逻辑）（FR-501）
- [x] T605 VoiceSettingsView：voiceChunkedStreaming 开关（默认开，外接服务区展示）（FR-501）
- [x] T606 编译验证 + 提交
