# english2-daily

英语二每日一句，翻译 → 自动批改 → 拆解分析。

---

## 从这里开始

```
console/today.md
```

打开 `today.md`，两个链接分别进入今天的 fool 解析和 probe 采分卡，用 ← → 在历史之间导航。

---

## 每日流程

**1. 创建当天文件**

```bash
bash new-day.sh
```

创建明天的文件：`bash new-day.sh tomorrow`

**2. 填写翻译，推到 GitHub**

在 `src/june/MMDD-dayNN.md` 的「我的理解和翻译」填好后 push，后台的 `auto-review.sh` 会自动检测并批改。

**3. 看结果**

批改完成后，`auto-review.sh` 自动 commit + push，刷新 GitHub 即可。

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
