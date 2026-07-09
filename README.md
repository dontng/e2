# english2-daily

英二每日翻译训练库。当前版本只保留一条主线：每天翻译一句，把错因、修正路线、词汇短语和可迁移复盘写清楚。

旧的自动化网页、fool/probe/console 系统已归档到 `archive2/`，不参与当前日常流程。

## 当前架构

```text
README.md              # 项目总览，帮助人和 Codex 快速认清结构
AGENTS.md              # Codex 长期工作规则
STATE.md               # T1 提分状态层，记录风险、预警和进度反馈
REVIEW.md              # 当前批改审计入口
STANDARD.md            # 每日批改详细规范
reviews/               # 周总结与批改质量审计
src/                   # 每日翻译与批改正文
t1/                    # T1 专项训练包
scripts/src-nav.sh     # day 导航刷新脚本
archive/, archive2/    # 历史归档，不参与日常
```

## Codex 应该怎么读

不要从 GitHub 链接或全仓库扫描开始。进入项目后按这个顺序读：

1. `README.md`：确认项目当前架构。
2. `AGENTS.md`：确认 Codex 的长期工作边界。
3. `STATE.md`：读取当前 T1 风险、预警、进度反馈和下一次动作。
4. `REVIEW.md`：确认当前审计范围。
5. `reviews/<week>.md`：读取本周暴露的问题和批改质量记录。
6. `src/<month>/MMDD-dayN.md`：只在需要核对证据或执行批改时打开每日文件。

这个项目给 Codex 留的是接口，不是一个巨型总文件。`REVIEW.md` 只指路，周总结承载滚动复盘，每日文件保留完整证据。

## T1 提分状态层

`src/` 的每日翻译和批改是 T0，负责产生真实样本。`STATE.md` 是 T1，负责把所有 T0 样本滚动成下一次训练的风险预警、进度条和收益反馈。

T1 不按“学完语法/句法/搭配”计量，而按失分风险是否下降计量。语法、句法、搭配、介词理解和更灵活的考场问题，都会根据 T0 样本自然进入风险线；不需要预先维护完整白名单。

`t1/` 保存面向用户的专项训练包。训练包只保留“目标”和“训练材料”两类前台内容，主体是 5-10 条高质量例句或阅读片段，不写后台状态说明。

## 每日文件

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

## 批改标准

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

## 周审计

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

`archive/` 和 `archive2/` 只是历史系统存档。里面的网页、daemon、console、fool、probe 说明不代表当前架构。

当前 active 区只看：

```text
README.md
AGENTS.md
STATE.md
REVIEW.md
STANDARD.md
reviews/
src/
t1/
scripts/src-nav.sh
```
