# 翻译插件组合 · 快速配置

英二每日翻译用的 VS Code 插件两件套：侧栏生词概览 + hover 悬浮翻译（含翻译/释义/例句/词源）。

## 插件清单

| 插件 | 扩展 ID | 作用 |
|------|---------|------|
| 会了吧 | `mqycn.huile8` | 打开文件自动扫词 → 侧栏生词列表 + 标记已掌握/陌生 |
| Code Translate | `w88975.code-translate` | hover 悬浮翻译，340 万离线词库 + 在线释义例句 |

## 1. 安装

```bash
code --install-extension mqycn.huile8
code --install-extension w88975.code-translate
```

## 2. 设置

打开 VS Code 设置（`Ctrl+,`）→ 右上角 `{}` 切换到 JSON，或直接编辑文件：

- **Linux (WSL)**: `~/.vscode-server/data/User/settings.json`
- **macOS**: `~/Library/Application Support/Code/User/settings.json`
- **Windows**: `%APPDATA%\Code\User\settings.json`

```json
{
    "EnglishChineseDictionary.enableHover": false,
    "Translate-next.hover.enable": false
}
```

> 上面两行是**防冲突**的——如果你装了其他翻译扩展（英汉词典、translate-next 等），关掉它们的 hover，只留 Code Translate。

## 3. 替换 hover 内容（含翻译 + 释义 + 例句 + 词源）

Code Translate 默认只显示基本翻译。替换源文件以获得四段式 hover：

找到扩展目录 `~/.vscode-server/extensions/w88975.code-translate-*/src/index.js`，替换为以下内容：

```javascript
const vscode = require('vscode')
const https = require('https')
const DICTQuery = require('./query')
const formatter = require('./format')

function fetchOnlineDict(word) {
  return new Promise((resolve) => {
    const url = `https://api.dictionaryapi.dev/api/v2/entries/en/${encodeURIComponent(word)}`
    const req = https.get(url, { timeout: 2000 }, (res) => {
      let data = ''
      res.on('data', chunk => data += chunk)
      res.on('end', () => {
        try { resolve(JSON.parse(data)) } catch (_) { resolve(null) }
      })
    })
    req.on('error', () => resolve(null))
    req.setTimeout(2000, () => { req.destroy(); resolve(null) })
  })
}

function extractAPIData(apiResult) {
  if (!apiResult || !Array.isArray(apiResult) || !apiResult[0]) return null
  const entry = apiResult[0]
  const items = []
  for (const m of (entry.meanings || []).slice(0, 3)) {
    const pos = m.partOfSpeech || ''
    for (const d of (m.definitions || []).slice(0, 2)) {
      items.push({ pos, definition: d.definition || '', example: d.example || '' })
    }
  }
  return items.length > 0 ? items : null
}

function buildHover(word, localResult, apiItems) {
  const sections = []
  const langUrl = `https://translate.google.com?text=${encodeURIComponent(word)}`

  sections.push(`### ${word}`)
  sections.push('---')
  sections.push('**📖 翻译**')
  if (localResult.w) {
    sections.push(localResult.w)
  } else {
    sections.push(`[查在线翻译](${langUrl})`)
  }

  if (apiItems && apiItems.length > 0) {
    sections.push('')
    sections.push('**📝 释义**')
    for (const item of apiItems.slice(0, 4)) {
      let line = `*${item.definition}*`
      if (item.pos) line += ` *\`${item.pos}\`*`
      sections.push(line)
      if (item.example) {
        sections.push(`> ${item.example}`)
      }
    }
  }

  sections.push('')
  sections.push(`[🔗 词源 (Etymonline)](https://www.etymonline.com/search?q=${encodeURIComponent(word)}) · [Wiktionary](https://en.wiktionary.org/wiki/${encodeURIComponent(word)})`)

  return new vscode.MarkdownString(sections.join('\n'))
}

async function init() {
  vscode.languages.registerHoverProvider('*', {
    async provideHover(document, position) {
      if (!document.getWordRangeAtPosition(position)) return
      let word = document.getText(document.getWordRangeAtPosition(position))
      let selectText = vscode.window.activeTextEditor?.document.getText(vscode.window.activeTextEditor.selection)
      if (selectText && word.indexOf(selectText) > -1) word = selectText
      let cleaned = formatter.cleanWord(word)
      const words = formatter.getWordArray(cleaned)
      if (!words || words.length === 0) return
      const lookupWord = words[0]
      const [localResult, apiResult] = await Promise.all([
        DICTQuery(lookupWord),
        fetchOnlineDict(lookupWord),
      ])
      const apiItems = extractAPIData(apiResult)
      return buildHover(lookupWord, localResult, apiItems)
    }
  })
}

module.exports = { init }
```

> **一键脚本**（在扩展目录下执行）：
> ```bash
> EXT_DIR=$(ls -d ~/.vscode-server/extensions/w88975.code-translate-*/src 2>/dev/null | head -1)
> if [ -d "$EXT_DIR" ]; then
>   cat > "$EXT_DIR/index.js" << 'JS'
> // 粘贴上面的完整 JS 代码
> JS
>   echo "Done: $EXT_DIR/index.js"
> else
>   echo "Extension not found, install it first"
> fi
> ```

## 4. 重载

`Ctrl+Shift+P` → `Developer: Reload Window`

## 5. 日常用法

1. 打开 markdown → **会了吧**自动在侧栏列出所有生词（概览用）
2. 读原文时**鼠标悬停**在任何生词上 → **Code Translate** 弹出四段式翻译
3. 查完理解后用会了吧侧栏**内联按钮**标记「已掌握」/「陌生」（打卡用）

## hover 浮窗字段

| Section | 数据来源 | 说明 |
|---------|---------|------|
| 📖 翻译 | 本地 340 万词库 | 中文释义，始终有 |
| 📝 释义 | 在线 Free Dictionary API | 英文释义 + 例句，视单词而定。API 超时则仅显示翻译 |
| 🔗 词源 | Etymonline / Wiktionary | 点击跳转查看词根词缀词源 |

## 卸载

```bash
code --uninstall-extension mqycn.huile8
code --uninstall-extension w88975.code-translate
```
