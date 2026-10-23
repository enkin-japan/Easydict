## 2026-10-23 | 任务：内置日英词典与单词发音，句子分析只给意译，日语查词路由

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->

**Links:** 计划 [`2026-10-23-builtin-dictionary.md`](../../exec-plans/completed/2026-10/2026-10-23-builtin-dictionary.md)、
GitHub Release `v2.25.0-slim.10`（enkin-japan/Easydict）

### 执行上下文

- **Agent Name:** `Claude Code`
- **Model:** `claude-opus-5-5`
- **Environment:** `macOS 27.0.1 / Xcode 27.1 (27A9275)`

### 用户请求

- 按讨论的方案做出 App 内查词和单词发音（日语、英语为主，母语中文）。
- 文本翻译只用意译，去掉所有直译。
- 排查“句子分析”和“查单词”开关有时失效的原因。
- 完成后发布新版本并在本机安装。

### 变更

- **内置词典服务**（`Service/Dictionary/Builtin/`）：
  - `scripts/builtin-dict/update.sh` 按固定版本下载 ECDICT、jmdict-simplified（JMdict 带例句、
    KANJIDIC2）、Kanjium 声调，`generate.py` 生成 SQLite（英语约 45 万条、日语约 22 万条、
    汉字约 1 万个），用 LZMA 压缩为 `builtin-dictionary.sqlite.xz`（约 26 MB）。
  - `BuiltinDictionaryStore` 在每个 build 首次使用时把数据库解压到 `cache/builtin-dictionary/`，
    之后只读查询，所有访问由一把锁串行；`isReady` 不等待解压。
  - `JapaneseDeinflector` 用后缀规则把活用形还原成原形（ます、た/て、ない、たい、可能/被动/使役、意志、
    假定、命令、ている/ちゃう 等，可连锁），候选带词类，由 JMdict 词性校验。
  - `BuiltinDictionary` 汇总查词和排序；`BuiltinDictionaryHTML` 渲染结果页：日语振假名、声调高低线与
    类型、词性中文名、例句、汉字（音训、拼音、含义）；英语音标、中文释义、词形变化、柯林斯星级、牛津
    3000、考试标签、英文释义。
  - `WordPronouncer` 用系统离线语音朗读，选同地区里质量最高的语音；结果页按钮发 `pronounce` 消息，
    `EZWebViewManager` 转给它。
  - 新服务类型 `BuiltinDictionary`、图标和文案；升级时插到各窗口列表第一位并启用。
- **句子分析**：去掉直译，意译放在第一项；改用说明“意译加讲解”的系统提示词，不再沿用“只返回译文”的
  翻译系统提示词。中英文 few-shot 同步修改。
- **开关路由**：
  - 句子分析从只对英语改为对英语和日语。
  - 查单词新增日语：JMdict 里的词或其活用形；提示词附 JMdict 的读音、声调和释义，要求给出假名读音、
    声调和活用类型，并补上近义词等项。
  - `String.queryType` 与 `StreamService.queryType` 共用 `sentenceAnalysisLanguages`。
- **划词拆分**：`EnglishWordChecker` 先查 ECDICT 词表和变形表，词典未就绪或查不到时用系统拼写词典。
- **文档**：`SLIM.md`、架构文档、`dictionary-overview.md`；build 号提升到 76。
- **测试**：新增 `BuiltinDictionaryTests`（键归一化、12 个活用还原用例、读音与声调、同音词排序、
  英语变形、拆词判断、日语路由）。

### 设计意图

- **开关失效的原因**在 App 的路由，不在模型：句子分析只对英语生效，查单词只对英语单词和中文词生效，
  日语一律走普通翻译。用本地 gemma 复现时，即使系统提示词写着“只返回译文”，模型也稳定输出完整分析；
  但这个系统提示词与句子分析矛盾，所以一并换掉。
- **数据与格式**：没有可用的开放日汉词典，日语用 JMdict 英文释义加大模型中文讲解。数据量大，用按需
  查询的 SQLite，不像注音服务那样常驻内存。裁剪和压缩方式的取舍见计划。
- **排序**：精确匹配优先，然后依次比较是否常用词、主写法或主读音是否等于查询词、规则的具体程度、
  步数，让 `行った` 先给 `行く`、`見られている` 先给 `見る`、`はし` 不先给 `嘴`。
- **路由不阻塞**：查询类型判断和拆词只在数据库已打开时查词，否则立即回退并在后台打开；服务创建时也会
  提前在后台打开。
- **发音**：日语读词典给出的假名读音，避免语音引擎把汉字读错；声调以 Kanjium 为准，画在读音上。

### 验证

- 构建与静态检查：
  - Debug `xcodebuild build`、`build-for-testing` 通过，新文件没有警告。
  - `git diff --check`、`jq -e .`（`Localizable.xcstrings`、图标 `Contents.json`）、`sh -n update.sh`、
    `py_compile generate.py` 通过。
  - `update.sh` 两次生成的压缩包大小一致（25987176 字节）。
- 单元测试：
  - `BuiltinDictionaryTests` 8 个、`StringAnalysisTests` 通过。
  - 跳过 `ServiceTests`、`SystemUtilitiesTests` 后全量 196 个测试，只有已知的 `Intelligent Chinese Type
    Detection` 失败：本机系统语言含日语，与本次改动无关。
- 提示词：用本机 `colab-llm` 上的 gemma 回放句子分析提示词（英语 2 句、日语 1 句，各 2–3 次）。
  - 修改前：输出含直译。
  - 修改后：只有意译、重点词汇、语法分析，日语句子同样完整。
- 渲染：导出日语（食べなかった、はし、東京、行っちゃった、綺麗）和英语（went、run 等）结果页，在浏览器
  预览中检查读音、声调线、例句、汉字、按钮和深色配色。
- Debug 版端到端：
  - 首次解压用时 0.74 秒；服务列表变为 `BuiltinDictionary, Reading, MDict, CustomOpenAI`。
  - URL scheme 查询「食べなかった」后结果窗口按内容增高，日志没有内置词典错误。
  - 测试后恢复 Debug 偏好设置。
- Review：线程安全、SQLite 使用、路由影响和列表规范化。修复两处 P3：英语排序比较函数不满足严格弱序；
  解压文件只按压缩包大小判断新旧，改为同时带 build 号。
- 未验证：
  - 发音按钮的实际朗读，没有在本机放声，也没有在结果窗口里点击。
  - 设置界面和结果窗口的人工查看，因为没有屏幕录制权限。

### 受影响文件

- `Easydict/Swift/Service/Dictionary/Builtin/`（新增，含 `Resources/`）
- `Easydict/Swift/Service/Dictionary/EnglishWordChecker.swift`、`dictionary-overview.md`
- `Easydict/Swift/Service/OpenAI/StreamService+Prompt.swift`、`StreamService.swift`
- `Easydict/Swift/Utility/Extensions/String/String+Analysis.swift`
- `Easydict/Swift/Service/Model/QueryServiceFactory.swift`、`Storage/LocalStorage.swift`
- `Easydict/objc/Service/Model/EZEnumTypes.h`、`EZEnumTypes.m`
- `Easydict/objc/ViewController/View/WordResultView/EZWebViewManager.m`
- `Easydict/objc/ViewController/Window/BaseQueryWindow/EZBaseQueryViewController.m`
- `Easydict/App/Localizable.xcstrings`、`Easydict/App/Assets.xcassets/service-icon/BuiltinDictionary.imageset/`
- `EasydictTests/Service/BuiltinDictionaryTests.swift`
- `scripts/builtin-dict/`
- `Easydict.xcodeproj/project.pbxproj`
- `SLIM.md`、`docs/design-docs/application-architecture.md`、`docs/exec-plans/`、`docs/histories/`
- `appcast.xml`

### 后续事项

- 独立的查词窗口（搜索框、候选列表、历史、加入生词本）。
- 有带音频的 MDict 词典时，优先播放真人录音。
- Anki 导出目前只认 MDict 词条，可以加上内置词典。
