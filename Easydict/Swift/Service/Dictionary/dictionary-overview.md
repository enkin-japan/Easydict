# 词典服务

`Dictionary` 聚合 Easydict 的词典类能力和它们共用的 HTML 结果渲染基础设施。它只包含以本地
词典条目为核心的查询能力，不包含语言检测等平台能力。

## 目录结构

```
Dictionary/
├── Builtin/                         # 内置词典服务：打包的 JMdict / ECDICT 数据库、活用还原、发音
├── MDict/                           # MDict/MDX/MDD 离线词典服务
├── DictionaryRendering/             # 共享 HTML 结果壳和 iframe 渲染
├── EnglishWordChecker.swift         # 判断文本是否为英文单词
└── dictionary-overview.md           # 本目录说明
```

## 职责边界

- `Builtin` 负责内置词典：
  - `BuiltinDictionaryStore` 是只读 SQLite，首次使用时把打包的 `builtin-dictionary.sqlite.xz` 解压到
    缓存目录。数据库由 `scripts/builtin-dict/update.sh` 生成。
  - `BuiltinDictionary` 是查词入口，日语查不到时用 `JapaneseDeinflector` 还原活用形。
  - `BuiltinDictionaryService` 和 `BuiltinDictionaryHTML` 渲染结果页；页面的发音按钮通过 web view 消息
    `pronounce` 交给 `WordPronouncer`，用系统离线语音朗读。
  - 查询类型判断（日语单词走查单词）和大模型查单词提示词里的 JMdict 参考也从这里取数据。
- `MDict` 负责导入、解析和查询 MDX/MDD 文件，并处理词典内资源。
- `DictionaryRendering` 接收各词典服务产出的 HTML section，组装结果面板模板。
- `EnglishWordChecker` 判断单个英文词是否真实存在，供划词拆分（`getUserName` → `get User Name`）
  使用；先查内置词典的 ECDICT 词表，词典还没打开或查不到时用系统拼写词典兜底。
- `Service/Apple` 只保留语言检测。

## 主要数据流

用户查询进入具体词典服务后，服务产出 `DictionaryHTMLSection`。共享渲染层把多个 section
组装到 `dictionary-result.html` 模板中，最终由结果面板的 WKWebView 加载。

## 调试入口

- MDict 未命中或资源缺失，检查 reader、manager 和资源路径重写。
- 结果高度或样式异常，检查 `DictionaryRendering` 的模板与 iframe 更新脚本。
- 划词后单词被错误拆开或没有拆开，检查 `EnglishWordChecker`。
- 内置词典查不到日语活用形或排序不对，检查 `JapaneseDeinflector` 的规则和 `BuiltinDictionary` 的排序；
  数据库打不开时看日志里的 `Built-in dictionary` 行和缓存目录 `cache/builtin-dictionary/`。
