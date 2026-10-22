# TTS 播放前唤醒输出设备，获取模型列表改为替换

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->
<!-- 本模板只用于多步骤、跨模块或高风险的执行任务。 -->

- 状态：completed
- 创建日期：2026-10-23
- 负责人：Claude Code
- 关联 Issue/PR：none

## 执行上下文

- **Agent Name:** `Claude Code`
- **Model:** `claude-opus-5-5`
- **Environment:** `macOS 27.0.1 / Xcode 27.1 (27A9275)`

## 背景

用户反馈本地 TTS 首次播放开头会丢掉零点几秒，重播正常。排查确认 API 返回的音频完整，重播用的是缓存里同一份音频；
本机默认输出是 USB 音箱，闲置时设备停流（`kAudioDevicePropertyDeviceIsRunningSomewhere` 为 0），重新出声时吞掉开头。
另外，“获取模型列表”只会新增模型，服务器已不提供的旧模型无法清除。

## 目标与范围

- 目标结果：TTS 播放开头不再被吞；获取模型列表后列表与勾选结果一致。
- 允许修改路径：`Easydict/Swift/Service/Speech/`、`Easydict/Swift/View/SettingView/Tabs/ServiceConfigurationView/`、
  `Easydict.xcodeproj/project.pbxproj`、`SLIM.md`、`appcast.xml`、本计划与同任务 history。
- 同任务 history：`docs/histories/2026-10/2026-10-23-tts-warmup-model-refresh.md`
- 用户限制：完成后发布新版本 DMG 并在本机安装。
- 非目标：修改端口 8000 的服务；系统声音的播放路径。
- 验收标准：设备闲置时 TTS 播放前设备已在运行；获取模型列表后旧模型被移除；发布并安装。

## 工作计划

1. 新增 `AudioOutputWarmer`，TTS 请求开始时启动只含混音器的 `AVAudioEngine` 向设备送静音，结束 30 秒后停止。
2. `RemoteModelsSheet` 保存时只保留勾选的模型。
3. 验证、发布与安装。

## 风险与决策

- 设备刚被唤醒时最多等 0.8 秒再播放：日语音色开头几乎没有静音，0.5 秒可能不够；只在设备闲置且音频回来得比这更快时才会等。
- 手动填写但服务器不提供的模型，刷新时也会被移除，这正是用户要的行为。

## 进度

- [x] 唤醒输出设备
- [x] 模型列表改为替换
- [x] 验证、发布与安装

## 验证

- 见同任务 history。

## 完成条件

验收标准全部满足，history 已写。
