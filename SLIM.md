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

**保留**
- 查询服务：Apple 词典、MDict、Ollama、OpenAI 官方 API（需自备 API Key）、自定义 OpenAI 兼容 API（可多个实例）
- 划词翻译（需要辅助功能权限）、输入翻译、剪贴板翻译
- 生词本、Anki 导出、图片 OCR（剪贴板里的图片，用系统 Vision 离线识别）

**新增**
- **注音服务**（默认启用，完全离线）：日语显示振り仮名，中文显示带声调拼音；
  “在这个词里的读音 ≠ 单字默认读音”的多音字会高亮并列出。
  - 中文：按打包的词组拼音词典（phrase-pinyin-data，约 41 万词）做双向最大匹配，再按词取读音，
    查不到的字用 pinyin-data 的常用读音；只差轻声的不算多音字。
  - 日语：系统分词器给出读音，再用打包的 JmdictFurigana（JMdict 派生，约 23 万词）逐字对齐假名，
    纠正被切开读错的词（二日 → ふつか）和长音 おう/おお（大きい、通り）。
  - 词典压缩后约 6.6 MB，首次注音时载入（约 0.03 秒），常驻内存约 25 MB；数据许可见
    `Easydict/Swift/Service/Reading/Resources/ReadingDataLicenses.txt`。
- **思考开关**（Ollama / 自定义 OpenAI 服务设置）：通过 Ollama 的 `/api/show` 检测当前模型，只有明确支持
  开关思考时才可操作，默认关闭（请求带 `reasoning_effort: none`，打开时为 `high`）；明确不支持或无法判断时
  开关置灰，请求保持原来的服务端默认。自定义 OpenAI 只对本机和局域网地址检测，不会向云端服务发额外请求。
- **发音**（设置 › 高级 › 发音）：引擎可选“系统声音”或“本地 TTS（OpenAI 兼容）”。
  - 系统声音改用 `AVSpeechSynthesizer`，默认自动选质量最高的语音（高品质 > 增强 > 普通，排除 Eloquence、
    MacinTalk 和趣味音色），中文、日语、英语可分别指定。Siri 语音不对第三方 App 开放，想要更好的系统音质需在
    “系统设置 › 辅助功能 › 朗读内容 › 系统语音 › 管理语音”下载增强/高品质语音。
  - 本地 TTS 调用 `POST /v1/audio/speech`（OpenAI 的语音接口，Kokoro-FastAPI、mlx-audio、LocalAI 等都兼容），
    可配置地址、API Key、模型和中文/日语/英语/其他语言各自的 voice；默认值对应本机 Kokoro-FastAPI
    （`http://localhost:8880/v1/audio/speech`、`kokoro`、`zf_xiaobei` / `jf_alpha` / `af_heart`）。
    请求失败时自动改用系统声音；最近 50 条音频缓存在内存里，重复播放不再请求；每一行都有试听按钮，
    试听失败会显示服务器返回的错误。
- **右键 → 服务**（零权限）：
  - `Easydict 查询`：用选中文字打开查询窗口
  - `Easydict 翻译并替换`：用第一个启用的 Ollama / 自定义 OpenAI 服务翻译，直接替换选中文字（写邮件回复时用）
- `⌥S` 默认改为“剪贴板翻译”：先用你自己的截图工具把截图复制到剪贴板，再按 `⌥S` 即可 OCR + 翻译。
- Bundle ID 改为 `dev.enkin.EasydictSlim`，不会与官方版冲突，也不会被官方更新覆盖。
- Release 用自己的 Developer ID（Team `9A84P4ZS84`）签名并公证：签名身份固定，更新后不用重新授予辅助功能权限，
  其他 Mac 下载后也能直接打开。Debug 仍是本机 ad-hoc 签名。
- Sparkle 自动更新改为读取本 fork 的 `appcast.xml`（`dev` 分支），菜单栏菜单和 App 菜单都有“检查更新”。

以下服务的源码还留在工程里，但**没有注册、不会出现、不会联网**：有道、DeepL、Google、Bing、百度、Codex CLI。
它们与语种识别、发音等模块耦合较深，等第一次编译通过后可以再逐个物理删除。

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

## 推荐的大模型 Prompt（填在 自定义 OpenAI / Ollama 服务的自定义提示词里）

```
你是中日双语翻译兼语言老师。对用户给出的文本：
1. 给出自然流畅的译文（中→日，日→中）。
2. 原文逐句标注读音：日语用「漢字(かな)」格式标注振假名；中文用带声调的拼音。
3. 必须根据上下文判断多音字或多种读法，并单独列出这些字，说明为什么在这里读这个音。
4. 如果只输入一个词，按词典格式输出：读音、词性、释义、2 个例句。
```

“注音”服务给出的是词典的确定性读音，大模型负责翻译和解释，两者可以互相对照。

**注意**：“翻译并替换”用的是服务列表里**第一个**启用的 AI 服务，它的输出会原样写回你的文本框。
建议建两个自定义 OpenAI 实例（指向同一个本地 API）：排在前面的那个不填自定义提示词，只做纯翻译；
排在后面的那个用上面的“老师”提示词，负责在查询窗口里讲解。

## 工具脚本

- `scripts/pbx_remove.py`：从 `project.pbxproj` 中删除文件/目录或 Swift Package
- `scripts/pbx_add.py`：把新的 Swift 文件（Sources）或资源文件（Resources）加入 target
- `scripts/reading-dict/update.sh`：按固定版本下载词典源数据，重新生成注音词典资源
