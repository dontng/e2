# english2-daily

英语二每日一句，翻译 → 自动批改 → 拆解 → 内功诊断。四战备考，考试日 2026-12-18。

---

## 从这里开始

```bash
bash studio.sh      # 主入口：写译 / 重译 / 看批改 / 走势图（端口 8787）
bash word.sh        # 单词复习页：一屏一次，词+例句端上来（端口 8788）
```

浏览器打开后，页面标题下有「单词 ↗ / 句子 ↗」互跳链接。保存翻译后 auto-review 在 15 秒内唤醒接手批改。

不在电脑前时，GitHub 上的轻量入口是 `console/today.md`（倒计时 + 今日评分 + fool/probe 链接），用 ← → 在历史之间导航。

---

## 每日流程

1. **开启今天** — studio 页面点「开启 day N」（或 `bash new-day.sh`），src / fool / probe 三件套空壳一起创建
2. **贴原句 → 写翻译 → 保存** — auto-review 15 秒内接手，顺序完成批改 → fool → probe，三步全部验证通过后才 push
3. **看结果** — studio 直接显示评分、批改、参考译文；打开当日 `probe/*-probe.md` 看刺痛 / G/P 印证 / 今日带走
4. **复习区盲译** — 3 次前和 7 次前的句子自动出现，不看旧答案直接重译；批改对比首译得分（↑ → ↓）
5. **单词复习** — `bash word.sh` 开单词页，一屏 10 词连例句，词义用胶带遮住口译后揭开对一眼

首译得分和参考译文藏在 HTML 注释里，GitHub 渲染和 studio 都不剧透。分数汇总在 [console/scores.md](console/scores.md) 和 studio 走势图。

---

## 在公司笔记本上用

`bash studio.sh` 在哪台机器上跑行为自动适配，无需配置。

| 场景 | 模式 | 保存后做什么 |
|------|------|-------------|
| Dell（跑着 auto-review） | 本地模式 | 写 markdown → touch 唤醒文件，daemon ≤15s 接手 |
| 公司笔记本（没有 daemon） | 远程模式 | 写 markdown → commit + push，Dell pull 后处理 |

远程模式下 studio 不调用 Claude，只做 git 操作。批改 / fool / probe 全在 Dell 上完成，推回 GitHub 后页面每 60 秒自动 pull，结果直接出现。

---

## 自动批改 daemon

```bash
nohup ./auto-review.sh >> .auto-review.log 2>&1 &
tail -f .auto-review.log   # 查看进度
pkill -f auto-review.sh    # 停止
```

每 10 分钟 `git pull` 并扫描。发现待处理文件时，**一次 Cursor Agent**（默认 `sonnet-4.6`）顺序完成三步，**三步全部验证通过后才 push**：

| 步骤 | 内容 | 完成度检测 |
|------|------|------------|
| 1 · src 批改 | 批改 + 评分 + Vocab/Phrases 各 3 例句 | `scripts/src.sh src_day_complete` |
| 2 · fool 拆解 | 四步：扫词 / 扫词块 / 扫句式 / 读句子 | `scripts/fool.sh fool_complete`（v2 标尺） |
| 3 · probe 诊断 | 原句摘抄 + 今日刺痛 / 内功 / 招式 / 台阶 / 今日带走 | `scripts/probe.sh probe_complete` |

本地诊断单日完成度：

```bash
bash scripts/verify-day.sh src/june/0622-day60.md
```

Dell WSL2 安装 Cursor Agent：`curl https://cursor.com/install -fsS | bash`，`agent login` 或设 `CURSOR_API_KEY`。

---

## 文件层次

| 目录 / 文件 | 内容 | 说明 |
|-------------|------|------|
| `src/` | 原始句子文件 | 批改结果写回这里；质量契约见 [`src/STANDARDS.md`](src/STANDARDS.md) |
| `fool/` | 愚者拆解 | 四步拆解全部英文句（原句 + Vocab + Phrases 例句）；契约见 [`fool/STANDARDS.md`](fool/STANDARDS.md) |
| `probe/` | 内功印证卡 | 仅针对田静每日一句：刺痛 / G/P 印证 / 台阶 / 今日带走；跨天总表 [`probe/internal-skills.md`](probe/internal-skills.md) |
| `console/` | 控制台 | 3 天滚动窗口；`today.md` 含倒计时和今日链接；[`scores.md`](console/scores.md) 全部评分 |
| `data/vocab.json` | 单词 SRS 状态 | 本机本地，不入 git |
| `scripts/` | 工具脚本 | 见 [`scripts/README.md`](scripts/README.md) |
