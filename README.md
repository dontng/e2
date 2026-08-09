# e2

英语二学习主仓库。当前以 2016—2025 十套考研英语二真题为核心语料，以句子分析为主要学习动作，逐年建立能够用于理解、做题、翻译和写作的语言资源。

两个项目的原 Git 历史已经通过双父 merge commit 接入本仓库，没有 squash 或重写。原 `reading` 仓库只作为只读归档保留；后续有效工作统一进入本仓库。

原 `english2-daily` 的每日翻译正文和批改规范保留为历史证据，不再决定当前主线。

## 当前架构

```text
README.md              # 项目总览，帮助人和 Codex 快速认清结构
AGENTS.md              # Codex 长期工作规则
suggest/0804-tasks-and-suggestions.md  # 0804任务、建议与执行顺序
STANDARD.md            # 历史每日批改规范
src/                   # 历史每日翻译与批改正文
archive-src/           # 较早的每日翻译归档
scripts/src-nav.sh     # 历史 day 导航脚本
reading/               # 2016—2025 阅读真题、OCR和分析
```

## Codex 应该怎么读

不要从 GitHub 链接或全仓库扫描开始。进入项目后按这个顺序读：

1. `README.md`：确认项目当前架构。
2. `AGENTS.md`：确认 Codex 的长期工作边界。
3. `suggest/0804-tasks-and-suggestions.md`：确认0804任务、真题递归口径和执行顺序。
4. `reading/README.md`：进入完整真题、OCR和年度分析。
5. 只有处理旧 daily 证据时，才继续读取 `STANDARD.md`、`src/` 和 `archive-src/`。

真题任务从 `reading/README.md` 进入，再按需要打开 `e2-analysis/`、`e2-ocr/` 或 `archive-e2/` 中对应真题 PDF。

这个项目给 Codex 留的是接口，不是一个巨型总文件。当前判断集中在 `suggest/0804-tasks-and-suggestions.md`，真题正文与证据留在 `reading/`；旧 daily 文件只在需要追溯时读取。

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
suggest/0804-tasks-and-suggestions.md
reading/
```

`STANDARD.md`、`src/`、`archive-src/` 和 `scripts/src-nav.sh` 只有在处理旧 daily 任务时才恢复为工作入口。

## Reading 模块

`reading/` 是从原独立仓库完整并入的阅读材料模块：

```text
reading/README.md              # 模块入口与目录说明
archive-e2/                     # 英语二真题 PDF
e2-ocr/                         # 英语二完整套卷 OCR
e2-analysis/                    # 英语二阅读分析
reading/VOCAB_PLAN.md          # 合并前的词汇管线规划记录
```

原仓库中的 8 个 commit 仍可沿合并提交的第二父历史访问；文件只是统一放到了 `reading/` 前缀下。
