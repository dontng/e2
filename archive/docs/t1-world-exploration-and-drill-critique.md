# T1 世界探索与 Drill 专项性评估

> 2026-07-10 · 基于对全仓库的探索，记录 T1 当前状态、架构理解和第一个 drill pack 的质量判断。

## T1 架构：两层模型

### T0（`src/`）— 原始证据层

- 全部 `src/` 下的每日翻译文件，不仅是最近一批。
- 每天 1 句英二翻译 → 批改 → Vocab/Phrases/Takeaways。
- 产出真实失分样本，供 T1 消费。

### T1（`STATE.md` + `t1/`）— 评分提升状态层

- 不教英语，不替代批改，不维护知识清单。
- 把所有 T0 样本滚动成下一次训练的**预警、风险权重和进度反馈**。
- 风险线不是预设知识白名单——语法、句法、搭配、介词理解，都按真实失分证据进入。
- 量化只看风险等级是否下降（high → medium → low）。
- T1 状态层是 Codex 维护的后台系统，用户交付物是**专项 drill pack**。

## 当前进度

| 维度 | 状态 |
|---|---|
| 当前 day | Day 75 |
| 当前周 | 2026-W28 |
| 近 7 天完成 | 4/7 |
| src/ 总文件数 | 12（day67-day75） |
| T1 drill pack | 1 份（day75 介词短语合读） |
| 周审计 | 2 份（W27, W28） |

## 5 条活跃风险线

| 风险线 | 权重 | 证据 |
|---|---|---|
| 介词短语合读 | high | `access to`, `graduating into`, `at the prospect of` |
| 固定表达识别 | high | `best and brightest`, `bargain bin` |
| 核心动词落地 | high | `suppress`, `descended` |
| 回指与省略 | medium | `Myriad's`, `in which` |
| 专名与词形 | medium | `Priestly`, `district`, `competing` |

已降级/消灭：暂无。

## Day 75 Drill 专项性评估：松散了

### 表面看是一个专项

- 目标：「介词短语合读」
- 10 个例句，每个标注「理解方向」

### 实际覆盖了 8 种不同的认知操作

| # | 模式 | 需要的反射 |
|---|---|---|
| 1 | `access to basic medical tests` | `to` 引导资源/机会，不是动作 |
| 2 | `graduating into a weak job market` | `into` 引导毕业时进入的外部环境 |
| 3 | `at the prospect of young doctors leaving` | 情绪反应 + 未来可能性，合读 |
| 4 | `from rural hospitals to private clinics and to foreign universities` | 路径画线 from A to B to C |
| 5 | `a system in which a single patent could block` | 关系代词回指前名词 |
| 6 | `departure of the best-trained nurses to richer countries` | 名词化动作 + of 主体 + to 方向 |
| 7 | `evidence of a direct link between A and B` | of 套 between，嵌套介词 |
| 8 | `from national agencies to local schools` | 转移路径（与 4 同构） |
| 9 | `objected to the use of student data` | **动词 + to**，跟前 8 个完全不同类 |
| 10 | `barriers to treatment for patients` | 名词 + to + for，多层限定 |

### 问题诊断

1. **10 句练了 8 种反射，每种只练了 1-1.25 次。** 读完第 1 题的 `access to` 反射，第 2 题就切换到 `graduate into`，前一个反射没巩固就被覆盖。

2. **这不是训练型 drill，是展示型材料。** 像一个语法书「介词短语」章节的例句精选——读起来每个都有道理，但读完无法形成任何一个明确的、可自动化的考场反射。

3. **「介词」作为归类维度太粗。** `access to`（to 后面是资源）、`from A to B to C`（路径画线）、`in which`（关系代词回指）是三类完全不同的认知挑战。把它们捆在一起叫「介词短语合读」，降低了 drill 的针对性。

4. **与 STATE.md 的标准对不上。** STATE.md 写「训练包必须凝结考点考察方式，让用户读完能形成更快的考场反应」。但大类 drill 做不到——它让用户知道了介词有很多种模式，但没有任何一个模式被反复强化到自动化。

### 专项 Drill 的正确做法

每个 drill 只打**一个反射**，用 **5 句同构题**：

| 窄专项 | 反射 | 同构句数 |
|---|---|---|
| `名词 + to + 资源/机会` | to 后面是资源，不能翻成动词 | 5 |
| `from A to B to C` 路径 | 先画线，再落动词 | 5 |
| `in which` 回指 | 关系代词必须回前文补名词 | 5 |
| `graduate/enter/step + into + 环境` | into 引导的是毕业后进入的局面 | 5 |
| `at the prospect of + 名词化事件` | 整块读出「对……可能性感到担忧」 | 5 |

5 句同构题的反射密度 = 10 句展示型材料的 5 倍。

## 对 T1 的纠正与澄清

### 纠正 1：T0 范围

STATE.md 写的「当前 T0 范围：0706-day72 到 0709-day75」是**最近一批被审计的样本**，不是全部 T0。T0 = `src/` 下所有文件（含 day67-71），且持续累积。

### 纠正 2：风险模型的累积性

STATE.md 第 46 行「让第 i 天的样本提高第 i+1 天的预警质量」容易引起误解。实际机制是：**基于 src/ 全部文件产生的当前状态 i，滚动到下一次训练的状态 i+1。** 是累积的、滚动的，不是相邻天机械传递。

---

> **关联文档**：[T1 自收敛机制分析与设计缺陷](t1-self-convergence-analysis.md)
