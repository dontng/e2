#!/usr/bin/env python3
"""studio.py — 本地交互台：在浏览器里完成 写译 → 批改 → 重译 的全部日常。

usage:  studio.py [repo_dir] [port]        （由根目录 studio.sh 启动）

仅标准库，只绑定 127.0.0.1。界面在 scripts/studio.html。
保存动作写回 src/ 的 markdown 并 touch 唤醒文件，auto-review 在 ≤15s 内接手。
"""
import sys
import os
import re
import json
import datetime
import subprocess
from pathlib import Path
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
import review
import scores as scores_mod

REPO = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else SCRIPTS.parent
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8787
WAKE = REPO / '.auto-review-wake'
PAGE = SCRIPTS / 'studio.html'


def exam_date() -> datetime.date:
    """EXAM_DATE 的唯一定义在 console.sh，这里读取而不复制。"""
    m = re.search(r'EXAM_DATE="(\d{4}-\d{2}-\d{2})"', (SCRIPTS / 'console.sh').read_text())
    return datetime.date.fromisoformat(m.group(1))


def github_base() -> str:
    try:
        url = subprocess.run(['git', 'config', 'remote.origin.url'],
                             cwd=REPO, capture_output=True, text=True).stdout.strip()
        m = re.search(r'github\.com[:/](.+?)(?:\.git)?$', url)
        return f'https://github.com/{m.group(1)}/blob/main/' if m else ''
    except OSError:
        return ''


GH = github_base()


def proc_alive(needle: str) -> bool:
    me = str(os.getpid())
    for p in Path('/proc').glob('[0-9]*'):
        if p.name == me:
            continue
        try:
            cmd = (p / 'cmdline').read_bytes().decode(errors='ignore').replace('\x00', ' ')
        except OSError:
            continue
        if needle in cmd:
            return True
    return False


def find_day_file(mmdd: str):
    hits = sorted(REPO.glob(f'src/*/{mmdd}-day*.md'))
    return hits[0] if hits else None


def get_state() -> dict:
    today = datetime.date.today()
    mmdd = today.strftime('%m%d')
    f = find_day_file(mmdd)

    data = scores_mod.collect(REPO)
    entries, redos = data['entries'], data['redos']
    next_day = max(entries, default=0) + 1

    t = {'exists': False, 'mmdd': mmdd, 'next_day': next_day}
    blocks = []
    if f:
        text = f.read_text(encoding='utf-8')
        rel = str(f.relative_to(REPO))
        stem = f.name[:-3]
        fool_rel = f'fool/{f.parent.name}/{stem}-fool.md'
        probe_rel = f'probe/{f.parent.name}/{stem}-probe.md'
        t = {
            'exists': True, 'mmdd': mmdd, 'next_day': next_day,
            'day': int(re.search(r'-day(\d+)\.md$', f.name).group(1)),
            'rel': rel,
            'gh': GH + rel if GH else '',
            'gh_fool': GH + fool_rel if GH and (REPO / fool_rel).exists() else '',
            'gh_probe': GH + probe_rel if GH and (REPO / probe_rel).exists() else '',
            'sentence': review.section(text, '原句'),
            'translation': review.section(text, '我的理解和翻译'),
            'correction': review.section(text, '批改'),
            'score': review.section(text, '评分'),
        }
        blocks = review.parse_blocks(text)
        for b in blocks:                      # 盲译：未批改前不暴露任何答案信息
            if not b['feedback']:
                b.pop('first', None)

    scored = [(d, e) for d, e in sorted(entries.items()) if e['score']]
    rows = []
    for day in sorted(entries, reverse=True)[:10]:
        e = entries[day]
        rows.append({'day': day, 'date': f"{e['mmdd'][:2]}/{e['mmdd'][2:]}",
                     'first': e['score'],
                     'redos': [{'score': s, 'trend': tr, 'date': f'{m[:2]}/{m[2:]}'}
                               for m, s, tr in redos.get(day, [])]})

    log_tail = []
    log_file = REPO / '.auto-review.log'
    if log_file.exists():
        log_tail = log_file.read_text(encoding='utf-8', errors='ignore').splitlines()[-5:]

    return {
        'days_left': (exam_date() - today).days,
        'today': t,
        'redo_blocks': blocks,
        'chart': [{'day': d, 'score': float(e['score'])} for d, e in scored[-14:]],
        'rows': rows,
        'total': len(entries),
        'daemon': {'auto_review': proc_alive('auto-review.sh'),
                   'knight': proc_alive('knight.sh')},
        'log_tail': log_tail,
    }


def wake():
    WAKE.touch()


def do_save(payload: dict) -> dict:
    f = find_day_file(datetime.date.today().strftime('%m%d'))
    if not f:
        return {'ok': False, 'msg': '今天的文件还不存在'}
    kind, content = payload.get('kind'), payload.get('content', '')
    if not content.strip():
        return {'ok': False, 'msg': '内容为空'}

    if kind == 'sentence':
        quoted = '\n'.join(
            l if l.startswith('>') or not l.strip() else '> ' + l
            for l in content.strip().splitlines())
        ok = review.set_section(f, '原句', quoted)
    elif kind == 'translation':
        if review.section(f.read_text(encoding='utf-8'), '批改'):
            return {'ok': False, 'msg': '已批改，不可再改首译'}
        ok = review.set_section(f, '我的理解和翻译', content)
    elif kind == 'redo':
        ok = review.fill_redo(f, int(payload['day']), content)
    else:
        return {'ok': False, 'msg': f'未知类型 {kind}'}

    if ok:
        wake()
    return {'ok': ok, 'msg': '已保存，批改将在片刻后出现' if ok else '写入失败'}


def do_new_day(payload: dict) -> dict:
    arg = ['tomorrow'] if payload.get('when') == 'tomorrow' else []
    r = subprocess.run(['bash', 'new-day.sh', *arg], cwd=REPO,
                       capture_output=True, text=True)
    return {'ok': r.returncode == 0, 'msg': (r.stdout + r.stderr).strip()}


def do_daemon_start(_: dict) -> dict:
    if proc_alive('auto-review.sh'):
        return {'ok': True, 'msg': 'auto-review 已在运行'}
    subprocess.Popen('nohup ./auto-review.sh >> .auto-review.log 2>&1 &',
                     shell=True, cwd=REPO)
    return {'ok': True, 'msg': 'auto-review 已启动'}


ACTIONS = {
    '/api/save': do_save,
    '/api/new-day': do_new_day,
    '/api/daemon-start': do_daemon_start,
    '/api/scan': lambda _: (wake(), {'ok': True, 'msg': '已通知 auto-review 立即扫描'})[1],
}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == '/api/state':
            return self._json(get_state())
        if self.path in ('/', '/index.html'):
            body = PAGE.read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self._json({'ok': False, 'msg': 'not found'}, 404)

    def do_POST(self):
        action = ACTIONS.get(self.path)
        if not action:
            return self._json({'ok': False, 'msg': 'not found'}, 404)
        length = int(self.headers.get('Content-Length') or 0)
        payload = json.loads(self.rfile.read(length) or b'{}')
        try:
            self._json(action(payload))
        except Exception as e:          # 单人本地工具：报错回给页面即可
            self._json({'ok': False, 'msg': str(e)}, 500)


def main():
    server = ThreadingHTTPServer(('127.0.0.1', PORT), Handler)
    print(f'studio → http://127.0.0.1:{PORT}   (Ctrl-C 退出)')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == '__main__':
    sys.exit(main())
