#!/usr/bin/env python3
"""word.py — 单词复习台后端：把词连同句子端上来读，不做判断。

usage:  word.py [repo_dir] [port]        （由根目录 word.sh 启动）

仅标准库，只绑 127.0.0.1。界面在 scripts/word.html。

复习模型：只读不评。一次只给一屏（≤SCREEN 词），一天可来多次。每个词被端上
读过一次 → 间隔渐宽地排到下次再现，永不毕业——保证每个词都反复回来。
状态存 data/vocab.json（本机本地，不入 git）。
"""
import sys
import json
import datetime
from pathlib import Path
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
import vocab

REPO = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else SCRIPTS.parent
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8788
PAGE = SCRIPTS / 'word.html'
STATE = REPO / 'data' / 'vocab.json'

SCREEN = 8                                  # 一屏几个词
INTERVALS = [1, 2, 4, 7, 12, 20, 30, 45, 60]   # 第 n 次读过后，隔几天再现


def load_state() -> dict:
    try:
        return json.loads(STATE.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}


def save_state(s: dict):
    STATE.parent.mkdir(exist_ok=True)
    STATE.write_text(json.dumps(s, ensure_ascii=False), encoding='utf-8')


def screen() -> dict:
    lib = vocab.collect_vocab(REPO)
    state = load_state()
    today = datetime.date.today()

    def due(w):
        st = state.get(w['word'].lower())
        return st is None or datetime.date.fromisoformat(st['due']) <= today

    pending = [w for w in lib if due(w)]
    pending.sort(key=lambda w: (state.get(w['word'].lower(), {}).get('seen', 0),
                                state.get(w['word'].lower(), {}).get('due', ''),
                                w['day']))
    return {'words': pending[:SCREEN], 'remaining': len(pending), 'total': len(lib)}


def mark_done(keys: list) -> dict:
    state = load_state()
    today = datetime.date.today()
    for k in keys:
        st = state.get(k, {'seen': 0})
        st['seen'] += 1
        st['last'] = today.isoformat()
        iv = INTERVALS[min(st['seen'] - 1, len(INTERVALS) - 1)]
        st['due'] = (today + datetime.timedelta(days=iv)).isoformat()
        state[k] = st
    save_state(state)
    return screen()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def _json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == '/api/screen':
            return self._json(screen())
        if self.path in ('/', '/index.html'):
            body = PAGE.read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self._json({'msg': 'not found'}, 404)

    def do_POST(self):
        if self.path != '/api/done':
            return self._json({'msg': 'not found'}, 404)
        length = int(self.headers.get('Content-Length') or 0)
        payload = json.loads(self.rfile.read(length) or b'{}')
        self._json(mark_done(payload.get('keys', [])))


def main():
    server = ThreadingHTTPServer(('127.0.0.1', PORT), Handler)
    print(f'word → http://127.0.0.1:{PORT}   (Ctrl-C 退出)')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == '__main__':
    sys.exit(main())
