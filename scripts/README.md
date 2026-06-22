# scripts/ 说明

每日一句的全部工具脚本。日常只需记住一条命令：

```bash
bash studio.sh        # 打开浏览器交互台，写译 / 重译 / 看批改都在里面
```

其余脚本要么被 `studio.sh`、`auto-review.sh` 在内部调用，要么是偶尔手动跑的小工具。下面先列各脚本职能，再详解 studio 网页。

---

## 一、脚本职能速查

### 根目录

| 脚本 | 职能 | 怎么触发 |
|------|------|----------|
| `studio.sh` | 启动**句子**交互台（`127.0.0.1:8787`）并开浏览器；**顺带后台拉起单词台 8788**（已在跑则跳过）。`PORT=9000 bash studio.sh` 可换端口。 | 手动，日常入口 |
| `word.sh` | 启动**单词**复习台（`127.0.0.1:8788`）并开浏览器；**顺带后台拉起句子台 8787**（已在跑则跳过）。`PORT=9001 bash word.sh` 可换端口。 | 手动，复习入口 |

> 两页都在跑后，页面标题下各有「单词 ↗ / 句子 ↗」链接可**直接在浏览器里互跳**，不必回终端再敲命令。互链按默认端口 8787/8788 硬编码；若用 `PORT=` 自定义端口则链接失效。
| `new-day.sh` | 创建当天的 `src/<月>/<mmdd>-dayN.md`，自动注入「复习区」（盲译重做的句子）。`bash new-day.sh tomorrow` 预建明天；`bash new-day.sh 0625` 指定日期。 | 手动 / 网页「开启 day / 备好明天」按钮 |
| `auto-review.sh` | **批改 daemon**（Dell 常驻）。轮询 → 一次 Agent 顺序 **批改 src → fool → probe**；`scripts/src.sh` / `fool.sh` / `probe.sh` 验证通过后 push。 | Dell；VS Code `folderOpen` task |
| `day-pipeline-prompt.sh` | 日课 Agent prompt 构建（流程 only；格式见各 `STANDARDS.md`）。 | 被 `auto-review.sh` source |
| `src.sh` | src 批改完成度（批改+评分+Vocab/Phrases 例句意图）。 | 被 `auto-review.sh` source |
| `fool.sh` | fool 完成度（四步 v2：扫词/扫词块/扫句式/读句子）。 | 被 `auto-review.sh` source |
| `probe.sh` | probe 完成度（原句摘抄+诊断五段）。 | 被 `auto-review.sh` source |

### scripts/ 下（多为被 source 的模块，非独立运行）

| 文件 | 职能 |
|------|------|
| `studio.py` | 句子交互台后端。纯标准库 HTTP server，渲染 `studio.html`、提供 `/api/*`。详见第二节。 |
| `studio.html` | 句子交互台前端单页（HTML+CSS+JS 一体）。详见第二节。 |
| `word.py` | 单词复习台后端。复用 `vocab.py` 聚合词库，按「读式再曝光」调度，状态存 `data/vocab.json`（本机本地、不入 git）。详见第三节。 |
| `word.html` | 单词复习台前端单页。详见第三节。 |
| `vocab.py` | 单词库的唯一归属。解析全仓 `## Vocab` 卡片 → `collect_vocab(repo)` 返回 [{word, pos, gloss, day, sentences:[{en,zh}]}]，按词面去重、合并复现句子。中文全部取自既有 markdown（例句 `（…）`= 句子中文，核心意象首句 = 词义）。 |
| `review.py` | day 文件与复习区的解析/写入单一职责模块。CLI：`review.py inject <file> <day>` 注入复习区；`review.py pending <file>` 判断是否有待批改重译。库函数 `section / set_section / parse_blocks / fill_redo` 被 studio.py、scores.py 复用。复习注入规则：每句一生恰好被复习两次（第 3 次前、第 7 次前），盲译不带答案，参考译文藏在 HTML 注释里渲染不可见、批改可读。 |
| `scores.py` | 评分数据的唯一归属。CLI `scores.py <repo> <exam_date>` 重生成 `console/scores.md` 并输出 today.md 摘要行。库函数 `collect(repo)` 返回所有天的首译/重译分数，喂给 studio 的走势图与表格。 |
| `console.sh` | 被 `auto-review.sh` source。维护 3 天滚动的 console 窗口文件（带上一篇/下一篇导航的轻量入口）。 |
| `nav.sh` | 被 `auto-review.sh` source（须在 `console.sh` 之后）。`fool/`、`probe/` 行内导航。 |
| `probe.sh` | probe 完成度（原句摘抄 + 诊断五段；无 Q&A）。 |
| `verify-day.sh` | 本地诊断：`bash scripts/verify-day.sh src/.../dayN.md`。 |

> 调用关系：`auto-review.sh` source `console.sh → nav.sh → probe.sh → src.sh → fool.sh → day-pipeline-prompt.sh`；`studio.py` import `review`、`scores`。

---

## 二、studio 网页详解（`bash studio.sh` 叫醒的页面）

一个本地优先、零配置的单页交互台。把田静每日一句的整套日常——**贴原句 → 写翻译 → 看批改 → 盲译重做**——全收进一个浏览器页面，无需碰 markdown 文件。页面每 8 秒自动刷新，正在打字时不打断。

### 双运行模式（自动判断，无需设置）

页面顶部「工具箱」会显示当前模式：

- **本地模式** — 本机正跑着 `auto-review.sh`（即家里的 Dell）。保存即写回 markdown 并 touch 唤醒文件，daemon ≤15 秒接手批改，结果直接出现在页面。
- **远程模式** — 本机没有 daemon（如公司笔记本）。保存后自动 `commit + push` 到 GitHub，Dell 在下个轮询 pull 到后批改；页面每 60 秒自动 pull，结果推回来后自动显示。

判断依据：扫 `/proc` 看有没有 `auto-review.sh` 进程在跑。所以同一份代码在哪台机器打开都能用，行为自适应。

### 页面分区（从上到下）

**① 顶栏** — 标题 + 右上角醒目的「距考试还剩 N 天」倒计时（考试日定义在 `console.sh` 的 `EXAM_DATE`，页面只读取不复制）。

**② 今日** — 当天那句的工作区，按进度自动切换形态：
- 文件还没建 → 显示「开启 day N」按钮（调 `new-day.sh`）。
- 已建、还没贴原句 → 一个文本框，把田静原句贴进去保存。
- 有原句、还没写翻译 → 显示原句 + 翻译输入框。
- 写了翻译、等批改 → 翻译框（批改完成前可反复改）+ 跳动的「批改中」脉冲提示。
- 已批改 → 原句 + 我的翻译 + **大号评分**（≥6 分绿、否则红）+ Claude 的讲解，并附 GitHub 上 SRC / FOOL / PROBE 三个跳转链接。

**③ 复习** — 盲译重做区。`new-day.sh` 注入的待复习句子在这里逐句出现：不看旧答案直接重译 → 保存 → 等批改 → 出讲解后标「済」。每句一生只在此遇到两次。

**④ 坚持** — GitHub 风格的练习热力图 + 最近 10 天明细表。
- 热力图：每格一天，按真实日历排布（周日起、月份/星期标签、最近一年窗口，随数据从约 18 周自动生长）。**练了就填，颜色深浅按首译分**（莫兰迪绿 5 档：未练→浅→深；练了未批改记最浅档），今天那格红框标出。一眼看出坚持与断签，副标题显示总句数与当前连续天数。
- 明细表：DAY / 日期 / 首译分 / 重译分（重译带 ↑↓ 升降箭头）。
- 数据均来自 `scores.py` 的 `collect`；日期由 `studio.py` 的 `heatmap_cells` 把 `mmdd` 还原成真实日期（年份按「今年；月日晚于今天则归去年」推断）。

**⑤ 工具箱** — 按模式给出操作按钮：
- 本地模式：auto-review 运行状态灯 · 「立即扫描」(touch 唤醒) · daemon 没跑时有「启动 auto-review」。
- 远程模式：「立即同步」(先 push 本地未推、再强制 pull) · 同步异常会标红。
- 两种模式都有「备好明天」(预建明天的 day 文件)。
- 下方是命令速查卡 + 本地模式下 `.auto-review.log` 的最后几行。

### 典型用法

1. 早上 `bash studio.sh`，页面自动打开。
2. 「今日」区若提示没文件，点「开启 day N」。
3. 把田静公众号当天原句贴进框 → 保存。
4. 写下自己的理解和翻译 → 保存。注：**一旦批改完成，首译不可再改**（防止改完答案刷分）。
5. 等片刻（本地 ≤15s / 远程下个轮询），批改与评分自动显示。
6. 往下到「复习」区，把到期的旧句盲译重做 → 保存 → 等复习批改。
7. 走势图和表格自动累积，长期看曲线。

### 后端接口（studio.py）

| 路由 | 作用 |
|------|------|
| `GET /api/state` | 返回整页状态（模式、倒计时、今日、复习区、走势、表格、日志），前端每 8 秒拉一次 |
| `POST /api/save` | 保存原句 / 首译 / 重译；本地模式写文件+唤醒，远程模式 commit+push |
| `POST /api/new-day` | 建今天的文件；`{when:'tomorrow'}` 建明天 |
| `POST /api/scan` | touch 唤醒文件，让本地 daemon 立即扫描 |
| `POST /api/sync` | 远程模式手动同步（push 本地未推 + 强制 pull） |
| `POST /api/daemon-start` | 本地启动 auto-review daemon |

> 单人本地工具，只绑 `127.0.0.1`，出错直接把信息回给页面 toast，不做鉴权。

---

## 三、单词复习台（`bash word.sh` 叫醒的页面）

刻意克制的第二个页面，**只做一件事**：把词连同它的句子端上来读。与句子台分开、互不混。

**复习模型——只读不评。** 不发音、没有「认识/生」按钮、没有图表/搜索/词网浏览。主题是「只要学就当不会」：永不自评是否学会，只管反复见、反复读。

**怎么用：**
1. 一次只给**一屏**（≤8 词，每词连同 2–3 句例句）；一天可来很多次。
2. 对着英文**口译/口读**过一遍整屏（词义和句子的中文都被**胶带**遮住）。
3. 读完点胶带揭开中文（或「揭开整屏」一次性掀开），自己对一眼理解对没对——不点按钮、不记分。
4. 点「又来一屏」：当前这屏算读过、排到以后再现，下一屏换新词；读空了就提示待会儿再来。

**调度（无自评驱动）：** 每个词被端上读过一次，按 `INTERVALS`（1/2/4/7/12/20/30/45/60 天）渐宽地排到下次再现，**永不毕业**——保证每个学过的词都反复回来，不怕「见一次就到考场才再见」。状态存 `data/vocab.json`（每机一份、不入 git）。

**接口（word.py）：** `GET /api/screen` 取一屏待复习词；`POST /api/done {keys}` 标记这屏读过、推后到期并返回下一屏。词库解析全在 `vocab.py`，word.py 不另写解析。
