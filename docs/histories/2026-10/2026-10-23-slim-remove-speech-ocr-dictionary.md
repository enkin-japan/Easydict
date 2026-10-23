## 2026-10-23 | 任务：精简：删除发音、OCR、Apple 词典、官方 OpenAI、多实例与 Beta

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->

**Links:** 计划 [`2026-10-23-slim-remove-speech-ocr-dictionary.md`](../../exec-plans/completed/2026-10/2026-10-23-slim-remove-speech-ocr-dictionary.md)、
GitHub Release `v2.25.0-slim.8`（enkin-japan/Easydict）

### 执行上下文

- **Agent Name:** `Claude Code`
- **Model:** `claude-opus-5-5`
- **Environment:** `macOS 27.0.1 / Xcode 27.1 (27A9275)`

### 用户请求

继续精简，并从代码层面完全删除以下功能：

- 发音。
- Apple 词典。
- 添加其他服务的入口（包括自定义 OpenAI 多实例和官方 OpenAI）。
- OCR 及相关功能。
- Beta 特性。

用户之后打算引入更好的词典，用于拆词、App 内查词和单词读音，这次精简要为此留出位置。完成后发布新版本并在本机安装。

### 变更

- **旧服务**：删除未注册的有道、DeepL、Google、Bing、百度、Codex CLI 源码，连同以下内容：
  - Codex 打包脚本与构建阶段。
  - HTTP 服务残留和 `EZWebViewTranslator`。
  - Cookie、AES 工具和 `CryptoSwift` 依赖。
  - 生词本仍在用的 `DictionaryEntry` 移到 `Feature/VocabularyNotebook/`。
  - “翻译并替换”改为直接调用 `contentStreamTranslate`，不再依赖 HTTP 请求类型。
- **发音**：删除以下内容：
  - `Service/Speech`、`AppleSpeechService`、`TTSServiceType`。
  - `EZAudioPlayer`、`EZAudioButton`、`EZAudioUtils`。
  - 查询框和结果卡片的播放按钮、自动朗读、`⌘S` 快捷键。
  - 设置里的发音部分及对应设置键。
  - 音标文字保留。
- **OCR**：删除以下内容：
  - `AppleOCREngine`、`EZOCRResult`。
  - OCR 窗口和菜单项、OCR 相关设置、剪贴板图片识别。
  - 语言映射里的 OCR 语言表、OCR 专用正则和图片工具。
  - 截图提示音工具。
  - `⌥S` 只翻译剪贴板文字。
- **Apple 词典**：删除以下内容：
  - 服务本身和 `DictionaryKit`。
  - 标题栏快捷按钮与快捷键、`x-dictionary` 链接处理。
  - Apple 系统翻译。
  - `AppleService` 只保留语言检测。
  - Anki 预览只用 MDict。
- **拆词判断**：新增 `EnglishWordChecker`，用系统拼写词典判断单个英文词，供 `segmentWords` 使用。
  - 先转小写，同时接受美式和英式拼写。
  - 所有检查走同一个串行队列。
- **服务列表**：注册表固定为注音、MDict、自定义 OpenAI，删除以下内容：
  - 官方 OpenAI。
  - 添加/删除服务界面与风险提示。
  - `#uuid` 多实例标识：`QueryService.uuid`、`QueryServiceConfiguration.uuid`、`serviceTypeWithUniqueIdentifier`。
    其中 `serviceTypeWithUniqueIdentifier` 改为 `serviceTypeId` 和 `serviceType`。
  - `LocalStorage.allServiceTypes` 会丢弃已删除的类型，并以停用状态补上缺少的服务。
- **迁移**：`ServiceListMigration` 替代 `OllamaServiceMigration`，在 `LocalStorage` 初始化时运行。
  - 把 `CustomOpenAI#<uuid>`（有多个时取窗口顺序里的第一个）或旧 Ollama 的设置复制到单实例的键。
  - 复制各窗口的启用状态，并替换列表项。
  - 旧键保留。
- **Beta**：删除以下内容：
  - Beta 开关与 URL scheme 写入项。
  - 文言文识别和 `ChineseGenre` 分析器。
  - “包含测试版更新”设置键。
  - URL scheme 可写键只保留 `IntelligentQueryMode`。
- **资源与文档**：
  - 删除 265 条只属于已删功能的文案，以及无用服务图标和播放图标。
  - 同步 `SLIM.md`、`AGENTS.md`、架构与路径设计文档、词典目录说明。
  - build 号提升到 74。
- **测试**：删除被删代码对应的测试文件和用例，调整引用了 OCR 字段的测试夹具，没有新增测试。

### 设计意图

- **一并删除旧服务**：未注册旧服务当初只因与发音、语种识别耦合才保留，发音删掉后一并删除，`CryptoSwift` 也随之移除。
- **去掉多实例标识**：多实例标识只为“可添加多个”存在，去掉后服务标识就是类型本身。迁移按存储格式直接改写偏好，
  所以在 `LocalStorage` 规范化列表之前运行，否则旧列表项会先被当作未知类型丢掉。
- **拆词判断**：
  - Apple 词典删除后，拆词判断需要替代。系统拼写检查无需权限，词表比 Apple 词典的词条判断更宽。
  - 拼写检查跳过大小写混合的词，所以改为检查小写形式；`LaTeX`、`username` 不拆，`getUserName`、`viewDidLoad` 照常拆。
  - 判断集中在一个类型里，以后引入内置词典时只换这一处。
- **Objective-C 的改动**：查询控制器和窗口管理器只做了删除，没有新增 Objective-C 逻辑。

### 验证

- 构建：
  - Debug `xcodebuild build` 通过，本次文件没有 SwiftLint 警告。
  - `git diff --check` 通过；`Localizable.xcstrings`、`Package.resolved` 的 `jq -e .` 通过。
  - 文案只删了 265 条，其余条目内容与顺序不变。
- 测试：
  - `build-for-testing` 通过。
  - 跳过需要联网和系统权限的 `ServiceTests`、`SystemUtilitiesTests` 后，`test-without-building` 共 189 个测试。
  - 唯一失败的是 `Intelligent Chinese Type Detection`：本机系统语言含日语，`開門` 被识别为日语。
    这段逻辑本次只删除了 Beta 开关下的文言文分支，失败与改动无关。
  - 拆词用例（`LaTeX`、`'UIKit'`、`simpleWord`、`key_value`）全部通过。
- 迁移（Debug 版，测试后已恢复 Debug 偏好设置）：
  - 导入本机正式版设置后启动：三个窗口列表从 `Reading, AppleDictionary, CustomOpenAI#<uuid>` 变为
    `Reading, CustomOpenAI, MDict`。
  - 地址、模型、模型列表等 `EZCustomOpenAI*Key` 全部复制；各窗口启用状态保留，MDict 以停用状态补上。
  - 用 Debug 版原有的 Ollama 设置启动：列表同样迁移。
- 真实查询：
  - 正式版设置里的地址 `http://colab-tts:8000` 已无法解析（服务器已改为 `colab-llm:8000`），查询报 DNS 错误。
  - 临时改成 `http://colab-llm:8000/v1/chat/completions` 后再查，没有报错。
- 系统拼写检查与 Apple 词典的判断用 26 个样例对比过，见设计意图。
- Release：App 与 DMG 公证 Accepted，`spctl` 为 `Notarized Developer ID`；Release `v2.25.0-slim.8` 附 DMG
  （SHA-256 `b8337174…2dd4`）与 Sparkle 更新包（21684803 字节，上一版为 25490566 字节），appcast 指向 build 74。
- 未运行：
  - 集成测试 `ServiceTests`、`SystemUtilitiesTests`。
  - 设置界面的人工点击确认（无屏幕录制权限）。

### 受影响文件

- `Easydict/Swift/Service/`：删除 `Speech`、`Youdao`、`DeepL`、`Google`、`Bing`、`Baidu`、`CodexCLI`、
  `Apple/AppleOCREngine`、`Apple/AppleSpeechService`、`Apple/AppleTranslation`、`Dictionary/AppleDictionary`、
  `OpenAI/OpenAIService.swift`。
  新增 `Dictionary/EnglishWordChecker.swift`、`Model/Storage/ServiceListMigration.swift`。
- `Easydict/Swift/Feature/HTTPServer/`、`Easydict/Swift/Utility/ChineseGenre/`：删除
- `Easydict/objc/`：删除 `Service/AudioPlayer`、`Service/WebViewTranslator`、`Libraries/DictionaryKit`、
  `Libraries/FWEncryptorAES`、`ViewController/View/CustomButton/EZAudioButton`、`ViewController/View/CommonView`；
  修改查询控制器、窗口管理器、结果视图、标题栏
- `Easydict/Swift/Service/Model/`、`Easydict/Swift/View/SettingView/`、`Easydict/Swift/Feature/`
- `Easydict/App/Localizable.xcstrings`、`Easydict/App/Assets.xcassets`
- `Easydict.xcodeproj/project.pbxproj`、`Easydict.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `scripts/codex-runtime/`：删除
- `EasydictTests/`
- `SLIM.md`、`AGENTS.md`、`docs/`
- `appcast.xml`

### 后续事项

- 正式版设置里的自定义 OpenAI 地址仍是已失效的 `http://colab-tts:8000/v1/chat/completions`，需要改成
  `http://colab-llm:8000/v1/chat/completions`。
- 思考开关只对本机和私有网段地址检测，`colab-llm` 这类 Tailscale 主机名检测不到，开关不可用。
- 引入更好的词典（拆词判断、App 内查词、单词读音）时，从 `EnglishWordChecker` 和 `Service/Dictionary` 接入。
