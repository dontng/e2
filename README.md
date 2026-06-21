# english2-daily

英语二每日一句，翻译 → 自动批改 → 拆解分析。

---

## 从这里开始

```bash
bash studio.sh
```

浏览器自动打开本地交互台：贴原句、写翻译、做重译、看批改和走势，全部在一页完成。保存后 auto-review 会在 15 秒内被唤醒接手批改。

不在电脑前时，GitHub 上的轻量入口是 `console/today.md`（倒计时 + 今日 fool/probe + [评分总览](console/scores.md)），用 ← → 在历史之间导航。

---

## 每日流程（studio 一页完成）

1. **开启今天** — 页面上点「开启 day N」（或 `bash new-day.sh`），复习区自动注入
2. **贴原句 → 写翻译 → 保存** — auto-review 15 秒内接手，批改完页面直接显示评分和讲解
3. **复习区盲译** — 3 次前和 7 次前的句子（每句一生两遇），不看旧答案直接重译；批改只指出仍存在的错误，并对比首译得分（↑ → ↓）

首译得分和参考译文藏在 HTML 注释里，GitHub 渲染和 studio 页面都不剧透。所有分数汇总在 [console/scores.md](console/scores.md) 和 studio 的走势图。

不用 studio 时，直接编辑 `src/` 下的 markdown 后 push，效果完全相同——studio 只是更顺手的皮，数据始终是这些纯文本文件。

---

## 在公司笔记本上用

`bash studio.sh` 在哪台机器上跑，行为会自动适配，无需配置。

**判断依据**：studio 启动时扫描本机进程，有没有 `auto-review.sh` 在跑。

| 场景 | 模式 | 保存后做什么 |
|------|------|-------------|
| Dell（跑着 auto-review） | 本地模式 | 写 markdown → touch 唤醒文件，daemon ≤15s 接手批改 |
| 公司笔记本（没有 daemon） | 远程模式 | 写 markdown → commit + push 到 GitHub，Dell pull 到后处理 |

远程模式下 studio 不调用 Claude，不执行批改，只做 git 操作。批改、fool、probe 全在 Dell 上完成，推回 GitHub 后页面每 60 秒自动 pull，结果直接出现——早上公司贴句子写翻译，晚上回家打开已有结果。

---

## 自动批改

```bash
nohup ./auto-review.sh >> .auto-review.log 2>&1 &
```

后台挂起，每 10 分钟扫一次。发现未批改文件时自动：批改 → 生成 probe（裁切 + 内功诊断）→ 生成 fool → 更新 console → push。

读完批改后，打开当日 `probe/*-probe.md`：看 **今日刺痛 / 内功印证 / 今日带走**；跨天的总表在 [`probe/internal-skills.md`](probe/internal-skills.md)，印证够了自行改条目 **状态**。

```bash
tail -f .auto-review.log   # 查看进度
pkill -f auto-review.sh    # 停止
```

---

## 文件层次

| 目录 | 内容 | 说明 |
|------|------|------|
| `src/` | 原始句子文件 | 批改结果写回这里；质量契约见 [`src/STANDARDS.md`](src/STANDARDS.md) |
| `fool/` | 愚者解析 | AI 对句子的全量拆解，帮你读懂批改；契约见 [`fool/STANDARDS.md`](fool/STANDARDS.md) |
| `probe/` | 内功印证卡 | 裁切 + AI 诊断：今日刺痛、G/P 触发、提分台阶、今日带走；总表见 [`probe/internal-skills.md`](probe/internal-skills.md) |
| `console/` | 控制台 | 3 天滚动窗口，`today.md` 作入口 |
