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

## 自动批改

```bash
nohup ./auto-review.sh >> .auto-review.log 2>&1 &
```

后台挂起，每 10 分钟扫一次。发现未批改文件时自动：批改 → 生成 fool → 生成 probe → 更新 console → push。

```bash
tail -f .auto-review.log   # 查看进度
pkill -f auto-review.sh    # 停止
```

---

## 文件层次

| 目录 | 内容 | 说明 |
|------|------|------|
| `src/` | 原始句子文件 | 批改结果写回这里 |
| `fool/` | 愚者解析 | AI 对句子的全量拆解，帮你读懂批改 |
| `probe/` | 采分卡 | 原句 + 我的翻译 + 评分，留 Q&A 空间给自己追问 |
| `console/` | 控制台 | 3 天滚动窗口，`today.md` 作入口 |
