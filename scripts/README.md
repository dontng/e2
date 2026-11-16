# 项目脚本

根目录 `scripts/` 是后续新增脚本的统一位置，不再另建根目录 `tools/` 或在真题工作区另设工具目录。

| 脚本 | 用途 | 状态 |
|---|---|---|
| `render-pages.py` | 将源 PDF 渲染成无损 WebP 页面 | 保留，显式传入输入和输出路径 |
| `build-semantic-paper.py` | 从 2020 源 PDF 构建已有网页的语义数据 | 保留为技术样例工具 |
| `build-text-pages.py` | 从 2020 源 PDF 提取文字层和图表 OCR | 保留为技术样例工具 |
| `build-2026-paper.py` | 根据2026转录数据重建 `e2-analysis/26.html` | 仅使用Python标准库，不改动归档PDF |
| `src-nav.sh` | 维护旧 Daily 前后篇导航 | 保留原代码；当前没有 `src/`，不作为活动任务运行 |
| `strip_files.py` | 删减旧 Daily 栏目 | 保留原代码；写死旧电脑路径，不作为当前维护命令运行 |

`tools/deepseek_audit.py` 和依赖它的 `audit.sh` 已下线，历史代码可从 Git 找回。保留旧维护脚本不意味着恢复 Daily、T1 或其排期。

2020 构建输入现位于 `e2-analysis/papers/2020/source.pdf`；脚本从自身位置定位仓库。示例：

```bash
python scripts/render-pages.py e2-analysis/papers/2020/source.pdf /tmp/e2-page-preview
```

构建脚本依各自用途需要 PyMuPDF、Pillow 或 Tesseract；不将环境准备变成学习任务。
