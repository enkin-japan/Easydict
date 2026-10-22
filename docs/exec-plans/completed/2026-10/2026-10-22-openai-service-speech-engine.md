# 恢复 OpenAI 服务与可选发音引擎

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->
<!-- 本模板只用于多步骤、跨模块或高风险的执行任务。 -->

- 状态：completed
- 创建日期：2026-10-22
- 负责人：Claude Code
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `Claude Code`
- **Model:** `claude-opus-5-5`
- **Environment:** `macOS 27.0.1 / Xcode 27.1 (27A9275)`

## 背景

精简版只注册了本地服务，`OpenAIService` 源码还在但未注册。发音固定走已弃用的 `NSSpeechSynthesizer`，
设置里没有任何发音选项，也无法接入本机神经网络 TTS。

## 目标与范围

- 目标结果：
  - 服务列表可以添加 OpenAI 官方服务（用户自备 API Key）。
  - 设置 › 高级新增“发音”分区：引擎可选“系统声音”或“本地 TTS（OpenAI 兼容）”。
  - 系统声音改用 `AVSpeechSynthesizer`，默认自动选择质量最高的非趣味语音，中文、日语、英语可分别指定语音。
  - 本地 TTS 调用 OpenAI 兼容的 `/v1/audio/speech`，可配置地址、API Key、模型和按语言的 voice；
    请求失败时自动改用系统声音；设置中可试听并显示错误。
- 允许修改路径：`Easydict/Swift/Service/`、`Easydict/Swift/Feature/Configuration/`、
  `Easydict/Swift/View/SettingView/`、`Easydict/objc/Service/AudioPlayer/`、`Easydict/App/Localizable.xcstrings`、
  `Easydict.xcodeproj/project.pbxproj`、`SLIM.md`、`appcast.xml`、本计划与同任务 history。
- 同任务 history：`docs/histories/2026-10/2026-10-22-openai-service-speech-engine.md`
- 用户限制：完成后发布新版本 DMG 并在本机安装。
- 非目标：MCP 接入；VOICEVOX 等非 OpenAI 兼容协议；在线 TTS 预设。
- 验收标准：Debug 构建通过；本地模拟 `/v1/audio/speech` 服务收到正确请求并播放返回音频；
  服务失败时回退系统声音；Release 公证通过并安装到本机。

## 工作计划

1. 注册 `OpenAIService`。
2. `AppleSpeechService` 改为 `AVSpeechSynthesisVoice` 选择语音，新增 `SpeechPlayer` 统一播放系统语音和本地 TTS。
3. 新增 `OpenAICompatibleTTSClient`，`EZAudioPlayer` 改用 `SpeechPlayer`。
4. 高级设置新增发音分区并补齐 6 种语言文案。
5. 构建、模拟服务验证、Review、发布与本机安装。

## 风险与决策

- 实测第三方进程只能看到压缩版、Eloquence 和用户下载的增强/高品质语音，Siri 与 gryphon 神经语音只对
  Apple 签名进程可见，所以系统声音的提升取决于用户下载的语音；真正的音质提升来自本地 TTS。
- 不使用 MCP：MCP 面向大模型调用工具，App 直接合成音频不需要模型参与，且 MCP TTS 服务通常自己播放
  音频、不返回音频数据，协议层也没有统一的 TTS 工具定义。
- 本地 TTS 默认值对应 Kokoro-FastAPI（`http://localhost:8880/v1/audio/speech`、`kokoro`、按语言的 Kokoro voice）。

## 进度

- [x] 注册 OpenAI 服务
- [x] 系统语音迁移与 SpeechPlayer
- [x] 本地 TTS 客户端与设置界面
- [x] 验证、Review、发布与安装

## 验证

- 构建、测试、模拟服务端到端验证与发布结果见同任务 history。

## 完成条件

验收标准全部满足，history 已写，计划归档到 `completed/2026-10/`。
