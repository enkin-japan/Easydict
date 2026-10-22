## 2026-10-22 | 任务：打包中日注音词典并增加模型思考开关

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->

**Links:** 计划 [`2026-10-22-reading-dicts-thinking-toggle.md`](../../exec-plans/completed/2026-10/2026-10-22-reading-dicts-thinking-toggle.md)、
GitHub Release `v2.25.0-slim.4`（enkin-japan/Easydict）

### 执行上下文

- **Agent Name:** `Claude Code`
- **Model:** `claude-opus-5-5`
- **Environment:** `macOS 27.0.1 / Xcode 27.1 (27A9275)`

### 用户请求

为中文、日语读音寻找完善的词典并打包进注音服务；在自定义 API 设置中增加模型思考开关，仅在明确支持开关思考时
可操作，明确不支持或无法判断时保持改前默认并置灰；完成后发布新版本并在本机安装。

### 变更

- 注音词典：`scripts/reading-dict/update.sh` 按固定版本下载 phrase-pinyin-data、pinyin-data（MIT）与
  JmdictFurigana（MIT，数据派生自 JMdict，CC BY-SA 4.0），`generate.swift` 过滤后按键的 UTF-8 字节序排序并
  LZFSE 压缩为 `Easydict/Swift/Service/Reading/Resources/` 下三个资源（共约 6.6 MB），附 `ReadingDataLicenses.txt`。
- `ReadingTable`：把解压后的行保存为单个字节缓冲加行偏移，按首字段二分查找。
- 中文：`ReadingAnnotator.mandarin` 改为按词典双向最大匹配分词（词数少者优先，其次单字少者，平局取逆向），
  按词取读音；单字回退到 pinyin-data 常用读音，再回退系统转换；只差轻声的不标为多音字。
- 日语：保留 `CFStringTokenizer` 分词与读音；相邻纯汉字片段能组成词典词时合并，切分读音不在词典读音中时改用
  词典最常用读音（二日 → ふつか、三本 → さんぼん）；用 JmdictFurigana 逐字对齐假名；长音 おう/おお 视为等价
  匹配词典读音（大きい、通り、遠い）；查不到时沿用原送假名启发式。
- 思考开关：`StreamService` 增加 `supportsThinkingToggle`、`enableThinkingKey`（默认关闭）与能力检测接口；
  `OllamaThinkingProbe` 调用 Ollama `/api/show`，`capabilities` 含 `thinking` 且 `thinking.values` 同时含
  `false`/`true` 时判为可开关，只缓存确定结果；Ollama 与自定义 OpenAI 仅在可开关时发送
  `reasoning_effort`（开 `high`、关 `none`），否则不发送；自定义 OpenAI 只探测本机与局域网地址；
  `BaseOpenAIService` 在首次请求前先完成检测；设置页新增 `ThinkingToggleCell`，非可开关状态置灰并显示原因，
  6 种语言的文案写入 `Localizable.xcstrings`。
- `scripts/pbx_add.py` 支持把非 Swift 文件加入 Resources；build 号提升到 70；`SLIM.md` 补充说明。

### 设计意图

日语系统分词器的上下文读音已经可靠，问题集中在注音位置与少数切分错误，因此只用 JMdict 数据做对齐和有冲突时
的纠正，不替换分词器；中文系统转换逐字取音，必须引入词组词典和分词。词典改用排序字节表二分查找，避免数十万
个 Swift 字符串对象带来的内存开销。思考开关严格按“能明确检测才生效”，其余情况请求与改前完全一致；在可操作时
默认关闭，以消除每次二十余秒的思考等待。

### 验证

- 独立 probe（编译注音相关源码 + 真实资源）：银行/行长/重新/音乐/睡觉/长期/长江读音正确且高亮，觉得/喜欢不因
  轻声高亮；取り扱い、申し込み、手続き逐字对齐，二日 ふつか、三本 さんぼん、大きい おおきい、通り とおり正确；
  首次载入 0.03 秒，进程峰值内存 73 MB（散列表实现为 233 MB）。
- 本机 Ollama（`gemma4:26b-mlx`）经记录代理的真实请求：开关关闭时请求带 `reasoning_effort: none`、无思考内容、
  0.24 秒 / 0.57 秒完成；打开时为 `high` 且返回思考内容；首次请求前 `/api/show` 检测为 `toggleable`（10 ms）。
  关闭状态下的第一次请求耗时 29.7 秒，之后复现均在 1 秒内，原因未能确认（Ollama 日志未记录）。
- `xcodebuild build`（Debug）通过且本次文件无 SwiftLint 警告；`git diff --check`、`bash -n`、`jq -e .` 通过。
- 未运行 `xcodebuild test`；设置页的置灰效果未截图确认（终端无屏幕录制权限）。

### 受影响文件

- `Easydict/Swift/Service/Reading/ReadingAnnotator.swift`
- `Easydict/Swift/Service/Reading/ReadingTable.swift`
- `Easydict/Swift/Service/Reading/ChinesePinyinDictionary.swift`
- `Easydict/Swift/Service/Reading/JapaneseFuriganaDictionary.swift`
- `Easydict/Swift/Service/Reading/Resources/`
- `Easydict/Swift/Service/Ollama/OllamaThinkingProbe.swift`
- `Easydict/Swift/Service/Ollama/OllamaService.swift`
- `Easydict/Swift/Service/CustomOpenAI/CustomOpenAIService.swift`
- `Easydict/Swift/Service/OpenAI/BaseOpenAIService.swift`
- `Easydict/Swift/Service/OpenAI/StreamService.swift`
- `Easydict/Swift/Feature/Configuration/ServiceConfigurationKey.swift`
- `Easydict/Swift/View/SettingView/Tabs/ServiceConfigurationView/ThinkingToggleCell.swift`
- `Easydict/Swift/View/SettingView/Tabs/ServiceConfigurationView/StreamConfigurationView.swift`
- `Easydict/App/Localizable.xcstrings`
- `Easydict.xcodeproj/project.pbxproj`
- `scripts/reading-dict/update.sh`
- `scripts/reading-dict/generate.swift`
- `scripts/pbx_add.py`
- `SLIM.md`
- `appcast.xml`

### 后续事项

- 中文真正歧义的多音字（这一行字）仍取默认读音；日语读音与词典冲突时取最常用读音，个别人名地名可能被改成常用读法。
- 非 Ollama 的本地服务（llama.cpp、LM Studio）无法检测思考能力，开关保持置灰。
