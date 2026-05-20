# engligh2-daily

英语二每日一句练习，包含翻译留痕、批改标注、词汇解释和问答收录。

## 每日文件结构

每个文件包含以下区块：

- **原句** — 当天英二例句
- **我的理解和翻译** — 自己的翻译留痕，不修改
- **批改** — 内联标注错误 + 参考译文
- **Vocab** — 不熟单词 + vocabulary.com 两段解释
- **Phrases** — 词组拆解与语境说明
- **问答收录** — 讨论中产生的语言问题与解答

## 目录结构

```
sentence/
  may/
    0519-day31.md
    0520-day32.md
  june/
    ...
```

## 每日使用

### 1. 创建当天文件

```bash
bash new-day.sh
```

### 2. 提前创建明天的文件

```bash
bash new-day.sh tomorrow
```

### 3. 指定日期创建（需手动传入序号）

```bash
bash new-day.sh 0601 36
```

日期格式为 `MMDD`，序号需要手动指定，避免跳着创建时序号错乱。

### 4. 推送到 GitHub

```bash
git add . && git commit -m "Day XX" && git push
```

