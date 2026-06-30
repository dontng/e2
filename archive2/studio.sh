#!/bin/bash
# studio.sh — 启动本地交互台并打开浏览器
# usage:  bash studio.sh          # 默认端口 8787
#         PORT=9000 bash studio.sh

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-8787}"
URL="http://127.0.0.1:$PORT"

# 兄弟页：单词台（8788）。没在跑就顺手后台拉起，省得另开终端敲 word.sh，
# 这样页面里「单词 ↗」链接随时点得通。
if ! (exec 3<>/dev/tcp/127.0.0.1/8788) 2>/dev/null; then
    nohup python3 "$REPO_DIR/scripts/word.py" "$REPO_DIR" 8788 >/dev/null 2>&1 &
fi

(
    sleep 0.8
    if command -v wslview >/dev/null 2>&1; then wslview "$URL"
    elif command -v cmd.exe >/dev/null 2>&1; then cmd.exe /c start "$URL" 2>/dev/null
    elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL"
    elif command -v open >/dev/null 2>&1; then open "$URL"
    else echo "请手动打开 $URL"
    fi
) &

exec python3 "$REPO_DIR/scripts/studio.py" "$REPO_DIR" "$PORT"
