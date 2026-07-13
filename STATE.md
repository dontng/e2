# STATE

T1 状态层。它不保存英语资料，不替代每日批改；它只把所有 T0 样本滚动成下一次训练的预警、进度和收益反馈。

## 当前进度

| 项目 | 状态 |
|---|---|
| 当前 day | Day 79 |
| 当前周 | 2026-W29 |
| 最近 7 天完成 | 6 / 7 |
| 当前 T0 范围 | `0518-day30` 到 `0714-day79` |
| 下一次打开 | 新增或批改 Day 80 |

## 当前风险

| 风险线 | 权重 | 证据 | 下一次预警 |
|---|---:|---|---|
| 固定表达识别 | high | `best and brightest`, `bargain bin`, `hold the key to`, `find themselves`, `give in to`, `blame A on B` | 简单动词加介词先按短语试读，再确定各成分关系 |
| 长句主干锁定 | high | `we have identified ... to make forecasts`, `The Constitutional principles ... are noncontroversial` | 长名词主语后越过 `that/which` 从句，找全句有限谓语 |
| 介词短语合读 | high | `access to`, `graduating into`, `at the prospect of`, `blame A on B` | 看到介词先圈完整信息块，判断它引出对象、原因还是路径 |
| 核心动词落地 | high | `suppress`, `descended`, `identified`, `precede`, `vanish` | 每个语义块结束前检查核心动作；不会时至少先判方向 |
| 回指与省略 | high | `Myriad's`, `in which`, `find themselves`, Day 79 `which` | 关系词或代词进入中文前，必须回填明确对象或整件事 |
| 专名与语境定向 | medium | `Priestly`, `Federal Trade Commission`, `internet browsers`, `Washington` | 大写词先判专名/代指；政治法律词按制度层级限制词义 |
| 词形辨认 | medium | `district`, `competing`, `demoralization` | 读完整词干与后缀，不因局部形近跳到熟词 |

## 今日预警

1. 长名词主语后有 `that/which` 时，先越过从句找到全句真正谓语。
2. 简单动词加介词先试固定表达；关系代词先回填先行词。
3. 每个语义块都要落下核心动作，尤其注意感知结构后的第二个动词。

## 收益反馈

| 项目 | 状态 |
|---|---|
| 已稳定 | 每日批改格式、周审计入口及原译证据保留已稳定 |
| 正在压低 | 关系代词回填；已生成 Day 79 窄专项进行集中训练 |
| 仍然活跃 | 固定表达、长句主干、核心动词、介词论元关系 |
| 下次验证 | 能否找到长主语后的全句谓语，并保住每个语义块的核心动作 |

## T1 量化口径

- 不按“学完语法/句法/搭配”计量；按失分风险是否下降计量。
- 每个风险线只有三档：`high`、`medium`、`low`。
- 连续命中同类错误，风险保持或升高；连续避开同类错误，风险下降。
- 新问题不需要先命名；只要影响得分，就进入风险线或观察项。
- T1 的目标是让全部已积累样本提高下一次预警和训练包质量，不是只做相邻两天传递。
- 用户不是 T1 维护者；风险拆分、drill 自评、预警命中回溯由 Codex 在后台完成。

## T1 自觉机制

- 风险线只做总览；真正的训练入口是错误指纹。
- 一个错误指纹 = 一个可复现误判路线 + 一个考场反射。
- 同一风险线下若证据明显分成多个反射，Codex 自动拆分，不等待用户指出。
- 生成 drill 前必须自评：这份材料训练的是 1 个反射还是多个反射。
- 如果训练多个反射，自动拆成窄 drill；不要交付展示型合集。
- 批改后回溯今日预警：命中真实错误则保留或强化；连续空炮则改写预警。
- Probe 暴露的认知流程问题先进入观察项；证据不足时不急于训练，但不能遗忘。

## 错误指纹候选

| 指纹 | 状态 | 证据 | 训练反射 |
|---|---|---|---|
| 名词 + to + 资源/机会误判为动作 | high | `access to` | `to` 后先判资源/机会，不急着译成动作 |
| into + 外部环境误判为时间背景 | medium | `graduating into` | `into` 后是毕业时进入的局面 |
| at the prospect of + 名词化事件未合读 | medium | `at the prospect of` | 先把 prospect 后的事件封成担忧对象 |
| from A to B to C 路径未画线 | medium | `descended from ... to ... to ...` | 先画路径，再落中文动词 |
| in which 回指悬空 | medium | `in which` | `which` 必须回前文补地点/范围名词 |
| 关系代词未先回填先行词 | high | Day 79 `which`, 既往 `in which` | 先说出“这个词替代谁/哪件事”，再读从句 |
| 简单词固定表达逐词硬拼 | high | `best and brightest`, `bargain bin`, `hold the key to`, `find oneself in`, `give in to` | 先把简单词组合按短语查义，再决定是否逐词 |
| blame A on B 论元关系倒置 | medium | Day 79 | 先标结果 A、原因 B，再落成“把 A 归因于 B” |
| have done ... to do 主干断裂 | high | `we have identified ... to make forecasts` | 先译“已经识别出……，从而能够……” |
| 长名词主语后的全句谓语漏读 | high | `The Constitutional principles ... are noncontroversial` | 越过插入从句，先用主语和最终谓语封口 |
| that A and that B 并列层级未识别 | medium | Day 78 | 先把两个 `that` 标成同级内容块 |
| 现在分词修饰误作并列动作 | medium | `patterns shaping the history` | `N + doing` 先试“正在/能够……的 N” |
| 技术载体类别误判 | medium | `internet browsers` | 技术名词先判软件、网页、平台、设备 |
| 感知动词后的第二动作丢失 | medium | `feel the oppression vanish` | `feel/see/hear + O + V` 先译“感到 O 做 V” |
| how/what/whether 从句作主语后谓语漏接 | high | `just how many others pay attention ... has little to do with` | 句首疑问词从句先封成“这件事”，再找后面的谓语 |

## Codex 执行

- 用户说“继续”时，先读本文件，再读 `REVIEW.md` 和当前周总结。
- 批改前只给 3 条以内今日预警。
- 批改后只更新：风险线、收益反馈、下一次预警。
- 批改后同时做后台自检：预警是否命中、风险线是否需要拆分、是否出现新错误指纹。
- 不把 T1 写成教学文章；所有记录都要服务下一次得分。
- 不默认用户已经吸收了所有历史 T1 内容；历史内容只作为训练材料，不作为已掌握前提。
- 重复风险再次出现时，不重复生成同质解释；引用相关日训练，把旧样本和今日样本合并成新的训练挑战。
- T1 要保持复利和创造力：同一风险反复出现时，输出新的考场动作、对照任务或验证方式，而不是围着旧表述兜圈。

## 用户交付物

T1 状态、风险权重和 Error Board 是 Codex 自己维护的后台体系，不是主要交付物。给用户的交付物应是专项训练包：

- 针对一个真实失分风险，给 3-10 条高质量例句或阅读片段。
- 每条材料标出应该理解的方向；句子复杂时给释义，生词影响理解时给必要翻译。
- 不做交互式问答，不要求用户一轮轮反馈，避免沟通成本放大。
- 不写幼儿园式逐词喂饭；要像好的代码注释或 commit message，一眼能懂意图，但保留训练强度。
- 训练包必须凝结考点考察方式，让用户读完能形成更快的考场反应。
- 训练包文件只保留“目标”和“训练材料”两类前台内容；不要堆历史连接、考场动作、下次预警等后台说明。
- 问题点较窄时给 5 条材料；问题点较大、较难、值得反复咀嚼时给 10 条材料。
