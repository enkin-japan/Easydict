## 2026-10-21 | 任务：整合精简版、修复编译并发布 DMG

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->

**Links:** [`SLIM.md`](../../../SLIM.md)、GitHub Release `v2.25.0-slim.1`（ad-hoc）与 `v2.25.0-slim.2`（Developer ID 公证）（enkin-japan/Easydict）

### 执行上下文

- **Agent Name:** `Claude Code`
- **Model:** `claude-opus-5-5`
- **Environment:** `macOS 27.0.1 / Xcode 27.1 (27A9275)`

### 用户请求

评估个人精简版（只保留查词、翻译、读音，去掉 OCR 截图和云端服务，只用自定义 API / 本地模型）是否合理，
并首次编译运行；随后把本地精简版整合进用户 fork，只保留最终版本，并发布 DMG 供多台设备下载安装；
之后改用 Developer ID 签名并公证，避免每次更新都要重新授予权限。

### 变更

- `AppleDictionary.swift`：`import SystemPackage` 改为系统自带的 `import System`。SystemPackage 原先由
  已删除的 Vapor 依赖间接提供，删除后无法解析模块。
- `SystemServiceProvider.swift`：Objective-C 方法桥接到 Swift 后名为 `showFloating(_:queryText:autoQuery:actionType:)`，
  修正调用名。
- `String+EncryptAES.swift`：精简时为 `sha256()` 引入 `CryptoKit`，与 `CryptoSwift` 的 `AES` 冲突，
  显式写成 `CryptoSwift.AES`。
- `EZBaseQueryViewController.m`：删除向 `LocalStorage` 兜底请求有道服务的代码。有道已不注册，
  Debug 版会在打开查询窗口时触发 `assertionFailure` 崩溃；`preferYoudaoTTSForEnglishWord` 在精简版固定为
  `false`，该实例不会被使用。
- Git 整合：本地目录原本不是 Git 仓库。初始化后接入 fork（`origin`）与上游（`upstream`），以 `SLIM.md`
  记录的基准 `b4eced7` 为父提交，把精简与上述修复合并为 fork `dev` 分支上的单个提交；`.claude/CLAUDE.md`
  与 `.claude/skills` 恢复为上游的符号链接（本地是内容相同的副本）。
- 发布：以 Release 配置归档 arm64 + x86_64 通用版，ad-hoc 签名，打包为 `Easydict-Slim-2.25.0.dmg`，
  发布到 fork 的 GitHub Release `v2.25.0-slim.1`。
- 签名：ad-hoc 签名的 designated requirement 是 cdhash，每次编译都会变，辅助功能授权随之失效。Release target
  恢复上游的 `CODE_SIGN_IDENTITY[sdk=macosx*] = "Developer ID Application"`，Team 改为 `9A84P4ZS84`；归档时
  传入 `--timestamp` 并指定登录钥匙串（同一证书也在系统钥匙串中）。App 与 DMG 用 App Store Connect API Key
  公证并装订，发布为 `v2.25.0-slim.2`；`SLIM.md` 补充发布步骤并修正打开 workspace 的路径。

### 设计意图

只做让精简版能编译、能查询的最小修复，不扩大删除范围；剩余未注册服务的物理删除留待后续。
按用户要求只保留最终使用版本：精简与修复合为一个提交，直接快进 fork 的 `dev`，不另设分支；上游历史保留，
以后仍可从 `upstream` 合并更新。Developer ID 让签名身份变为“Team ID + Bundle ID”，跨编译保持不变；Debug 仍用
ad-hoc，不受影响。
构建阶段的 SwiftFormat 会改写源码，提交中包含其对 5 个精简时修改文件的格式化结果；Release 归档设置
`EASYDICT_RELEASE_PACKAGING=YES` 跳过该步骤。

### 验证

- `xcodebuild build -workspace Easydict.xcworkspace -scheme Easydict -configuration Debug`：通过。
- 手动检查：通过 `easydict://query?text=...` 查询“行长”“pronunciation”“生行”，App 不再崩溃；Apple 词典、
  注音服务正常返回；Ollama 因本机 `localhost:11434` 未运行而报连接失败（预期）。
- 未运行 `xcodebuild test`。
- `git diff --check`：无空白错误。
- `xcodebuild archive -configuration Release -destination generic/platform=macOS`：通过，arm64 + x86_64。
- `codesign --verify --deep --strict`：App 与 3 个内嵌 framework 均为 Team `9A84P4ZS84` 签名并带安全时间戳，
  启用 Hardened Runtime。
- `notarytool submit --wait`：App 与 DMG 公证结果均为 Accepted，App 日志无 issues；两者均已 `stapler staple`。
- `spctl -a`：DMG 与其中的 App 均为 `accepted`，`source=Notarized Developer ID`。

### 受影响文件

- `Easydict/Swift/Service/Dictionary/AppleDictionary/AppleDictionary.swift`
- `Easydict/Swift/Feature/SystemService/SystemServiceProvider.swift`
- `Easydict/Swift/Utility/Extensions/String/String+EncryptAES.swift`
- `Easydict/objc/ViewController/Window/BaseQueryWindow/EZBaseQueryViewController.m`
- `Easydict.xcodeproj/project.pbxproj`
- `SLIM.md`

### 后续事项

- 物理删除未注册的有道、DeepL、Google、Bing、百度、OpenAI、Codex CLI 源码及 `TTSServiceType` 中的在线选项。
- 若确实不需要 OCR，可移除剪贴板图片 OCR 并恢复 `⌥S` 的原有绑定。
