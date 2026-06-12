#!/bin/bash
# studio.sh — 启动本地交互台并打开浏览器
# usage:  bash studio.sh          # 默认端口 8787
#         PORT=9000 bash studio.sh

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-8787}"
URL="http://127.0.0.1:$PORT"

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
