# 2021—2026 六套真题工作区

本目录集中管理近六年完整真题及其 AI 解答、答案核对、用户刷题记录和教学经验。先从 2026 做一个年度样例，再处理其余年份；这份入口只记录真实状态，不把已有分题型讲解算成整卷已经完成。

| 年份 | 原卷 | 文字稿 | 当前状态 |
|---|---|---|---|
| 2021 | [PDF](papers/2021/source.pdf) | [文字稿](papers/2021/source.md) | 已归位；AI 整卷解答尚未开始 |
| 2022 | [PDF](papers/2022/source.pdf) | [文字稿](papers/2022/source.md) | 已归位；AI 整卷解答尚未开始 |
| 2023 | [PDF](papers/2023/source.pdf) | [文字稿](papers/2023/source.md) | 已归位；AI 整卷解答尚未开始 |
| 2024 | [PDF](papers/2024/source.pdf) | [文字稿](papers/2024/source.md) | 已归位；AI 整卷解答尚未开始 |
| 2025 | [PDF](papers/2025/source.pdf) | [文字稿](papers/2025/source.md) | 已归位；AI 整卷解答尚未开始 |
| 2026 | [PDF](papers/2026/source.pdf) | 待归位 | PDF 已归位；文字稿与 AI 整卷解答尚未开始 |

## 年度内容放在哪里

每年统一放在 `papers/年份/`。现有 `source.pdf` 和 `source.md` 保留题目；后续按实际产出增加 `solution.md`（AI 首次判断、依据、答案核对和订正）、`teaching.md`（本卷词汇、句子、逻辑和解题经验）、`record.md`（用户首次作答与复盘）。HTML 及其专属资源也放在对应年份；没有内容不预建空文件。

跨年度共同经验形成后写在本目录的 `experience.md`，每条链接回具体年份和题号。`reading/`、`writing/`、`new-type/` 保留跨多年题型资料，按需互链，不复制整套教学。

## 网页与工具

[2020 网页](20.html)仅保留为已有交互与排版的技术样例，不列入当前六套训练。`papers/2020/` 保存其构建输入和资源，`viewer/` 保存阅读器，[根目录 scripts/](../scripts/README.md) 保存生成与维护脚本。根目录的最新版网页和阅读器已收进这里；旧入口 `20-text1.html` 仍可跳转。

用 Live Server 从本目录打开 `20.html`。Python 构建工具从仓库内定位输入，2020 源 PDF 为 `papers/2020/source.pdf`；原卷的 SHA 校验保持不变。
