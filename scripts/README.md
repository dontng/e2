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
| `studio.sh` | 启动本地交互台：拉起 `scripts/studio.py`（绑定 `127.0.0.1:8787`）并自动打开浏览器。`PORT=9000 bash studio.sh` 可换端口。 | 手动，日常入口 |
| `new-day.sh` | 创建当天的 `src/<月>/<mmdd>-dayN.md`，自动注入「复习区」（盲译重做的句子）。`bash new-day.sh tomorrow` 预建明天；`bash new-day.sh 0625` 指定日期。 | 手动 / 网页「开启 day / 备好明天」按钮 |
| `auto-review.sh` | **批改 daemon**，常驻在家里那台 Dell。轮询仓库找未批改的翻译 → 调 Claude 批改 → 生成评分/讲解、刷新 console 与 probe → commit & push。默认 10 分钟轮询；`--once` 扫一次即退。 | Dell 上常驻；VS Code `folderOpen` task 也会拉起 |

### scripts/ 下（多为被 source 的模块，非独立运行）

| 文件 | 职能 |
|------|------|
| `studio.py` | 交互台后端。纯标准库 HTTP server，渲染 `studio.html`、提供 `/api/*`。详见第二节。 |
| `studio.html` | 交互台前端单页（HTML+CSS+JS 一体）。详见第二节。 |
| `review.py` | day 文件与复习区的解析/写入单一职责模块。CLI：`review.py inject <file> <day>` 注入复习区；`review.py pending <file>` 判断是否有待批改重译。库函数 `section / set_section / parse_blocks / fill_redo` 被 studio.py、scores.py 复用。复习注入规则：每句一生恰好被复习两次（第 3 次前、第 7 次前），盲译不带答案，参考译文藏在 HTML 注释里渲染不可见、批改可读。 |
| `scores.py` | 评分数据的唯一归属。CLI `scores.py <repo> <exam_date>` 重生成 `console/scores.md` 并输出 today.md 摘要行。库函数 `collect(repo)` 返回所有天的首译/重译分数，喂给 studio 的走势图与表格。 |
| `console.sh` | 被 `auto-review.sh` source。维护 3 天滚动的 console 窗口文件（带上一篇/下一篇导航的轻量入口）。 |
| `nav.sh` | 被 `auto-review.sh` source（须在 `console.sh` 之后）。给 `fool/`、`probe/` 文件维护行内上一篇/下一篇导航。 |
| `probe.sh` | 被 `auto-review.sh` source。为每句生成 probe 卡片（原句+翻译+评分+问答占位）。 |

> 调用关系：`auto-review.sh` 依次 source `console.sh → nav.sh → probe.sh`；`studio.py` import `review` 和 `scores`；`scores.py` 也 import `review`。解析逻辑只在 `review.py` 里写一份，其余全部复用，不重复造解析。

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

**④ 走势** — 近 14 次首译评分的柱状图（≥6 绿、≤2 红）+ 最近 10 天的明细表（DAY / 日期 / 首译分 / 重译分，重译带 ↑↓ 升降箭头）。数据来自 `scores.py` 的 `collect`。

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
