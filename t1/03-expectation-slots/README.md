# T1-03 · 句子期待位：没等到落地，就不提前收句

这个专项处理的不是“长句看着难”，而是阅读时没有持续保留尚未填满的位置：长主语之后还缺谓语，`what` 从句之后还缺外层动作，`that A and that B` 的第二项还在等待，结果眼睛继续向右，脑中却已经把句子结束了。

本目录的长期数据分别放在：[历史错例](cases.md) · [闭卷训练](drills.md) · [复测记录](review-log.md)。本页只保留机制说明和首次入口。

## 已暴露的坍塌点

| 真实证据 | 当时需要保留的期待位 |
|---|---|
| [Day 78](../../src/26-07/0713-day78.md)、[Day 90](../../src/26-07/0727-day90.md) | 长名词主语结束后，仍等待全句谓语 |
| [Day 102](../../src/26-08/0811-day102.md) | `Asked whether...` 只是背景，仍等待谁说了什么 |
| [Day 105](../../src/26-08/0814-day105.md) | `Researchers measured... and found...` 中并列谓语共享主语 |
| [Day 106](../../src/26-08/0815-day106.md) | `-ing` 事件整体作主语，之后等待 `means` |
| [Day 108](../../src/26-08/0818-day108.md) | `lacking not in A but in B` 要让 A、B 占同一槽位 |
| [Day 88](../../src/26-07/0724-day88.md) | `Only if... will...` 条件结束后等待倒装主句 |
| [Day 127](../../src/26-09/0909-day127.md) | 长主语和介词修饰结束后，等待核心谓语落地 |
| [Day 128](../../src/26-09/0910-day128.md) | `Calls [to A or to B] ignore C`：两个 `to` 都在修饰 `Calls`，`ignore` 才落地 |
| [Day 129](../../src/26-09/0911-day129.md) | `With N doing/done` 是背景，逗号后仍需主句 |
| [Day 130](../../src/26-09/0912-day130.md) | `sets of criteria have been measured`：头名词决定数，`of` 内名词不夺主干 |
| [Day 131](../../src/26-09/0914-day131.md) | `what ... was referring to was that...`：内层关系完成后，外层等式才完成 |

## 不翻译，先记账

每读到一个结构触发器，只开必要的槽位：

| 读到 | 立刻保留 | 什么时候关掉 |
|---|---|---|
| 长名词短语开头 | `S[未完] → V?` | 读到与头名词配套的限定动词 |
| `what/how/whether...` | `从句[未完]`，若整体作主语再留 `外层 V?` | 从句内部动作完成且外层谓语出现 |
| `that A and that B` | `内容1 + 内容2` | 两个 `that` 从句均完成 |
| `not A but B` / `rather than` | `A ↔ B 同层` | B 的语法形状与 A 对齐 |
| `with N doing/done` | `背景`，另留 `主句 S-V?` | 逗号后主句落地 |
| `only if...` 句首 | `条件`，另留 `倒装主句?` | 助动词 + 主语 + 动词出现 |

期待位不是画满整棵语法树。考场只需知道“现在还欠什么”。只要债没还清，就不能用中文顺感把句子提前封口。

## D0：只交骨架，不做全文翻译

用方括号圈修饰块，用下划线或加粗标主句主语和谓语；再写一句“读到哪儿还在等什么”。

1. The rapid expansion of online services in small towns **has changed** how residents seek advice.
2. What many observers failed to notice **was** that the decline had begun years earlier.
3. Asked whether the rule should be changed, the minister **said** the evidence remained limited.
4. Researchers **recorded** the responses and **compared** them with earlier results.
5. Only if the figures are independently checked **can** the claim be trusted.
6. Calls to reduce fees or to extend payment periods **ignore** the underlying shortage.
7. With several positions left unfilled, the agency **has delayed** the launch.
8. The first of the two sets of criteria **was designed** for younger applicants.
9. The report argues that prices will stabilize and that wages will recover.
10. What the author was pointing to **was** that convenience can hide long-term costs.

<details>
<summary>骨架与应保留的期待位</summary>

1. `S = expansion`，`V = has changed`；`of...in...` 中的复数名词不填主句谓语。
2. `S = What...notice`，`V = was`，`C = that...`；完成 `notice` 后仍等外层 `was`。
3. `[Asked whether...]` 是背景；仍等 `the minister said`。
4. 一个主语 `Researchers` 开出两个并列谓语 `recorded / compared`。
5. 条件块结束后仍等倒装主句 `can the claim be trusted`。
6. `S = Calls [to...or to...]`，`V = ignore`；两个 `to` 都没有抢走主句谓语。
7. `[With...]` 是背景；主句为 `the agency has delayed`。
8. 头名词是单数 `The first`，所以谓语为 `was designed`；`sets/criteria` 都在 `of` 内。
9. `argues` 后并列两个同层内容：`that prices...` 与 `that wages...`。
10. `what` 从句作主语；内层 `was pointing to` 完成后，仍等外层 `was that...`。

</details>

## 分步复现

| 节点 | 任务 | 失败判定 |
|---|---|---|
| D1 | 同骨架短句，口头报“还欠什么” | 提前翻译完、漏报外层谓语 |
| D3 | 同骨架换主题，标主干 | 修饰语夺主干、并列层级错 |
| D7 | 两种触发器叠加 | 只处理内层，忘记外层债务 |
| D14 | 低熟悉真题句限时拆骨架 | 主干正确但明显依赖反复回读，记 `H` |
| D30 | 完整阅读中自然抽查 | 主干或逻辑范围再次坍塌，记 `F` |

专项得分按“控制点”计算，不按整句二元判定。比如第 6 题至少有：头名词、两个并列 `to`、主句谓语、宾语四个控制点；错一个就知道撞在哪次转弯，不会把整题只记成“又不会长难句”。

实际队列和每次结果只追加到 [`review-log.md`](review-log.md)，避免机制页与进度表出现两个版本。

某一骨架退出活动队列须在至少 14 天中三次 `S`，其中一次为两个结构叠加的新句，且能在首遍或一次可控回读中恢复主干。背得出 Day 128 的答案不算退出。
