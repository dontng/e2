# T1-01 · 词形辨认：先看全，再调义

这个专项不负责扩充一张无限词表，只处理一种已经反复造成整句失控的问题：眼睛只取了单词的一部分，脑中先到的熟词替换了纸面上的词。目标不是“这次订正”，而是在新句里稳定完成 **完整取形 → 区分信号 → 句内校验**。

本目录的长期数据分别放在：[历史错例](cases.md) · [闭卷训练](drills.md) · [复测记录](review-log.md)。本页只保留机制说明和首次入口。

## 哪些词进入这里

只有真实阅读中发生过以下情况的词进入活动队列：漏看字母、添看字母、把长词压成相似熟词，或看见词根就直接拼义。一个词如果只是义项调错，转入 [`02-familiar-sense.md`](../02-familiar-sense/)；词认对但没找到谓语，转入 [`03-expectation-slots.md`](../03-expectation-slots/)。

## 已发生的错误，不再当作“粗心”

| 首次证据 | 纸面词 | 当时调出的词/意思 | 下次必须抓住的区分信号 |
|---|---|---|---|
| [Day 67](../../archive-src/june/0630-day67-v2.md) | `competing` | `completing` | `compet-` 是竞争；`complet-` 才是完成 |
| [Day 70](../../src/26-07/0703-day70.md) | `district` | `restriction` | `dis-trict` 很短；没有 `re-` 和 `-tion` |
| [Day 79](../../src/26-07/0714-day79.md) | `demoralization` | `democracy` | 中段是 `moral`，末尾是过程名词 `-ization` |
| [Day 101](../../src/26-08/0810-day101.md) | `novel` | `noble` | 逐字保住 `v`；`novel idea` 是新颖的想法 |
| [Day 125](../../src/26-09/0907-day125.md) | `somewhat` | `somehow` | 尾部 `what` 表程度，`how` 表方式 |
| [Day 125](../../src/26-09/0907-day125.md) | `reaching` | `researching` | `reach` 后直接接 `-ing`，没有 `res-` |
| [Day 126](../../src/26-09/0908-day126.md) | `rationally` | `randomly`/“随心” | 中段 `ration` 指理性；`random` 才是随机 |
| [Day 127](../../src/26-09/0909-day127.md) | `combined / rise / due` | `compared / risk / duty` | 分别锁定 `bin / se / due`，不可只看开头 |
| [Day 128](../../src/26-09/0910-day128.md) | `astronomy` | 航空 | `astro-` 是星体；航空是 `aviation` |
| [Day 130](../../src/26-09/0912-day130.md) | `assessment / sets` | `access / seat` | `assess + ment`；`set` 的复数只有一个 `e` |

活动词不是把左右两栏都背一遍。优先主动掌握纸面词；右栏只作为一次“排除旧反应”的对照。`criteria` 等在句中迟疑过但未发生稳定替换的词，先留作观察项，不挤进活动队列。

## 考场动作：一秒钟完成三道闸

1. **看全**：从首字母扫到词尾，长词至少抓“词头—中段—词尾”三个点。
2. **判别**：说出使它不可能是旧错词的那一小段，如 `reaching` 没有 `res-`。
3. **回句**：检查词性和搭配能否占住当前位置。`a somewhat difficult task` 需要程度副词，不能塞入“以某种方式”。

不要在考场上默写词根分析。训练时把三闸做慢，最终压缩成看到全词后的直接识别。

## D0 重建：先做，后展开答案

只写括号中的正确词，并圈出决定你的字母段。

1. Two local firms are **(competing / completing)** for the contract.
2. The decline was **(somewhat / somehow)** slower than expected.
3. The probe is **(reaching / researching)** the outer edge of the system.
4. The policy led to a **(rise / risk)** in housing costs.
5. The delay was **(due / duty)** largely to staff shortages.
6. The panel published its **(assessment / access)** of the proposal.
7. The two scores were **(combined / compared)** to create a single index.
8. She offered a **(novel / noble)** solution to an old problem.
9. The course introduces modern **(astronomy / aviation)** through telescope images.
10. The two **(sets / seats)** of criteria produced different rankings.

<details>
<summary>答案与最小校验</summary>

1. `competing`：`compet-`；且 `for` 与竞争相接。
2. `somewhat`：`-what`；修饰比较级 `slower`，表示“有些”。
3. `reaching`：没有 `res-`；探测器“到达”边缘。
4. `rise`：没有 `k`；`a rise in` 是“……的上升”。
5. `due`：完整三字母；`due to` 表原因。
6. `assessment`：`assess-ment`；委员会发布评估。
7. `combined`：`combine A to create B`；两个分数被合并成一个指标。
8. `novel`：中间是 `v`；修饰方案时为“新颖的”。
9. `astronomy`：`astro-`；望远镜图像提供语义校验。
10. `sets`：`set + s`；两套标准。

</details>

## 延时复测队列

每次只测当前到期项目，Codex 根据实际作答维护状态；不要求学习者另抄表格。

| 节点 | 测什么 | 通过条件 |
|---|---|---|
| D1 | 原词换句重认 | 词形正确，能指出一个区分段 |
| D3 | 易混项同场对比 | 不靠中文提示选对，并用句内位置校验 |
| D7 | 无选项的新句 | 直接读出纸面词及本句义 |
| D14 | 低熟悉主题迁移 | 没有明显停顿，也不先调出旧错词 |
| D30 | 真题/真实阅读抽查 | 首遍识别正确，句子关系不受损 |

记录只用三种结果：`F`（错认）、`H`（对但明显犹豫）、`S`（直接成功）。出现 `F` 就回到 D1，并更换语境；同一路径第三次复发时，只增加一个更窄的形态对比，不再追加一篇解释。

实际队列和每次结果只追加到 [`review-log.md`](review-log.md)，避免机制页与进度表出现两个版本。

## 专项退出，不等于永不复习

一个词离开活动队列须同时满足：至少 14 天内三次 `S`、其中一次为无选项新语境、全程无中文提示且无明显犹豫。退出后仍可被完整真题抽查；若再次误认，按新证据重新入队。某天把十题全做对，只能证明当天会做，不能证明已稳定。
