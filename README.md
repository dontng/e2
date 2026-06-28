# english2-daily

> 每天翻一句，批改，拆开，再来。

一个人的考研英语二备考工具——句子驱动，把"写译"接上"自动批改"和"拆解内功"，专治"看着认识、译出来对不上"。**四战**冲刺，目标从 **39 分**跑到 **65+**，考试日 2026-12-18。

## 架构

```
studio.sh ──▶ studio.py (Python, stdlib only, 127.0.0.1:8787)
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
     src/         fool/       probe/
   原句+批改      四步拆解    内功诊断卡
```

`auto-review.sh` 守护进程跑在 Dell，轮询到新翻译后唤醒一次 Cursor Agent，顺序完成批改 → fool → probe 三步，三步全部验证通过后 push。单文件前端 `scripts/studio.html`，和纸风格三栏布局，无框架，仅标准库，git 同步跨机器。

## 功能

### 今日写译
- **贴原句 → 写翻译 → 保存**：studio 页面完成全部输入，auto-review ≤15s 唤醒接手批改
- **批改三件套**：src 批改+评分+Vocab/Phrases 各 3 例句 → fool 四步拆解 → probe 内功诊断，三步验证通过后一次性 push
- **结果直出**：studio 实时显示评分、批改详情、参考译文；首译得分藏在 HTML 注释，不剧透

### 复习区
- **每句一生两遇**：第 3 次前和第 7 次前自动抽取，不带旧答案写入新一天的复习区
- **盲译重做**：不看旧答案直接重译，批改对比首译得分（↑ → ↓）
- **历史天可补译**：翻阅任意历史天，复习块未批改时依然可写译并触发批改，不绑定当天

### 拆解内功（Fool · Probe）
- **Fool 四步**：扫词 → 扫词块 → 扫句式 → 读句子，针对批改中出现的所有英文句降维解析
- **Vocab / Phrases**：每个单词 3 条同难度例句（vocabulary.com 风格 × 李延隆造句），短语同标准
- **Probe 诊断**：今日刺痛 / G·P 印证 / 台阶 / 今日带走，跨天总表 `probe/internal-skills.md`

### 单词台
- **一屏 10 词**：词 + 例句一次端上来，词义用遮盖法口译后揭开对比（`bash word.sh`，端口 8788）

### 坚持追踪
- **热力图**：过去 20 周每天练习情况，绿色深浅对应评分高低
- **评分走势表**：最近 10 天首译 + 重译评分，↑ ↓ 趋势一眼可见

### 跨机器同步
| 场景 | 模式 | 保存后做什么 |
|------|------|-------------|
| Dell（跑着 auto-review） | 本地模式 | 写 markdown → touch 唤醒，daemon ≤15s 接手 |
| 其他笔记本 | 远程模式 | 写 markdown → commit + push，Dell pull 后处理；页面每 60s 自动 pull |

## 使用

```bash
bash studio.sh      # 主入口：写译 / 重译 / 看批改 / 走势图（端口 8787）
bash word.sh        # 单词复习页：一屏 10 词连例句（端口 8788）
```

不在电脑前时，GitHub 上的轻量入口是 `console/today.md`——倒计时 + 今日评分 + fool/probe 链接，← → 历史导航。

## Daemon

```bash
nohup ./auto-review.sh >> .auto-review.log 2>&1 &
tail -f .auto-review.log   # 查看进度
pkill -f auto-review.sh    # 停止
```

Dell WSL2 安装 Cursor Agent：`curl https://cursor.com/install -fsS | bash`，`agent login` 或设 `CURSOR_API_KEY`。

本地诊断单日完成度：

```bash
bash scripts/verify-day.sh src/june/0622-day60.md
```

## 文件

| 目录 / 文件 | 内容 | 说明 |
|-------------|------|------|
| `src/` | 原始句子文件 | 批改结果写回这里；质量契约见 `src/standard.md` |
| `fool/` | 愚者拆解 | 四步拆解所有英文句（原句 + Vocab + Phrases 例句）；契约见 `fool/standard.md` |
| `probe/` | 内功印证卡 | 刺痛 / G·P 印证 / 台阶 / 今日带走；跨天总表 `probe/internal-skills.md` |
| `console/` | 控制台 | `today.md` 倒计时 + 今日链接；`scores.md` 全部评分 |
| `scripts/` | 工具脚本 | studio.py / review.py / scores.py / word.py，见 `scripts/README.md` |

## 进度

65 句入库（截止 day65），fool + probe 双轨同步生成，复习区盲译 → 批改全流程跑通。分数汇总见 `console/scores.md` 和 studio 走势图。

## 路线图

### 已完成
- [x] 写译 → 自动批改（本地 daemon + 远程 git push 双模式）
- [x] fool 四步拆解 + Vocab / Phrases 各 3 例句
- [x] probe 内功诊断 + 跨天总表
- [x] 复习区（每句两遇，盲译 + 批改对比）
- [x] 历史天复习块可补译，不绑定当天
- [x] 坚持热力图 + 评分走势表
- [x] 单词台（一屏 10 词）
- [x] 跨机同步，studio 行为自动适配，零配置
- [x] 每日 console 快照（GitHub 轻量入口）

### 下一步
- [ ] probe Q&A 笔记时间线（批改暴露的句法疑问持久化）
- [ ] 单词台记忆闭环（词义遮盖翻转 + 间隔复习）
- [ ] 大题（翻译/作文）训练模块
