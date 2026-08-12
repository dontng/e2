# 微信每日一句

本目录存放从“长难句每日一句”微信文章转换出的 Markdown。

```text
src-we/
├── YYYY/                    # 按发布年份存放转换结果
├── _inbox/                  # 待转换 HTML
└── _tools/                  # 转换脚本及说明
```

转换规则和命令见 [`_tools/README.md`](_tools/README.md)。

## 跨年去重

2025 与 2026 的课程存在重复选句。当前目录已经按原句做过一次跨年去重：

- 完整重复时保留 2026 新版，删除 2025 旧版；
- 2026 原句若因转换或原页面问题只剩半句，则删除残缺版，保留 2025 完整版；
- 只比较原句，不因出处、标点空格或讲解排版不同而把同一句保留两次。

去重后共保留 264 篇：2025 年 166 篇，2026 年 98 篇。去重过程、词汇规模和考纲覆盖估算见
[`suggest/0812-src-we-dedup-and-vocabulary-coverage.md`](../suggest/0812-src-we-dedup-and-vocabulary-coverage.md)。
