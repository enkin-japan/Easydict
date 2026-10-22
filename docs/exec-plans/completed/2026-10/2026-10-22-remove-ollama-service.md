# 移除 Ollama 服务并迁移到自定义 OpenAI

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

用户改用 mlx-vlm 自建的 OpenAI 兼容服务（端口 8000），它没有 Ollama 的 `/api/tags`，Ollama 服务类型获取模型列表会失败。
用户决定统一用自定义 OpenAI 接入，删除 Ollama 服务。本机现有配置只有 Ollama 服务（已指向端口 8000）。

## 目标与范围

- 目标结果：服务列表不再提供 Ollama；已有 Ollama 服务自动变成设置相同的自定义 OpenAI 实例；自定义 OpenAI 不填 API Key 也能翻译和获取模型列表。
- 允许修改路径：`Easydict/Swift/Service/`、`Easydict/Swift/Feature/ActionManager/`、`Easydict/Swift/View/SettingView/`、
  `Easydict/App/`、`Easydict.xcodeproj/project.pbxproj`、`SLIM.md`、`appcast.xml`、本计划与同任务 history。
- 同任务 history：`docs/histories/2026-10/2026-10-22-remove-ollama-service.md`
- 用户限制：完成后发布新版本 DMG 并在本机安装。
- 非目标：修改用户的 API 服务；思考开关改用其他检测方式。
- 验收标准：构建通过；旧 Ollama 配置启动后迁移且只迁移一次；迁移后的服务无 Key 时真实翻译成功；发布并安装。

## 工作计划

1. 删除 `OllamaService` / `OllamaModel`，`OllamaThinkingProbe` 移到 `CustomOpenAI/` 继续供思考开关使用。
2. 新增启动迁移，把 `EZOllama*Key` 设置、服务列表位置和各窗口启用状态转到新的自定义 OpenAI 实例。
3. 自定义 OpenAI 的 API Key 改为可选。
4. 验证、发布与安装。

## 风险与决策

- 迁移不删除旧 Ollama 设置，回退旧版本仍可用；判断条件是服务列表里是否还有 `Ollama`，因此只执行一次。
- API Key 可选后，需要 Key 的云端兼容服务在未填写时由服务器返回鉴权错误，不再在本地拦截。

## 进度

- [x] 删除 Ollama 服务
- [x] 启动迁移
- [x] API Key 可选
- [x] 验证、发布与安装

## 验证

- 见同任务 history。

## 完成条件

验收标准全部满足，history 已写。
