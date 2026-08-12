# AGENTS

这个仓库以 2016—2025 十套考研英语二真题为核心语料。Codex 进入仓库后，先按这里的接口确认当前任务与证据入口。

## 工作入口

日常不要从 GitHub 链接或全仓库扫描开始。优先读取：

1. `suggest/0812-129-days-to-75.md`：当前129天计划、真题与黄皮书闭环、前后50天分工。
2. `suggest/0804-tasks-and-suggestions.md`：早期真题递归口径，只有需要追溯旧设计时读取。
3. `archive-e2/`、`e2-ocr/`、`e2-analysis/`：完整真题、OCR和年度分析入口。
4. 进入某一年时，再打开对应的 PDF、完整 OCR 或年度分析。
5. 只有明确处理旧 daily 证据时，才读取 `STANDARD.md`、`src/` 与 `archive-src/`。

## 执行边界

- 当前主任务以 `suggest/0812-129-days-to-75.md` 为准，2016—2025完整英二真题是核心语料，黄皮书是主要外部解析依据。
- 真题任务先读 `suggest/0812-129-days-to-75.md`，再直接进入 `archive-e2/`、`e2-ocr/` 或 `e2-analysis/`。
- `src/`、`archive-src/` 和 `STANDARD.md` 保留旧 daily 证据与规则，只在相关任务中读取；它们不决定当前真题主线。
- 每日批改格式以 `STANDARD.md` 为准。
- 批改完成后，把 `## 我的翻译` 整块注释掉，不删除。
- 新增或批改日文件后运行 `bash scripts/src-nav.sh`。

## 提交约定

提交前确认工作区是否含有用户已有修改。只暂存本次任务相关文件，不顺手提交无关改动。

Commit message 是交付物的一部分。提交信息必须清楚说明本次改变的目的、范围和对后续工作的影响；不要只写 `update`、`fix`、`changes` 这类无法交接的占位信息。

### AI 交付署名与提交边界

- 只要改动由 Codex 或 GPT 产出并由其提交交付，保留用户配置的 Git author 和 committer，并在 commit message 最后加入：`Co-Authored-By: Codex <noreply@openai.com>`。
- 此规则同时适用于本地 `git`、`gh`、GitHub API/connector、直接推送 `main` 和 PR；不要因为交付通道不同而遗漏署名。
- 一个用户目标默认只形成一个完整、可读、可回滚的 commit。先完成范围内的编辑、校验和文档同步，再提交；不要把检查、补一行说明或中间状态拆成额外 commit。
- 只有用户新增了独立目标，或保留外部 Git 历史必须产生 merge commit 时，才拆分；后一种情况在交付前说明原因。
- 用户明确要求 `push to main` 时，完成范围检查、commit 和推送，不擅自改为 PR；推送前核对最终 commit 同时符合本节的署名与单目标边界。
- 每次 commit 并 push 之后，必须执行 `git status` 确认工作区干净（无未提交修改、无未跟踪文件）。如果存在残留改动，必须继续处理（补充提交或说明原因），不得留下脏工作区给下一次会话。
