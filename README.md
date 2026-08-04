# e2

英语二学习主仓库。当前以 2016—2025 十套考研英语二真题为核心语料，以句子分析为主要学习动作，逐年建立能够用于理解、做题、翻译和写作的语言资源。

两个项目的原 Git 历史已经通过双父 merge commit 接入本仓库，没有 squash 或重写。原 `reading` 仓库只作为只读归档保留；后续有效工作统一进入本仓库。

原 `english2-daily` 的每日翻译、T1、自动化网页、fool/probe/console 等内容保留为历史证据，不再决定当前主线。

## 当前架构

```text
README.md              # 项目总览，帮助人和 Codex 快速认清结构
AGENTS.md              # Codex 长期工作规则
suggest/README.md      # 现阶段目标、任务、建议与执行顺序
t1/CONSTITUTION.md      # 历史 T1 解释宪法
STATE.md               # 历史 T1 状态层
REVIEW.md              # 历史批改审计入口
STANDARD.md            # 历史每日批改规范
reviews/               # 历史周总结与审计
src/                   # 历史每日翻译与批改正文
t1/                    # 历史 T1 训练包
scripts/src-nav.sh     # 历史 day 导航脚本
reading/               # 阅读真题、OCR、分析和 IELTS 材料
archive/               # 历史设计文档与旧系统归档，不参与当前执行
```

## Codex 应该怎么读

不要从 GitHub 链接或全仓库扫描开始。进入项目后按这个顺序读：

1. `README.md`：确认项目当前架构。
2. `AGENTS.md`：确认 Codex 的长期工作边界。
3. `suggest/README.md`：确认现阶段任务、真题递归口径和执行顺序。
4. `reading/README.md`：进入完整真题、OCR和年度分析。
5. 只有处理旧 daily/T1 证据时，才继续读取 `t1/CONSTITUTION.md`、`STATE.md`、`REVIEW.md`、`reviews/` 和 `src/`。

真题任务从 `reading/README.md` 进入，再按需要打开 `reading/english2/analysis/`、`reading/english2/ocr/` 或对应真题 PDF。

这个项目给 Codex 留的是接口，不是一个巨型总文件。当前判断集中在 `suggest/README.md`，真题正文与证据留在 `reading/`；旧 daily/T1 文件只在需要追溯时读取。

## T1 提分状态层（历史）

`src/` 的每日翻译和批改是 T0，负责产生真实样本。`STATE.md` 是 T1，负责把所有 T0 样本滚动成下一次训练的风险预警、进度条和收益反馈。`t1/CONSTITUTION.md` 是解释质量的上位约束：不能只给答案或术语，必须交代理解从何处断、又怎样从已知义走到句中义。

T1 不按“学完语法/句法/搭配”计量，而按失分风险是否下降计量；同时用理解出口标签追踪“为什么没读出”，避免只积累结构名称。语法、句法、搭配、介词理解和更灵活的考场问题，都会根据 T0 样本自然进入风险线；不需要预先维护完整白名单。

`t1/` 保存面向用户的专项训练包。训练包只保留“目标”和“训练材料”两类前台内容，主体是 5-10 条高质量例句或阅读片段，不写后台状态说明。

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

## 周审计（历史）

批改不是终点。每周用 `reviews/` 做二次整理：

- 这周反复暴露了哪些能力问题。
- 哪些批改点覆盖充分，哪些漏讲。
- Vocab/Phrases 数量是否匹配错误密度。
- 哪些问题要带到下一周观察。

当前入口：

```text
STATE.md -> REVIEW.md -> reviews/2026-W28.md
```

`2026-W28` 当前覆盖 `0706-day72` 到 `0709-day75`，后续若新增本周日文件，继续追加到当前周总结。

## 历史归档

`archive/` 是历史系统和旧设计文档存档。里面的 T1 设计、网页、daemon、console、fool、probe 说明不代表当前架构。

当前真题主线只看：

```text
README.md
AGENTS.md
suggest/README.md
reading/
```

`STATE.md`、`REVIEW.md`、`STANDARD.md`、`reviews/`、`src/`、`t1/` 和 `scripts/src-nav.sh` 只有在处理旧 daily/T1 任务时才恢复为工作入口。

## Reading 模块

`reading/` 是从原独立仓库完整并入的阅读材料模块：

```text
reading/README.md              # 模块入口与目录说明
reading/english1/              # 英语一 OCR 与真题 PDF
reading/english2/              # 英语二 OCR、真题 PDF 与阅读分析
reading/ielts16/               # IELTS 16 示例材料
reading/VOCAB_PLAN.md          # 合并前的词汇管线规划记录
```

原仓库中的 8 个 commit 仍可沿合并提交的第二父历史访问；文件只是统一放到了 `reading/` 前缀下。
