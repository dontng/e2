# e2

英语二学习主仓库。当前以 2016—2025 十套考研英语二真题为核心语料，以句子分析为主要学习动作，逐年建立能够用于理解、做题、翻译和写作的语言资源。

两个项目的原 Git 历史已经通过双父 merge commit 接入本仓库，没有 squash 或重写；后续有效工作统一进入本仓库。

原 `english2-daily` 的材料继续作为训练证据；当前 Daily 教学规则已经更新为基于用户译文的阅读机制诊断。

## 当前架构

```text
README.md              # 项目总览，帮助人和 Codex 快速认清结构
AGENTS.md              # Codex 长期工作规则
suggest/0812-129-days-to-75.md         # 当前129天计划与真题—黄皮书闭环
STANDARD.md            # 当前 Daily 英语机制讲解规范
src/                   # 当前 Daily 与连续能力诊断
archive-src/           # 较早的每日翻译归档
scripts/src-nav.sh     # Daily 导航脚本
archive-e2/            # 2016—2025 英语二真题 PDF
e2-ocr/                # 英语二完整套卷 OCR
e2-analysis/           # 英语二阅读分析
```

## Codex 应该怎么读

不要从 GitHub 链接或全仓库扫描开始。进入项目后按这个顺序读：

1. `README.md`：确认项目当前架构。
2. `AGENTS.md`：确认 Codex 的长期工作边界。
3. `suggest/0812-129-days-to-75.md`：确认当前129天计划、真题与黄皮书闭环和前后50天分工。
4. `archive-e2/`、`e2-ocr/`、`e2-analysis/`：进入完整真题、OCR和年度分析。
5. 处理 Daily、新句批改或追溯旧证据时，再读取 `STANDARD.md`、`src/` 和 `archive-src/`。

真题任务按需要直接打开 `archive-e2/` 中对应真题 PDF、`e2-ocr/` 中的完整 OCR 或 `e2-analysis/` 中的年度分析。

这个项目给 Codex 留的是接口，不是一个巨型总文件。当前判断集中在 `suggest/0812-129-days-to-75.md`，真题正文与证据分别留在 `archive-e2/`、`e2-ocr/` 和 `e2-analysis/`；Daily 与真题主线互相反哺：真题提供问题，Daily 负责把具体阅读机制讲透并留下可复测的诊断。

## Daily：从译文诊断阅读机制

Daily 文件位于 `src/<month>/MMDD-dayN.md`，详细方法以 [`STANDARD.md`](STANDARD.md) 为准。它不是旧式固定栏目批改，也不是随机讲一句话；它利用用户的首次翻译，追踪理解从哪里开始失控，并把这个机制训练成下一次可执行的阅读动作。

核心路径是：

> 观察用户译文 → 还原当时怎样处理英文 → 找到理解在哪一步失控 → 针对失控机制重新教读 → 最后落到译对与译好

文章使用编号小标题保持教学推进，但不固定评分、Vocab、Phrases、例句数量或篇幅。每一天都应判断旧问题是否通过、是否复发以及本句新增什么困难，并在结尾回到考研同义改写和下次识别动作。

<!--
以下 README 中的旧 Daily 结构已停用，仅保留为历史记录。

## 每日文件（历史）

每日内容放在：

```text
src/<month>/MMDD-dayN.md
```

当前 canonical day 从 `src/june/0630-day67-v2.md` 开始，之后进入 `src/july/`。日期可以跨月，导航按 day 编号连续。

每日文件结构：

```md
# Day N · YYYY-MM-DD

## 原句 (Input)

## 我的翻译

## 批改 (Diff & Debug)

## 核心复盘 (Takeaways)

## 词汇 (Vocab)

## 短语 (Phrases)
```

批改完成后，`## 我的翻译` 整块用 HTML 注释包起来，保留原译作为证据。

## 批改标准（历史）

详细格式见 `STANDARD.md`。核心原则：

- 批改是改错，不是讲课。
- 先指出原译哪里错，再说明误判路线。
- Vocab 只收这次暴露的问题词。
- Phrases 只收单词认识但整体读不懂的表达。
- Takeaways 写可迁移的训练动作，不复述当天句子。

批改或新增日文件后运行：

```bash
bash scripts/src-nav.sh
```

只检查导航：

```bash
bash scripts/src-nav.sh --check
```

当前真题主线只看：

```text
README.md
AGENTS.md
suggest/0812-129-days-to-75.md
archive-e2/
e2-ocr/
e2-analysis/
```

`STANDARD.md`、`src/`、`archive-src/` 和 `scripts/src-nav.sh` 只有在处理旧 daily 任务时才恢复为工作入口。
-->

## 真题语料

真题语料直接位于仓库根目录：

```text
archive-e2/     # 英语二真题 PDF
e2-ocr/         # 英语二完整套卷 OCR
e2-analysis/    # 英语二阅读分析
```
