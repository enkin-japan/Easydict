# 词典服务

`Dictionary` 聚合 Easydict 的词典类能力和它们共用的 HTML 结果渲染基础设施。它只包含以本地
词典条目为核心的查询能力，不包含语言检测等平台能力。

## 目录结构

```
Dictionary/
├── MDict/                           # MDict/MDX/MDD 离线词典服务
├── DictionaryRendering/             # 共享 HTML 结果壳和 iframe 渲染
├── EnglishWordChecker.swift         # 判断文本是否为英文单词
└── dictionary-overview.md           # 本目录说明
```

## 职责边界

- `MDict` 负责导入、解析和查询 MDX/MDD 文件，并处理词典内资源。
- `DictionaryRendering` 接收各词典服务产出的 HTML section，组装结果面板模板。
- `EnglishWordChecker` 判断单个英文词是否真实存在，供划词拆分（`getUserName` → `get User Name`）
  使用；目前基于系统拼写词典，以后引入内置词典时只替换这一处。
- `Service/Apple` 只保留语言检测。

## 主要数据流

用户查询进入具体词典服务后，服务产出 `DictionaryHTMLSection`。共享渲染层把多个 section
组装到 `dictionary-result.html` 模板中，最终由结果面板的 WKWebView 加载。

## 调试入口

- MDict 未命中或资源缺失，检查 reader、manager 和资源路径重写。
- 结果高度或样式异常，检查 `DictionaryRendering` 的模板与 iframe 更新脚本。
- 划词后单词被错误拆开或没有拆开，检查 `EnglishWordChecker`。
