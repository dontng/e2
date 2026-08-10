# 微信文章转换工具

`convert_wechat_daily.py` 把微信导出的“长难句每日一句”HTML整理成 `src-we/MMDD-dayN.md`。

它只保留以下内容：

- 原句、出处和思考题
- 找谓语动词及原文高亮提示
- 生词
- 断句、简化和原文中的红色/删除线格式
- 参考译文

图片、开头答疑、视频、语法重点、难点提示及后续预习不会进入结果。

## 单篇转换

```powershell
python src-we/_tools/convert_wechat_daily.py "C:\path\article.html"
```

脚本读取文章发布时间和 `Day N`，自动生成类似 `0810-day101.md` 的文件名。

## 批量转换

把 HTML 放进 `src-we/_inbox/`，然后运行：

```powershell
python src-we/_tools/convert_wechat_daily.py src-we/_inbox
```

## 检查结果是否需要更新

```powershell
python src-we/_tools/convert_wechat_daily.py src-we/_inbox --check
```

脚本只依赖 Python 标准库，不需要安装额外包。微信编辑器结构发生变化时，脚本会明确报错，不会静默生成残缺文件。
