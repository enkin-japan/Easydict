## 2026-10-23 | 任务：TTS 播放前唤醒输出设备，获取模型列表改为替换

<!-- 文件名：YYYY-MM-DD-<slug>.md；命名规则见 docs/histories/README.md 的“命名与 slug”。 -->

**Links:** 计划 [`2026-10-23-tts-warmup-model-refresh.md`](../../exec-plans/completed/2026-10/2026-10-23-tts-warmup-model-refresh.md)、
GitHub Release `v2.25.0-slim.7`（enkin-japan/Easydict）

### 执行上下文

- **Agent Name:** `Claude Code`
- **Model:** `claude-opus-5-5`
- **Environment:** `macOS 27.0.1 / Xcode 27.1 (27A9275)`

### 用户请求

本地 TTS 首次播放开头被吞零点几秒、重播正常，要求查明原因并按建议修复；另外“获取模型列表”只新增不删除，
旧模型无法清除。完成后发布新版本并在本机安装。

### 变更

- 新增 `AudioOutputWarmer`：TTS 请求开始时启动只含混音器的 `AVAudioEngine`，向默认输出设备送静音；设备刚被唤醒时
  播放前最多等满 0.8 秒；每次播放结束（`SpeechPlayer.finish()`）后 30 秒没有新播放才停止。
- `RemoteModelsSheet` 保存时只传勾选的模型，`updateModels` 按原顺序保留仍被勾选的模型并追加新勾选的，
  服务器不再提供或被取消勾选的模型移除；没有勾选任何模型时“好”按钮不可用。
- build 号提升到 73；`SLIM.md` 同步说明。

### 设计意图

API 返回的音频完整（首次与重复合成的语音都从 0.32 秒开始），App 重播用的是缓存里同一份音频，所以被吞的是播放端：
本机默认输出 Audioengine 2+（USB）闲置时停流，重新出声需要时间。提前送静音能利用等待合成的时间唤醒设备，
保持 30 秒覆盖连续查词的间隔；只有缓存命中且设备在睡眠时才会额外等待。只用混音器节点，不打开输入设备，
不会触发麦克风权限。模型列表以服务器结果为准，才能清掉迁移遗留的 Ollama 模型名。

### 验证

- Debug `xcodebuild build` 通过，本次文件无 SwiftLint 警告；`git diff --check` 通过。
- 用 CoreAudio 的 `kAudioDevicePropertyDeviceIsRunningSomewhere` 监视默认输出设备，并在 Debug 版自动朗读英文单词
  （测试后 Debug 偏好设置已恢复）：
  - 设备闲置时查新词：朗读开始后设备立即开始运行，音频到达后才播放；最后一次播放结束约 30 秒后设备停止。
  - 设备闲置时重播缓存的词：设备开始运行约 0.56 秒后才播放（当时等待值为 0.5 秒，Review 后改为 0.8 秒）。
  - 设备仍在运行时查新词：音频到达后立即播放，不额外等待。
- 模型列表合并逻辑用独立脚本复现：`gemma4:e4b-mlx, gemma4:26b-mlx, gemma-4-26b-a4b-it-4bit` 在服务器只提供
  `gemma-4-26b-a4b-it-4bit` 时变为只剩它；保留模型的顺序不变，新勾选的追加在后。
- Review：唤醒等待由 0.5 秒改为 0.8 秒（日语音频开头几乎没有静音），其余无 finding。
- 未运行：在设置界面点击“获取模型列表”（无屏幕录制和辅助功能权限）；无法用耳朵确认开头不再被吞。

### 受影响文件

- `Easydict/Swift/Service/Speech/AudioOutputWarmer.swift`
- `Easydict/Swift/Service/Speech/SpeechPlayer.swift`
- `Easydict/Swift/View/SettingView/Tabs/ServiceConfigurationView/StreamConfigurationView.swift`
- `Easydict.xcodeproj/project.pbxproj`
- `SLIM.md`
- `appcast.xml`

### 后续事项

- 端口 8000 的服务闲置约 20 分钟后，首个 TTS 请求用了 10.25 秒（服务器日志），首个翻译请求首字等了 24 秒；
  属于服务端问题，未在本项目处理。
