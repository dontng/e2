# 微信文章转换工具

## 阅读每日一题

`convert_wechat_question.py` 把微信导出的“阅读每日一题”HTML整理成
`src-we/questions/YYYY/MMDD-questionNNN.md`。转换结果保留真题段落、题目、选项、
解题方法、词汇、长难句和高分辨率解析图，并把答案与讲解放进折叠区域；视频提示、
次日预告和公众号宣传内容会被排除。标题层级、生词的 `✅` 格式、红色强调、加粗和
删除线沿用“每日一句”的 Markdown 约定；黄色行内重点转换为稳定的高亮，黄色栏目名
则转换为 Markdown 标题。

单篇或少量试转换：

```powershell
python src-we/_tools/convert_wechat_question.py "src-we/_inbox/2025/每日一题/article.html"
```

批量转换入口：

```powershell
python src-we/_tools/convert_wechat_question.py "src-we/_inbox/2025/每日一题"
```

批量模式只处理文件名含三位题号（如 `每日一题001`）的文章；周复习、学习建议等
非标准文章会提示并跳过。由于部分文章没有可可靠抽取的文字答案，转换器会中止而不
猜测；当前已人工核验 `001`、`002` 两篇。用 `--check` 可以检查现有 Markdown 是否
与 HTML 一致。

## 长难句每日一句

`convert_wechat_daily.py` 把微信导出的“长难句每日一句”HTML按发布年份整理成
`src-we/YYYY/MMDD-dayN.md`。

它只保留以下内容：

- 原句、出处和思考题
- 找谓语动词及原文高亮提示
- 生词
- 断句、简化和原文中的红色/删除线格式
- 语法重点及原文中的强调格式
- 翻译要点（原文有该栏目时）
- 参考译文
- 仅以图片呈现的原句、分析或语法内容（2025 版页面）

页眉装饰图、二维码、结尾宣传图、开头答疑、视频、难点提示及后续预习不会进入结果。

## 单篇转换

```powershell
python src-we/_tools/convert_wechat_daily.py "C:\path\article.html"
```

脚本读取文章发布时间和 `Day N`，自动生成类似
`src-we/2026/0810-day101.md` 的路径。

## 批量转换

把 HTML 放进 `src-we/_inbox/`，然后运行：

```powershell
python src-we/_tools/convert_wechat_daily.py "src-we/_inbox/2026/每日一句"
```

批量转换时以 HTML 正文中的 `DAY N` 标记识别每日一句；同目录内没有该标记的通知、汇总等文章会明确提示并跳过。

## 检查结果是否需要更新

```powershell
python src-we/_tools/convert_wechat_daily.py src-we/_inbox --check
```

脚本只依赖 Python 标准库，不需要安装额外包。微信编辑器结构发生变化时，脚本会明确报错，不会静默生成残缺文件。

## 跨年重复

`dedupe-ignore.txt` 记录已经确认应从 Markdown 语料中排除、但仍需保留原始 HTML
证据的输出路径。转换器遇到清单中的目标时会显示
`SKIP deduplicated`，不会重新生成已删除的重复文件；`--check` 也把这些路径视为
有意跳过，而不是缺失。

需要恢复某篇时，先从清单中删除对应的 `YYYY/MMDD-dayN.md`，再重新运行转换。
