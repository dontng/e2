# 词形辨认训练库

做题时只提交答案和决定性的字母段，不看本页后半的折叠答案。每轮最多十项；真实作答后由 Codex 将结果写入 `review-log.md`，下一轮只保留 `F/H` 与少量旧 `S` 抽查。

## Round A · 历史易混对

1. The two firms are `(competing / completing)` for the same contract.
2. The decline was `(somewhat / somehow)` slower than expected.
3. The probe is `(reaching / researching)` the edge of the solar system.
4. The two scores were `(combined / compared)` to form one index.
5. The report noted a `(rise / risk)` in household debt.
6. The delay was `(due / duty)` to a shortage of inspectors.
7. The panel published its `(assessment / access)` of the evidence.
8. The course introduces `(astronomy / aviation)` through telescope images.
9. The proposal offered a `(novel / noble)` way to reduce waste.
10. Several `(sets / seats)` of criteria were tested.

<details>
<summary>Round A 答案</summary>

`competing—compet`；`somewhat—what`；`reaching—无 res`；`combined—bin`；`rise—无 k`；`due—完整 due`；`assessment—assess`；`astronomy—astro`；`novel—v`；`sets—set+s`。

</details>

## Round B · 旧错词去选项重认

先读句子，再抄出加粗词的完整拼写、词性和本句义。

1. The reform was supported by a broad **coalition of civic institutions**.
2. The exhibition examines the **intellectual** history of the period.
3. The new rule follows a **conventional** approach to licensing.
4. A prolonged recession can deepen public **demoralization**.
5. The court heard evidence from three **jurors**.
6. The crisis damaged the directors' **reputations**.
7. The dance **troupe** will perform in six cities.
8. The policy was introduced **unintentionally** through a drafting error.

<details>
<summary>Round B 最小答案</summary>

1. `institutions`，名词复数，制度/机构；2. `intellectual`，形容词，思想/智识方面的；3. `conventional`，形容词，传统/常规的；4. `demoralization`，名词，士气低落/精神受挫；5. `jurors`，陪审员；6. `reputations`，声誉；7. `troupe`，演出团；8. `unintentionally`，非故意地。

</details>

## Round C · 段落压力测试

只标出下段五个加粗词，不翻译全文。写出它们分别不可能是哪一个历史错词，并说明一个句内校验。

> A **conventional** review found that two **sets** of safety criteria, when **combined**, produced a more reliable **assessment** of the **risk** faced by regional hospitals.

<details>
<summary>Round C 校验</summary>

`conventional` 不是 congressional；`sets` 不是 seats；`combined` 不是 compared；`assessment` 不是 access；本题这里实际是 `risk`，不是 `rise`——因为医院“面临”的是风险。最后一项故意要求句义推翻机械记忆：训练目标是读对纸面，不是永远选左栏。

</details>

## 生成后续轮次的约束

- D1 保留相同目标词，必须换句；D3 才允许让易混词作为正确答案出现。
- D7 去掉选项；D14 放入低熟悉主题短段；D30 优先从真题自然抽查。
- 同一组第三次失败，缩成一对并要求逐字指出差异，不扩大词表。
