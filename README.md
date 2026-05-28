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

## 自动批改（auto-review.sh）

`auto-review.sh` 是一个持续运行的后台脚本，自动扫描未批改的文件，调用 Claude 完成批改后 commit 并 push。

**触发条件**：文件的「我的理解和翻译」区块有内容，但「批改」区块为空。

---

### 执行方式

#### 方式一：持续轮询（默认，推荐挂后台使用）

每 2 小时自动扫描一次，遇到 rate limit 自动退避 5 小时。

```bash
nohup ./auto-review.sh >> .auto-review.log 2>&1 &
```

后台静默运行，日志追加写入 `.auto-review.log`。

#### 方式二：只跑一次（适合手动触发或测试）

扫描当前所有未批改文件，批改完毕后退出，不进入循环等待。

```bash
./auto-review.sh --once
```

#### 方式三：自定义轮询间隔

通过环境变量 `POLL_INTERVAL` 指定间隔秒数，例如改为 1 小时：

```bash
POLL_INTERVAL=3600 ./auto-review.sh
```

---

### 查看日志

```bash
tail -f .auto-review.log
```

### 停止后台运行

```bash
pkill -f auto-review.sh
```

