# 2020 英语（二）真题现场

[打开整卷](20.html)；[打开原来的 Text 1 页面](20-text1.html)。直接用 VS Code Live Server 预览即可。主页面先是封面，然后按第 1—2 页、第 3—4 页……翻动，奇数页在左、偶数页在右。顶部只保留翻页和“原题 / 复盘”；左右方向键翻页，Text 1 复盘可用 X、C 和 Enter 操作解析。

## 内容怎么维护

```text
20.html                         整卷入口和简洁工具栏
20-text1.html                   改版前完整 Text 1 页面，原样保留
viewer/reader.css              整卷与各题型文字页的样式
viewer/text1-layout.css        已经商定的 Text 1 版式与折叠样式
viewer/reader.js               双页翻动、原题/复盘、笔记快捷键
papers/2020/pages.js           页序、页码和双页组合
papers/2020/text1-layout.js    旧版 Text 1 的段落、题目及解析插槽
papers/2020/notes.js           Text 1 的 13 处既有复盘内容
papers/2020/full-paper.js      其他各页的段落、题干、选项、任务说明
papers/2020/assets/2020-writing-chart.webp   作文题原卷图表
tools/build-semantic-paper.py   由已核对原卷重建其他页文字的脚本
```

第 3—4 页复用旧版 Text 1 的文字排版和原位折叠；其他页面也按段落、题干和选项抄成可选中的 HTML。第 14 页图表保留为单独裁切的图像，题目要求仍是文字。解析只在已经有作答证据的 Text 1 出现；其他页先保持原题现场，答题记录日后可单独上传或填写，再据此补解析。原卷来源是 `archive-e2/2020年考研英语二真题.pdf`；排版时应逐页与原卷对照，尤其不能把 PDF 文字层误识别的字符当成原题。
