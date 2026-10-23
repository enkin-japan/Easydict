## 2026-10-23 | 任务：新增“侧悬浮窗口始终显示”设置

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->

**Links:** GitHub Release `v2.25.0-slim.9`（enkin-japan/Easydict）

### 执行上下文

- **Agent Name:** `Claude Code`
- **Model:** `claude-opus-5-5`
- **Environment:** `macOS 27.0.1 / Xcode 27.1 (27A9275)`

### 用户请求

在设置中添加侧悬浮窗口是否持续显示的选项：打开后，点击其他 App 时侧悬浮窗口保持显示，不消失也不隐藏。
完成后发布新版本并在本机安装。

### 变更

- 新增设置键 `keepFixedWindowVisible`（`EZConfiguration_kKeepFixedWindowVisible`，默认关闭），
  `MyConfiguration` 同步暴露给 Objective-C。
- `EZWindowManager` 显示窗口时，侧悬浮窗口在该设置打开时自动钉住（与“当窗口显示时自动钉住”取或）。
- 设置切换时，正在显示的侧悬浮窗口立即钉住或恢复；没有显示时不为此创建窗口。
- 高级设置“窗口管理”新增开关，六种语言文案；`SLIM.md` 补充说明。

### 设计意图

- 复用现有的钉住状态，而不是另加一套“不关闭”逻辑：钉住同时满足“失去焦点和点击外部不关闭”和
  “浮在其他窗口之上”，否则点击其他 App 后窗口会被其窗口盖住，看起来仍像消失了。
- 标题栏钉住按钮照常反映并可切换这一状态；Esc 和关闭按钮仍会关闭窗口，下次显示时重新钉住。
- 已有的“当窗口显示时自动钉住”同时作用于迷你窗口，新开关只管侧悬浮窗口，迷你窗口仍点外部即关。

### 验证

- Debug `xcodebuild build` 通过，改动文件没有警告；`git diff --check` 与 `Localizable.xcstrings` 的
  `jq -e .` 通过。
- Debug 版实测（用 `CGWindowListCopyWindowInfo` 看窗口，测试后恢复 Debug 偏好设置）：
  - 开关关闭：URL scheme 打开侧悬浮窗口后切到访达，窗口关闭。
  - 开关打开：窗口层级为 19（钉住），切到访达后仍显示。
  - 窗口显示时切换开关：打开后立即钉住，再关闭后恢复普通层级。
- 未运行：单元测试（改动不涉及已有测试覆盖的逻辑）；设置界面的人工点击确认。

### 受影响文件

- `Easydict/Swift/Feature/Configuration/Defaults.Keys+Extension.swift`
- `Easydict/Swift/Feature/Configuration/MyConfiguration.swift`
- `Easydict/Swift/View/SettingView/Tabs/TabView/AdvancedTab.swift`
- `Easydict/objc/ViewController/Window/WindowManager/EZWindowManager.m`
- `Easydict/App/Localizable.xcstrings`
- `SLIM.md`
- `Easydict.xcodeproj/project.pbxproj`（build 号）
- `appcast.xml`

### 后续事项

- None
