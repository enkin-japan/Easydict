## 2026-10-22 | 任务：恢复 OpenAI 服务并增加可选发音引擎

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->

**Links:** 计划 [`2026-10-22-openai-service-speech-engine.md`](../../exec-plans/completed/2026-10/2026-10-22-openai-service-speech-engine.md)、
GitHub Release `v2.25.0-slim.5`（enkin-japan/Easydict）

### 执行上下文

- **Agent Name:** `Claude Code`
- **Model:** `claude-opus-5-5`
- **Environment:** `macOS 27.0.1 / Xcode 27.1 (27A9275)`

### 用户请求

加回 OpenAI 接口；为发音增加设置，可以选择系统声音或本地 TTS；完成后发布新版本并在本机安装。
同时询问本地 TTS 是否有统一接口、是否应考虑 MCP。

### 变更

- `QueryServiceFactory` 重新注册 `OpenAIService`（用户自备 API Key），代码沿用上游，无思考开关。
- 新增 `Service/Speech/`：
  - `SpeechEngine`：`system` / `openAICompatible` 两种引擎，`SpeechVoiceLanguage` 把语言归为中文、日语、
    英语、其他四组，各自对应系统语音与 TTS voice 设置键。
  - `OpenAICompatibleTTSClient`：Alamofire 调用 `POST /v1/audio/speech`（`model`、`input`、`voice`、
    `response_format: mp3`，有 Key 时带 Bearer），只填到 `/v1` 或根地址时自动补全路径，超时 60 秒，
    非 2xx 时把状态码和返回内容前 300 字放进本地化错误。
  - `SpeechPlayer`（`EZSpeechPlayer`）：统一播放系统语音（`AVSpeechSynthesizer`）与服务器音频（`AVAudioPlayer`），
    新的播放会先停止旧的，用代次号忽略过期请求；服务器失败时按调用方选择回退系统声音或上报错误；
    内存缓存最近 50 条音频。
- `AppleSpeechService` 改用 `AVSpeechSynthesisVoice`：排除趣味音色和个人声音（macOS 14+），按
  高品质 > 增强 > 普通、普通音色优先于 MacinTalk / Eloquence 排序；用户指定的语音已卸载时回到自动选择；
  文言文按普通话选音。保留 `preferredVoiceIdentifier(from:)` 供现有测试使用。
- `EZAudioPlayer` 去掉 `NSSpeechSynthesizer` 与其代理，改由 `EZSpeechPlayer` 播放并在完成时复位
  `isPlaying`；`AppleService.playTextAudio` 删除。
- 设置 › 高级新增“发音”分区（`AdvancedTabSpeechSection`）：引擎选择；系统声音下中文、日语、英语各一个
  语音选择（自动 + 已安装语音及品质）；本地 TTS 下可填地址、API Key、模型和四组 voice，每行有试听按钮，
  试听不回退并显示错误。23 个新文案写入 6 种语言。
- build 号提升到 71；`SLIM.md` 补充 OpenAI 与发音说明。

### 设计意图

本地 TTS 选 OpenAI 的 `/v1/audio/speech` 作为唯一协议：它是本地 TTS 服务事实上的通用接口（Kokoro-FastAPI、
mlx-audio、LocalAI、openedai-speech 等都实现），同一套设置也能接 OpenAI 云端 TTS。不使用 MCP：MCP 是给大模型
调用工具的协议，发音不需要模型参与，也没有统一的 TTS 工具定义，现有 TTS MCP 服务多是自己播放音频而不返回数据。
实测第三方进程看不到 Siri 与 gryphon 神经语音（只有 Apple 签名的进程能看到），所以系统声音的提升只能来自用户
下载的增强/高品质语音，设置页脚注明了下载位置。

### 验证

- Debug `xcodebuild build` 通过，本次文件无 SwiftLint 警告；`xcodebuild test -only-testing:EasydictTests/AppleSpeechServiceTests`
  6 项通过；`git diff --check`、`jq -e .` 通过。
- 本机模拟服务（Python，按 voice 用 `say` 生成音频）+ Debug 版真实查询（`easydictd://query`，打开自动朗读）：
  - 地址填 `http://127.0.0.1:18880/v1` 时请求发到 `/v1/audio/speech`，带 `Bearer` Key，`model`、`voice: af_heart`、
    `response_format: mp3` 正确，日志显示播放 49 KB / 1.0 秒音频。
  - 改成错误地址后服务器返回 404，日志记录本地化错误并改用系统声音朗读。
  - 同一个词再次查询命中缓存，没有新请求。
  - 系统声音引擎不发请求，英语自动选 `com.apple.voice.compact.en-US.Samantha`；指定 Eloquence Flo 时按指定朗读，
    指定不存在的语音时回到 Samantha。
- 测试改动的 Debug 偏好设置已删除，模拟服务已停止。
- 未验证：没有运行真实的 Kokoro-FastAPI / mlx-audio；设置页布局未截图确认（终端无屏幕录制权限）；中文、日语只验证了
  选音逻辑，未在 App 中实际朗读。

### 受影响文件

- `Easydict/Swift/Service/Model/QueryServiceFactory.swift`
- `Easydict/Swift/Service/Speech/SpeechEngine.swift`
- `Easydict/Swift/Service/Speech/OpenAICompatibleTTSClient.swift`
- `Easydict/Swift/Service/Speech/SpeechPlayer.swift`
- `Easydict/Swift/Service/Apple/AppleSpeechService/AppleSpeechService.swift`
- `Easydict/Swift/Service/Apple/AppleService.swift`
- `Easydict/objc/Service/AudioPlayer/EZAudioPlayer.m`
- `Easydict/Swift/Feature/Configuration/Defaults.Keys+Extension.swift`
- `Easydict/Swift/View/SettingView/Tabs/TabView/AdvancedTab.swift`
- `Easydict/Swift/View/SettingView/Tabs/TabView/AdvancedTabSpeechSection.swift`
- `Easydict/App/Localizable.xcstrings`
- `Easydict.xcodeproj/project.pbxproj`
- `SLIM.md`

### 后续事项

- VOICEVOX / AivisSpeech 用自己的两段式接口（`/audio_query` + `/synthesis`），不兼容 OpenAI 协议，需要时可再加一种引擎。
- 本地 TTS 的“其他语言”只有一个 voice，Kokoro 以外的多语言服务需按服务端说明填写。
