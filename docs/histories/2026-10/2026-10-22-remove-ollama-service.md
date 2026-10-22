## 2026-10-22 | 任务：移除 Ollama 服务并迁移到自定义 OpenAI

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->

**Links:** 计划 [`2026-10-22-remove-ollama-service.md`](../../exec-plans/completed/2026-10/2026-10-22-remove-ollama-service.md)、
GitHub Release `v2.25.0-slim.6`（enkin-japan/Easydict）

### 执行上下文

- **Agent Name:** `Claude Code`
- **Model:** `claude-opus-5-5`
- **Environment:** `macOS 27.0.1 / Xcode 27.1 (27A9275)`

### 用户请求

本地 API 改用 mlx-vlm 自建服务（端口 8000），统一用自定义 OpenAI 接入，删除 Ollama 服务；完成后发布新版本并在本机安装。

### 变更

- 删除 `OllamaService.swift`、`OllamaModel.swift` 及其注册；默认服务列表不再包含 Ollama；`OllamaThinkingProbe` 移到
  `Service/CustomOpenAI/`，自定义 OpenAI 的思考开关继续用 Ollama 格式的 `/api/show` 检测。
- 新增 `OllamaServiceMigration`，在 `AppPathMigration` 之后运行：服务列表里还有 `Ollama` 时，生成一个自定义 OpenAI 实例，
  把所有 `EZOllama<设置>Key`（地址、模型、模型列表、提示词等）复制到 `EZCustomOpenAI<设置>_<uuid>_Key`，在各窗口原位置
  替换并沿用启用与参与查询状态；旧设置保留。
- 自定义 OpenAI 的 `apiKeyRequirement` 改为 `.none`（注册信息同步），请求与获取模型列表在 Key 为空时不带鉴权头，
  获取模型列表不再要求先填 Key。
- 删除不再使用的 `ollama_translate`、`service.configuration.fetch_models.local_title` 文案；“翻译并替换”的提示改为
  自定义 OpenAI / OpenAI；build 号提升到 72；`SLIM.md` 同步说明。

### 设计意图

本机只有 Ollama 一个翻译服务，直接删除会让升级后的每台 Mac 都失去翻译；按存储格式整体复制设置可以无感迁移，
也不需要逐项列出 Ollama 的设置键。迁移的触发条件就是服务列表里的 `Ollama`，替换后自然不会重复执行。
Ollama 服务原本不需要 Key，迁移后的自定义 OpenAI 也必须能无 Key 工作，否则本地服务会被“缺少密钥”拦截。

### 验证

- Debug `xcodebuild build` 通过，本次文件无 SwiftLint 警告；`git diff --check`、`jq -e .` 通过。
- 把本机正式版的 Ollama 配置（三个窗口的服务列表、服务信息、7 个 `EZOllama*Key`）导入 Debug 版，并把迷你窗口设为未启用：
  - 启动后三个窗口的 `Ollama` 都换成同一个 `CustomOpenAI#<uuid>`，地址 `http://localhost:8000/v1/chat/completions`、模型、
    模型列表等全部复制，迷你窗口保持未启用，其余保持启用。
  - 再次启动，服务列表与实例数量不变。
  - 首次真实查询报“缺少密钥”，据此把 API Key 改为可选；之后经记录代理转发到端口 8000 的真实翻译请求不带 `Authorization`，
    返回 200 并以 `data: [DONE]` 结束。`/api/show` 返回 404，思考开关保持置灰。
- 测试结束后 Debug 偏好设置恢复为测试前的备份，代理已停止。
- Release：App 与 DMG 公证 Accepted，`spctl` 为 `Notarized Developer ID`；Release `v2.25.0-slim.6` 附 DMG
  （SHA-256 `12bcf9c3…3c68`）与 Sparkle 更新包（25478659 字节），appcast 指向 build 72。
- 本机：build 71 移入废纸篓（未清空）后安装 build 72，首次启动日志记录迁移完成，三个窗口的服务列表变为
  `CustomOpenAI#<uuid>`（地址 `http://localhost:8000/v1/chat/completions`），真实查询经自定义 OpenAI 完成且无错误。
- 未运行：环境依赖的 `ServiceTests` 集成测试；“获取模型列表”按钮未在界面上点击确认（无屏幕录制权限）。

### 受影响文件

- `Easydict/Swift/Service/Ollama/`（删除）
- `Easydict/Swift/Service/CustomOpenAI/OllamaThinkingProbe.swift`
- `Easydict/Swift/Service/CustomOpenAI/OllamaServiceMigration.swift`
- `Easydict/Swift/Service/CustomOpenAI/CustomOpenAIService.swift`
- `Easydict/Swift/Service/OpenAI/BaseOpenAIService.swift`
- `Easydict/Swift/Service/Model/QueryServiceFactory.swift`
- `Easydict/Swift/Service/Model/Storage/LocalStorage.swift`
- `Easydict/Swift/Feature/ActionManager/ActionManager.swift`
- `Easydict/Swift/View/SettingView/Tabs/ServiceConfigurationView/StreamConfigurationView.swift`
- `Easydict/App/EasydictApp.swift`
- `Easydict/App/Localizable.xcstrings`
- `Easydict.xcodeproj/project.pbxproj`
- `SLIM.md`
- `appcast.xml`

### 后续事项

- 端口 8000 的服务没有 `/api/show`，思考开关保持置灰；服务端补上该接口后即可使用。
