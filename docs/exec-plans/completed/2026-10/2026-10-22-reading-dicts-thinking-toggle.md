# 中日注音词典与模型思考开关

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

注音服务只依赖系统语言数据：中文 `kCFStringTransformMandarinLatin` 逐字取默认读音，多音字（银行、重新、
音乐、睡觉）全部读错，多音字高亮从不触发；日语 `CFStringTokenizer` 读音基本正确，但含送假名的复合词
注音错位（`取り扱(とりあつか)い`），熟语按整词注音，少数数词被切开读错（`二(ふた)日(か)`）。
Ollama / 自定义 OpenAI 不发送 `reasoning_effort`，`gemma4:26b-mlx` 默认思考，本机实测首字 27.8 秒，
发送 `none` 后 0.2 秒，而设置界面没有可用的思考开关。

## 目标与范围

- 目标结果：
  - 中文按词组拼音词典分词注音，多音字读对并高亮；单字读音用打包的字表。
  - 日语用 JMdict 派生的逐字假名对齐数据修正注音位置，并在词典能确定时纠正切分错误的读音。
  - Ollama 与自定义 OpenAI 增加思考开关：仅当能明确检测到模型支持开关思考时可操作；明确不支持或
    无法判断时保持改前行为（不发送参数）且开关置灰。
  - 发布 build 70（Sparkle），本机安装新版本。
- 允许修改路径：`Easydict/Swift/Service/Reading/`、读音词典资源与生成脚本、`Easydict/Swift/Service/Ollama/`、
  `Easydict/Swift/Service/CustomOpenAI/`、`Easydict/Swift/Service/OpenAI/` 中与思考参数相关的部分、
  对应设置视图、`Localizable.xcstrings`、`project.pbxproj`、`appcast.xml`、`SLIM.md`、本计划与 history。
- 同任务 history：`docs/histories/2026-10/2026-10-22-reading-dicts-thinking-toggle.md`
- 用户限制：只在明确支持时才允许操作思考开关；完成后推送新版本并在本机安装。
- 非目标：不引入形态素解析器或在线服务；不新增测试（未获授权）；不改其他服务的思考参数。
- 验收标准：
  - 中文：银行/行长/重新/音乐/睡觉/觉得读音正确，多音字高亮生效。
  - 日语：取り扱い、申し込み、手続き按单字对齐；二日读作ふつか；原本正确的读音不退化。
  - `gemma4:26b-mlx` 可切换思考；关时请求带 `reasoning_effort: none`；非 Ollama 端点开关置灰且请求不变。
  - Release 公证通过，appcast 指向 build 70，本机 `/Applications/Easydict.app` 为 build 70。

## 工作计划

1. 下载并检查词典数据（phrase-pinyin-data、pinyin-data、JmdictFurigana），写生成脚本输出压缩资源。
2. 实现词典加载与中文分词注音、日语逐字对齐与读音纠正。
3. 实现思考能力检测（Ollama `/api/show`）与开关、请求参数映射和设置界面。
4. Debug 构建与离线 probe 验证注音，真实请求验证思考开关；review。
5. 归档、导出、公证、签名更新包，发布 build 70，更新 appcast，本机安装。

## 风险与决策

- 词典许可：phrase-pinyin-data / pinyin-data 为 MIT（含 CC-CEDICT 派生数据）；JmdictFurigana 数据派生自
  JMdict（EDRDG，CC BY-SA 4.0），与 GPLv3 单向兼容，需要署名。
- 包体积：原始文本约 22 MB，使用 LZFSE 压缩打包，首次使用时懒加载。
- 日语读音纠正只在词典条目与切分结果明确冲突时生效，避免把上下文正确的读音改错。
- 思考开关默认关闭（仅在可操作时生效），以消除每次 20 秒以上的思考等待。

## 进度

- [x] 词典数据与生成脚本
- [x] 中文、日语注音实现（散列表实现峰值内存 233 MB，改为排序字节表二分查找后 73 MB）
- [x] 思考开关
- [x] 构建、验证与 review
- [x] 发布与本机安装

## 验证

- 注音 probe、本机 Ollama 代理请求、Debug 构建与静态检查结果见同任务 history。
- Release 归档、导出重签、App 与 DMG 公证均通过（Accepted），`spctl` 为 `Notarized Developer ID`；
  Sparkle 更新包已签名，appcast 指向 build 70。
- 未运行 `xcodebuild test`；设置页置灰效果未截图确认。

## 完成条件

- 验收标准全部满足，history 已记录，计划移入 `completed/2026-10/`。
