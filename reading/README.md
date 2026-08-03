# Reading

`e2` 的阅读材料模块。这里保留原独立 `reading` 仓库的完整内容；合并时只增加了 `reading/` 路径前缀，原 commit 未被 squash 或重写。

## 目录

```text
english1/ocr/        # 2010–2025 英语一 OCR 文本与 OCR 脚本
english1/papers/     # 2010–2025 英语一真题 PDF
english2/analysis/   # 英语二阅读复盘
english2/ocr/        # 2010–2025 英语二 OCR 文本与 OCR 脚本
english2/papers/     # 2010–2025 英语二真题 PDF
ielts16/             # IELTS 16 示例文章与翻译
VOCAB_PLAN.md        # 独立仓库时期的词汇收集计划
```

执行英语二阅读任务时，优先从 `english2/analysis/` 找已有复盘，再用 `english2/ocr/` 定位可搜索文本，最后用 `english2/papers/` 核对原始版面。英语一和 IELTS 材料保持独立，只有任务明确需要时才读取。

`VOCAB_PLAN.md` 是合并前的交接记录，其中的项目名和相对路径反映当时两个仓库分立的状态，不应直接当作当前路径说明。
