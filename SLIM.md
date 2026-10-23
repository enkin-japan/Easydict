# Easydict Slim（个人精简版）

基于 [tisfeng/Easydict](https://github.com/tisfeng/Easydict)（GPL-3.0）`dev` 分支 `b4eced7` 修改，仅供个人使用。

## 与原版的区别

**删除**
- 截图翻译 / 静默截图 OCR（不再需要“屏幕录制”权限）
- AppleScript 浏览器取词与取网址（不再需要“自动化”权限，浏览器改走辅助功能）
- 除 OpenAI 外的云端翻译与云端大模型服务：Gemini、Claude、DeepSeek、Groq、智谱、MiniMax、GitHub Models、豆包、阿里、火山、腾讯、彩云、小牛、内置 AI、润色/摘要、Claude Code、GitHub Copilot
- 内置 API Key、HTTP 服务器（Vapor）
- Firebase 统计、Sentry 崩溃上报、隐私设置页
- 在线语种识别优化（Google/百度）、有道 OCR、有道/必应/谷歌在线发音
- 发音：本地 TTS、查询框和翻译结果的播放按钮、自动朗读与 `⌘S` 朗读快捷键（单词发音只保留在内置词典里，
  用系统离线语音）
- OCR：图片识别（包括剪贴板图片）、OCR 窗口与相关设置；`⌥S` 只翻译剪贴板文字
- Apple 词典服务、标题栏“在词典中打开”按钮、Apple 系统翻译
- 官方 OpenAI 服务；服务列表的添加/删除入口，以及自定义 OpenAI 的多实例
- Beta 功能开关（文言文识别）与“包含测试版更新”
- 未注册的旧服务源码（有道、DeepL、Google、Bing、百度、Codex CLI）和 HTTP 服务残留，以及只供它们使用的
  `CryptoSwift`

**保留**
- 查询服务固定为四个：内置词典、注音、MDict、自定义 OpenAI 兼容 API（只有一个，API Key 可留空，本地或
  局域网的 `/v1/chat/completions` 都用它接）。各窗口只能启用、停用和排序，不能增删。
- 划词翻译（需要辅助功能权限）、输入翻译、剪贴板翻译
- 生词本、Anki 导出（词条来自 MDict）

**新增**
- **服务设置自动迁移**：升级后第一次启动时，旧版本的自定义 OpenAI 实例（`CustomOpenAI#<uuid>`，有多个时取
  窗口列表里的第一个）或更早的 Ollama 服务会转换成唯一的自定义 OpenAI，接口地址、模型、提示词等设置和各窗口的
  启用状态都保留；已删除的服务从列表中移除，缺少的服务以停用状态补上。旧设置不删除，回退到旧版本仍可使用。
- **侧悬浮窗口始终显示**（设置 › 高级 › 窗口管理，默认关闭）：打开后侧悬浮窗口每次显示都会自动钉住，点击其他
  App 也不会关闭，并且浮在其他窗口之上；按 Esc 或关闭按钮仍可关闭，手动取消钉住后恢复点击外部即关闭。
  “当窗口显示时自动钉住”对侧悬浮窗口和迷你窗口都生效，这一项只管侧悬浮窗口。
- **内置词典**（默认启用，完全离线）：日语和英语查词，结果显示在查询窗口里。
  - 日语：JMdict（约 22 万词）的读音、词性、英文释义和例句，配 Kanjium 的声调（约 10 万个读音有声调，画成
    高低线并标出平板、头高、中高、尾高），以及词中每个汉字的音读、训读、拼音和含义（KANJIDIC2）。
    活用形会还原成原形再查（食べなかった → 食べる、行っちゃった → 行く、勉強した → 勉強）。
  - 英语：ECDICT 的音标、中文释义、词形变化、柯林斯星级、牛津 3000 和考试标签；查 `went` 同时给出 `go`。
    ECDICT 里约 37 万条未分级的专业词组被裁掉，单词全部保留（约 45 万条）。
  - 发音按钮用系统离线语音朗读：日语读词典给的假名读音（避免汉字读错），英语分英音和美音。建议在
    “系统设置 › 辅助功能 › 朗读内容”里下载“优化音质”的日语和英语语音。
  - 数据库约 97 MB，LZMA 压缩后约 26 MB 打进 App，首次使用时解压到
    `~/Library/Application Support/<bundle-id>/cache/builtin-dictionary/`（约 0.7 秒）；
    重新生成用 `scripts/builtin-dict/update.sh`，数据许可见
    `Easydict/Swift/Service/Dictionary/Builtin/Resources/BuiltinDictionaryLicenses.txt`。
  - 升级后内置词典会排在各窗口服务列表的第一位并启用。
- **自定义 OpenAI 的句子分析和查单词**：
  - 句子分析只给意译，不再给直译。
  - 原来只有英语句子会做句子分析，英语单词和中文词才会查单词，日语一律只翻译，所以这两个开关对日语看起来
    “时灵时不灵”。现在日语句子也做句子分析；日语单词（含活用形）会查单词，并把内置词典的读音、声调和释义
    一起交给大模型，让它用中文讲解。
- **划词拆分**：选中 `getUserName` 这类代码文本时，先查内置词典的英文词表，再用系统拼写词典兜底，判断它是
  不是真实的英文单词，不是才拆成 `get User Name`。判断集中在 `EnglishWordChecker`。
- **注音服务**（默认启用，完全离线）：日语显示振り仮名，中文显示带声调拼音；
  “在这个词里的读音 ≠ 单字默认读音”的多音字会高亮并列出。
  - 中文：按打包的词组拼音词典（phrase-pinyin-data，约 41 万词）做双向最大匹配，再按词取读音，
    查不到的字用 pinyin-data 的常用读音；只差轻声的不算多音字。
  - 日语：系统分词器给出读音，再用打包的 JmdictFurigana（JMdict 派生，约 23 万词）逐字对齐假名，
    纠正被切开读错的词（二日 → ふつか）和长音 おう/おお（大きい、通り）。
  - 词典压缩后约 6.6 MB，首次注音时载入（约 0.03 秒），常驻内存约 25 MB；数据许可见
    `Easydict/Swift/Service/Reading/Resources/ReadingDataLicenses.txt`。
- **思考开关**（自定义 OpenAI 服务设置）：通过 Ollama 格式的 `/api/show` 检测当前模型，只有明确支持
  开关思考时才可操作，默认关闭（请求带 `reasoning_effort: none`，打开时为 `high`）；明确不支持或无法判断时
  开关置灰，请求保持原来的服务端默认。自定义 OpenAI 只对本机和局域网地址检测，不会向云端服务发额外请求。
- **获取模型列表**：勾选结果会替换原有列表，服务器已不再提供的旧模型会被移除；当前模型被移除时自动切到列表第一个。
- **右键 → 服务**（零权限）：
  - `Easydict 查询`：用选中文字打开查询窗口
  - `Easydict 翻译并替换`：用自定义 OpenAI 服务翻译，直接替换选中文字（写邮件回复时用）
- `⌥S` 默认改为“剪贴板翻译”：翻译剪贴板里的文字。
- Bundle ID 改为 `dev.enkin.EasydictSlim`，不会与官方版冲突，也不会被官方更新覆盖。
- Release 用自己的 Developer ID（Team `9A84P4ZS84`）签名并公证：签名身份固定，更新后不用重新授予辅助功能权限，
  其他 Mac 下载后也能直接打开。Debug 仍是本机 ad-hoc 签名。
- Sparkle 自动更新改为读取本 fork 的 `appcast.xml`（`dev` 分支），菜单栏菜单和 App 菜单都有“检查更新”。

## 编译

需要 Xcode（macOS 13+）。

```bash
open Easydict.xcworkspace        # 在仓库根目录执行，注意是 .xcworkspace
```

1. 第一次打开时 Xcode 会重新解析 Swift Package（已删掉 Firebase/Sentry/Vapor），等它完成。
2. Scheme 选 `Easydict`，`Product › Build`（⌘B）。
3. 把编译出来的 `Easydict.app` 拖到 `/Applications`，启动一次。

## 发布新版本

需要钥匙串里的 `Developer ID Application` 证书，以及有公证权限的 App Store Connect API Key
（`AuthKey_<KeyID>.p8` 与 Issuer ID），以及登录钥匙串里的 Sparkle EdDSA 私钥。

1. 归档通用版（arm64 + x86_64）：

   ```bash
   xcodebuild archive -workspace Easydict.xcworkspace -scheme Easydict -configuration Release \
     -destination generic/platform=macOS -archivePath build/Easydict.xcarchive \
     EASYDICT_RELEASE_PACKAGING=YES ENABLE_DEBUG_DYLIB=NO DEPLOYMENT_POSTPROCESSING=YES \
     "OTHER_CODE_SIGN_FLAGS=--timestamp --keychain $HOME/Library/Keychains/login.keychain-db"
   ```

   `EASYDICT_RELEASE_PACKAGING=YES` 会跳过构建时的 SwiftFormat，避免改写源码；指定登录钥匙串是因为
   同一张证书也在系统钥匙串里。
2. 用 `xcodebuild -exportArchive` 导出（导出选项：`method` 为 `developer-id`、`signingStyle` 为 `manual`、
   `teamID` 为 `9A84P4ZS84`）。归档本身不会重签 Sparkle 内置的 `Autoupdate`、`Updater.app` 和 XPC 服务，
   只有导出后它们才是 Developer ID 签名，否则公证不通过。
3. 用 `xcrun notarytool submit --wait`（`--key`、`--key-id`、`--issuer`）公证导出 App 的 zip，再用
   `xcrun stapler staple` 装订。
4. 把 App 和指向 `/Applications` 的链接用 `hdiutil create -format UDZO` 打成 DMG，对 DMG 再签名、公证、装订。
5. 用装订后的 App 生成 Sparkle 更新包并签名（私钥在登录钥匙串，公钥写在 `Info.plist` 的 `SUPublicEDKey`）：

   ```bash
   ditto -c -k --sequesterRsrc --keepParent Easydict.app Easydict.zip
   "$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" Easydict.zip
   ```

6. `gh release create <tag> Easydict-Slim-<版本>.dmg Easydict.zip --repo enkin-japan/Easydict` 发布。
7. 在 `appcast.xml` 最前面加一个 `<item>`：`sparkle:version` 是 build 号（`CURRENT_PROJECT_VERSION`，
   每次发布必须递增），`enclosure` 指向该 Release 的 `Easydict.zip`，填上 `sign_update` 输出的
   `sparkle:edSignature` 和 `length`；提交并推送到 `dev` 后，已安装的 App 就能检查到更新。

如果“服务”菜单里没有出现 Easydict 的两项：
- 系统设置 › 键盘 › 键盘快捷键 › 服务 › 文本，勾选它们（这里也可以绑定全局快捷键）；
- 或在终端执行 `/System/Library/CoreServices/pbs -update` 后重新登录。

## 推荐的大模型 Prompt（填在 自定义 OpenAI 服务的自定义提示词里）

```
你是中日双语翻译兼语言老师。对用户给出的文本：
1. 给出自然流畅的译文（中→日，日→中）。
2. 原文逐句标注读音：日语用「漢字(かな)」格式标注振假名；中文用带声调的拼音。
3. 必须根据上下文判断多音字或多种读法，并单独列出这些字，说明为什么在这里读这个音。
4. 如果只输入一个词，按词典格式输出：读音、词性、释义、2 个例句。
```

“注音”服务给出的是词典的确定性读音，大模型负责翻译和解释，两者可以互相对照。

**注意**：“翻译并替换”也用这个自定义 OpenAI 服务，它的输出会原样写回你的文本框。自定义 OpenAI 只有一个，
填了上面的“老师”提示词后，“翻译并替换”写回的也会是带讲解的内容；只想替换成纯译文时不要填自定义提示词。

## 工具脚本

- `scripts/pbx_remove.py`：从 `project.pbxproj` 中删除文件/目录或 Swift Package
- `scripts/pbx_add.py`：把新的 Swift 文件（Sources）或资源文件（Resources）加入 target
- `scripts/reading-dict/update.sh`：按固定版本下载词典源数据，重新生成注音词典资源
