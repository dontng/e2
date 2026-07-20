# STATE

T1 状态层。它不保存英语资料，不替代每日批改；它只把所有 T0 样本滚动成下一次训练的预警、进度和收益反馈。

## 当前进度

| 项目 | 状态 |
|---|---|
| 当前 day | Day 85 |
| 当前周 | 2026-W30 |
| 最近 7 天完成 | 6 / 7 |
| 当前 T0 范围 | `0518-day30` 到 `0721-day85` |
| 下一次打开 | 新增或批改 Day 86 |

## 当前风险

| 风险线 | 权重 | 证据 | 下一次预警 |
|---|---:|---|---|
| 固定表达识别 | high | `best and brightest`, `bargain bin`, `hold the key to`, `find themselves`, `give in to`, `blame A on B`, `make it`, `keep A away from B`, `make the point that`, `replace A with B` | 简单动词加介词或固定宾语结构时先按整体试读，再确定各成分关系 |
| 长句主干锁定 | high | `we have identified ... to make forecasts`, `The Constitutional principles ... are noncontroversial`, Day 81 双因果句 | 先标文章框架、现象、原因一、原因二，再回到完整主干 |
| 介词短语合读 | high | `access to`, `graduating into`, `at the prospect of`, `blame A on B` | 看到介词先圈完整信息块，判断它引出对象、原因还是路径 |
| 核心动词落地 | high | `suppress`, `descended`, `identified`, `precede`, `vanish`, `relate`, `automate`, `replace` | 每个语义块结束前检查核心动作；不会时至少先判方向 |
| 回指与省略 | high | `Myriad's`, `in which`, `find themselves`, Day 79 `which` | 关系词或代词进入中文前，必须回填明确对象或整件事 |
| 句子期待位保留 | high | Day 78 `The Constitutional principles that ... and that ... are noncontroversial`；Day 82 否定比较判断 | 抽象名词或比较结构开头先保留“最后结论是什么”的槽位 |
| 头名词挂载链 | high | Day 78 多解释块；Day 82 `Bill ... that ensures that ...` | 先判每个后置块挂给谁，再找主句谓语和中文重排 |
| 熟词跨语境迁移 | high | Day 78 `alone`, `precede`; Day 85 `hard-wired`; 既往简单词短语硬拼 | 常见释义发怪时，回到核心意象，再按当前对象关系落中文 |
| 二元框架与立场关系 | medium | Day 84 `look beyond ... right or wrong`, `middle ground` | 先建“不要只停在 X—为两端之间留出空间”的关系，再落中文 |
| 专名与语境定向 | medium | `Priestly`, `Federal Trade Commission`, `internet browsers`, `Washington` | 大写词先判专名/代指；政治法律词按制度层级限制词义 |
| 词形辨认 | medium | `district`, `competing`, `demoralization`, `automated` | 读完整词干与后缀，不因局部形近跳到熟词 |
| 因果与替换方向 | high | Day 81 `reason ... because ... but also because ...`, `replace A with B` | 先列“现象—原因一—原因二”；替换结构先标被替换者 A 和替代者 B |
| 否定比较关系 | medium | Day 82 `nothing would be more important than ...` | 把否定主语、比较级和 `than` 后对象一起封口，再收束成最高级判断 |
| 倒装与真主语 | medium | Day 83 `Along with A came B` | 前置伴随块后先找动词，再确认动词后的 B 才是真正主语 |

## 理解出口追踪

风险线记录“什么结构出错”；本表记录“理解从哪里断”。主标签只标最先导致坍塌的一步，必要时再保留次标签。

| 标签 | 权重 | 当前证据 | 下一次要验证的出口 |
|---|---:|---|---|
| `出口/义项` | high | `alone`, `precede`, `give in`, `make it`, `hold out` | 能否从常见义先走到更宽的动作，再落到当前对象 |
| `出口/关系` | high | `blame A on B`, `keep A away from B`, `replace A with B`；Day 82 否定比较级；Day 84 `beyond / middle ground` | 能否先用普通中文摆稳比较、边界、结果、原因、承受者与替代者 |
| `出口/期待` | high | Day 78 两个 `that` 后的主句谓语；Day 81 双因果骨架 | 能否保留“这个名词/现象最后怎么样”的未完成槽位 |
| `出口/挂载` | high | Day 78 多个后置解释块；Day 82 两个 `that` | 能否判断每块服务谁，再决定中文顺序 |
| `出口/语境` | medium | Day 79 `blame` 的归因/归咎；制度语境的 `precede` | 能否先守住关系，再按对象与立场调整中文 |
| `出口/重组` | high | Day 78、81 中文散裂；Day 83 前置伴随块后的倒装未还原 | 能否先恢复语义骨架和真主语，再前置、拆句或压缩 |

## 今日预警

1. 看到 `look beyond X`，先说“不只停在 X 的框架里”，不要把 `beyond` 直译成“背后”。
2. `right or wrong` 与 `middle ground` 同句出现时，先建立二分判断和折中空间的对照。
3. `hard-wired` 修饰反应或习惯时，从“线路预先接好”走到“自动触发、根深蒂固”；`likely to do` 保留未来方向。

## 收益反馈

| 项目 | 状态 |
|---|---|
| 已稳定 | 每日批改格式、周审计入口及原译证据保留已稳定 |
| 正在压低 | Day 79 已改为“义项过桥→关系落点”的 13 条训练包；后续检查它是否真能让出口走通 |
| 仍然活跃 | 固定表达、长句主干、从句挂载、二元框架关系、熟词跨语境迁移 |
| 下次验证 | 能否把 `beyond X` 读成边界外的判断，并在反应/习惯语境中正确落地 `hard-wired` |

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
| 动词短语未触发整体识别 | high | Day 79 `give in to` | 先圈动词 + 小品词/介词为单位，再决定是否逐词 |
| 已识别结构的语境落点偏差 | medium | Day 79 `blame A on B` | 固定关系后，按文本是在归因、归咎还是怪罪选择中文 |
| 双因果骨架被拆散 | high | Day 81 `reason ... because ... but also because ...` | 先写“现象—原因一—原因二”，不急着翻局部名词 |
| replace A with B 方向翻转 | high | Day 81 | A 是被替换者，B 是替代者；中文落成“用 B 替代 A” |
| have done ... to do 主干断裂 | high | `we have identified ... to make forecasts` | 先译“已经识别出……，从而能够……” |
| 长名词主语后的全句谓语漏读 | high | `The Constitutional principles ... are noncontroversial` | 越过插入从句，先用主语和最终谓语封口 |
| that A and that B 并列层级未识别 | medium | Day 78 | 先把两个 `that` 标成同级内容块 |
| 现在分词修饰误作并列动作 | medium | `patterns shaping the history` | `N + doing` 先试“正在/能够……的 N” |
| 技术载体类别误判 | medium | `internet browsers` | 技术名词先判软件、网页、平台、设备 |
| 感知动词后的第二动作丢失 | medium | `feel the oppression vanish` | `feel/see/hear + O + V` 先译“感到 O 做 V” |
| how/what/whether 从句作主语后谓语漏接 | high | `just how many others pay attention ... has little to do with` | 句首疑问词从句先封成“这件事”，再找后面的谓语 |
| 抽象名词 + that 内容从句后主句谓语期待位丢失 | high | Day 78 `The Constitutional principles that A and that B are noncontroversial` | 读到 `claim/fact/principle/belief + that完整句`，先留槽“这个名词怎么样” |
| that A and that B 内容块并列未切开 | medium | Day 78 两个 `that` 同级说明 `principles` | 重复 `that` 先试平级内容块，不把第二块误接进第一块 |
| 头名词后多解释块归属不清 | high | Day 78 probe：多个 `that/which/-ing/-ed/介词短语/逗号补充` 都可能服务最前名词 | 每个块先标归属和功能：内容、回指、依据、状态、同位补充 |
| 中文重排承受力不足 | medium | Day 78 probe：直球内容给出后仍因后置链过长而放弃 | 先建结构树；中文允许前置、拆句或压缩，不强行顺译 |
| 熟词跨语境后仍停在生活场景义 | high | Day 78 `alone` 只熟“孤独”，`precede` 只熟“之前/更早” | 常见释义别硬套；先抓“排除其他主体”“在前/优先”这类核心意象 |
| 英文通用动词到中文关系词转换不足 | medium | Day 78 `federal laws precede state laws` | 主宾是抽象对象时，先判关系类型，再落成“优先于/位于之前/成立/取决于”等中文关系词 |
| 否定主语 + 比较级 + than 未合读 | medium | Day 82 `nothing would be more important than passing ...` | 先说完整的“没有什么比 X 更重要”，再压缩成“X 最重要” |
| 前置 along with 块误作主语 | medium | Day 83 `Along with A came B` | 先恢复 `B came along with A`，再翻两组对象的对照 |
| 对照句中的词义极性翻转 | medium | Day 83 `permanent` 被译成“短暂” | 用同句 `no intention to stay` 反查方向，正反两端必须能够构成对照 |
| beyond + 抽象框架按空间字面拆开 | medium | Day 84 `look beyond the ... logic` | 先还原“不只停在 X 中判断”，再找 X 外要看的层次 |
| hard-wired + 反应按物理连接理解 | medium | Day 85 `hard-wired responses` | 先用“预先接好、自动触发”过桥，再落成“近乎本能/根深蒂固” |

## Codex 执行

- 用户说“继续”时，先读本文件，再读 `REVIEW.md` 和当前周总结。
- 批改前只给 3 条以内今日预警。
- 批改后只更新：风险线、收益反馈、下一次预警。
- 批改后同时做后台自检：预警是否命中、风险线是否需要拆分、是否出现新错误指纹。
- 批改和 drill 交付前按 `t1/CONSTITUTION.md` 自检：是否已标出主理解出口，且给出从已知义到句中义的过桥路径。
- 不把 T1 写成教学文章；所有记录都要服务下一次得分。
- 不默认用户已经吸收了所有历史 T1 内容；历史内容只作为训练材料，不作为已掌握前提。
- 重复风险再次出现时，不重复生成同质解释；引用相关日训练，把旧样本和今日样本合并成新的训练挑战。
- T1 要保持复利和创造力：同一风险反复出现时，输出新的考场动作、对照任务或验证方式，而不是围着旧表述兜圈。

## 当前专项 Drill

| 文件 | 目标 |
|---|---|
| `t1/july/0713-day78-structure-drill.md` | 抽象名词 + `that` 内容从句时，保留主句谓语槽位 |
| `t1/july/0713-head-noun-attachment-chain-drill.md` | 一个头名词后多解释块连续挂载时，先归属再重排 |
| `t1/july/0713-day78-meaning-shift-drill.md` | 熟词跨语境后，用核心意象迁移到当前对象关系 |
| `t1/july/0714-day79-phrase-chain-drill.md` | 从熟动词常见义走到句中义，再把介词关系落成活中文 |

## 用户交付物

T1 状态、风险权重和 Error Board 是 Codex 自己维护的后台体系，不是主要交付物。给用户的交付物应是专项训练包：

- 针对一个真实失分风险，给 3-10 条高质量例句或阅读片段。
- 每条材料标出应该理解的方向；句子复杂时给释义，生词影响理解时给必要翻译。
- 不做交互式问答，不要求用户一轮轮反馈，避免沟通成本放大。
- 不写幼儿园式逐词喂饭；要像好的代码注释或 commit message，一眼能懂意图，但保留训练强度。
- 训练包必须凝结考点考察方式，让用户读完能形成更快的考场反应。
- 训练包文件只保留“目标”和“训练材料”两类前台内容；不要堆历史连接、考场动作、下次预警等后台说明。
- 问题点较窄时给 5 条材料；问题点较大、较难、值得反复咀嚼时给 10 条材料。
