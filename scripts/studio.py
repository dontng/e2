#!/usr/bin/env python3
"""studio.py — 本地交互台：在浏览器里完成 写译 → 批改 → 重译 的全部日常。

usage:  studio.py [repo_dir] [port]        （由根目录 studio.sh 启动）

仅标准库，只绑定 127.0.0.1。界面在 scripts/studio.html。

双模式（自动判断，零配置）：
  本地模式 — 本机跑着 auto-review（Dell）：保存写回 markdown 并 touch
            唤醒文件，daemon ≤15s 接手。
  远程模式 — 本机没有 daemon（公司笔记本）：保存后自动 commit + push 到
            GitHub，Dell 在下个轮询 pull 到后处理；页面每 60s 自动 pull，
            批改结果推回来后自动显示。
"""
import sys
import os
import re
import json
import time
import datetime
import threading
import subprocess
from pathlib import Path
from urllib.parse import urlparse, parse_qs
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

SCRIPTS = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS))
import review
import scores as scores_mod

REPO = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else SCRIPTS.parent
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8787
WAKE = REPO / '.auto-review-wake'
PAGE = SCRIPTS / 'studio.html'
THEME = REPO / 'data' / 'theme'     # 'dark' / 'light'；每机本地，不入 git。两页共享


def read_theme() -> str:
    """返回 'dark' / 'light'；未设置返回 'auto'（前端跟随系统）。"""
    try:
        v = THEME.read_text(encoding='utf-8').strip()
        return v if v in ('dark', 'light') else 'auto'
    except OSError:
        return 'auto'


def write_theme(v: str):
    if v not in ('dark', 'light'):
        return
    THEME.parent.mkdir(parents=True, exist_ok=True)
    THEME.write_text(v, encoding='utf-8')
PULL_INTERVAL = 60          # 远程模式下自动 pull 的最小间隔（秒）

_git_lock = threading.Lock()
_last_pull = 0.0

_daemon_ts = 0.0
_daemon_val = False
_DAEMON_TTL = 30.0         # 30 秒内复用上次的 /proc 扫描结果

_src_cache_key: float = -1.0
_src_cache_data: dict = {}

_live_state: dict = {}
_live_lock = threading.Lock()

_exam_date_val = None


def exam_date() -> datetime.date:
    """EXAM_DATE 的唯一定义在 console.sh，这里读取而不复制。"""
    global _exam_date_val
    if _exam_date_val is None:
        m = re.search(r'EXAM_DATE="(\d{4}-\d{2}-\d{2})"', (SCRIPTS / 'console.sh').read_text())
        _exam_date_val = datetime.date.fromisoformat(m.group(1))
    return _exam_date_val


def git(*args, timeout=40):
    return subprocess.run(['git', *args], cwd=REPO,
                          capture_output=True, text=True, timeout=timeout)


def github_base() -> str:
    m = re.search(r'github\.com[:/](.+?)(?:\.git)?$',
                  git('config', 'remote.origin.url').stdout.strip())
    return f'https://github.com/{m.group(1)}/blob/main/' if m else ''


GH = github_base()


def proc_alive(needle: str) -> bool:
    """非 Linux（无 /proc）一律返回 False → 自然落入远程模式。"""
    me = str(os.getpid())
    for p in Path('/proc').glob('[0-9]*'):
        if p.name == me:
            continue
        try:
            if 'bash' not in (p / 'comm').read_text(errors='ignore'):
                continue
            cmd = (p / 'cmdline').read_bytes().decode(errors='ignore').replace('\x00', ' ')
        except OSError:
            continue
        if needle in cmd:
            return True
    return False


def local_daemon() -> bool:
    global _daemon_ts, _daemon_val
    if time.time() - _daemon_ts < _DAEMON_TTL:
        return _daemon_val
    _daemon_val = proc_alive('auto-review.sh')
    _daemon_ts = time.time()
    return _daemon_val


def _src_mtime_key() -> float:
    """src/ 下所有 .md 文件的最大 mtime；文件增删或修改后自动失效。"""
    return max((f.stat().st_mtime for f in REPO.glob('src/*/*.md')), default=0.0)


def _load_src_data() -> dict:
    """缓存 scores + stems；只在文件变化时重新扫描。"""
    global _src_cache_key, _src_cache_data
    key = _src_mtime_key()
    if key == _src_cache_key:
        return _src_cache_data
    sc = scores_mod.collect(REPO)
    stems = [f"{e['mmdd']}-day{day}" for day, e in sorted(sc['entries'].items())]
    _src_cache_data = {'scores': sc, 'stems': stems}
    _src_cache_key = key
    return _src_cache_data


# ── git 同步（仅远程模式使用） ────────────────────────────────────────────────

def pull(force=False) -> str:
    """限频 pull；返回错误信息（成功为空串）。"""
    global _last_pull
    with _git_lock:
        if not force and time.time() - _last_pull < PULL_INTERVAL:
            return ''
        _last_pull = time.time()
        r = git('pull', '--rebase', '--autostash', 'origin', 'main')
        if r.returncode != 0:
            tail = (r.stderr or r.stdout).strip().splitlines()
            return tail[-1] if tail else 'pull 失败'
        return ''


def commit_push(paths: list, msg: str) -> dict:
    with _git_lock:
        git('add', *paths)
        if git('diff', '--cached', '--quiet').returncode == 0:
            return {'ok': True, 'msg': '没有需要同步的变化'}
        r = git('commit', '-m', msg)
        if r.returncode != 0:
            return {'ok': False, 'msg': 'commit 失败：' + r.stderr.strip()[-120:]}
        git('pull', '--rebase', '--autostash', 'origin', 'main')
        r = git('push', 'origin', 'main')
        if r.returncode != 0:
            tail = r.stderr.strip().splitlines()
            return {'ok': False,
                    'msg': 'push 失败（已存在本地，可稍后同步）：' + (tail[-1] if tail else '')}
        return {'ok': True, 'msg': '已推送 GitHub，Dell 将在下个轮询接手'}


# ── 状态 ──────────────────────────────────────────────────────────────────────

def find_day_file(mmdd: str):
    hits = sorted(REPO.glob(f'src/*/{mmdd}-day*.md'))
    return hits[0] if hits else None


def heatmap_cells(entries: dict, today: datetime.date) -> dict:
    """把每条 entry 的 mmdd 还原成真实日期 → {iso: score}。
    年份按「今年；若月日晚于今天则归去年」推断，对应最近一年的日历窗口。
    已练但未批改记 0.0，前端渲染成最浅一档（看得出坚持，区别于深浅分档）。"""
    cells = {}
    for e in entries.values():
        mmdd = e['mmdd']
        try:
            dt = datetime.date(today.year, int(mmdd[:2]), int(mmdd[2:]))
        except ValueError:
            continue
        if dt > today:
            try:
                dt = dt.replace(year=today.year - 1)
            except ValueError:
                continue
        cells[dt.isoformat()] = float(e['score']) if e['score'] else 0.0
    return cells


def read_doc(kind: str, stem: str = '') -> str:
    """读取某天的 fool / probe markdown 正文。stem 为空则取今天；文件不在返回空串。
    stem 形如 '0616-day56'。"""
    if kind not in ('fool', 'probe'):
        return ''
    if stem:
        doc = next(REPO.glob(f'{kind}/*/{stem}-{kind}.md'), None)
    else:
        f = find_day_file(datetime.date.today().strftime('%m%d'))
        doc = (REPO / kind / f.parent.name / f'{f.name[:-3]}-{kind}.md') if f else None
    if not doc or not doc.exists():
        return ''
    # 剥掉顶部导航行（« 上一篇 / 下一篇 »）和 source 行，右栏只看正文
    lines = doc.read_text(encoding='utf-8').splitlines()
    body = [l for l in lines
            if not l.startswith('«') and not l.startswith('source:')]
    return '\n'.join(body).strip()


def all_day_stems() -> list:
    """所有 src 天文件的 stem（形如 '0616-day56'），按文件名排序≈时间顺序。"""
    return _load_src_data()['stems']


def day_nav(stem: str, stems: list = None) -> tuple:
    """在所有天文件中给出 (前一天, 后一天) 的 stem；越界为 ''。"""
    stems = stems if stems is not None else all_day_stems()
    if stem not in stems:
        return '', ''
    i = stems.index(stem)
    return (stems[i - 1] if i > 0 else '', stems[i + 1] if i < len(stems) - 1 else '')


def day_card(f: Path, text: str = None) -> dict:
    """单个天文件 → 卡片数据（原句/翻译/批改/评分 + fool/probe 是否存在 + 复习块）。
    get_state 的今日卡与 day_view 的历史卡共用，避免两处重复。"""
    if text is None:
        text = f.read_text(encoding='utf-8')
    rel = str(f.relative_to(REPO))
    stem = f.name[:-3]
    fool_rel = f'fool/{f.parent.name}/{stem}-fool.md'
    probe_rel = f'probe/{f.parent.name}/{stem}-probe.md'
    return {
        'exists': True,
        'stem': stem,
        'mmdd': stem[:4],
        'day': int(re.search(r'-day(\d+)$', stem).group(1)),
        'rel': rel,
        'gh': GH + rel if GH else '',
        'has_fool': (REPO / fool_rel).exists(),
        'has_probe': (REPO / probe_rel).exists(),
        'sentence': review.section(text, '原句'),
        'translation': review.section(text, '我的理解和翻译'),
        'correction': review.section(text, '批改'),
        'score': review.section(text, '评分'),
    }


def day_view(stem: str) -> dict:
    """供右栏翻阅任意一天：完整卡片 + 复习块 + 前后导航。只读。"""
    f = next((p for p in sorted(REPO.glob('src/*/*-day*.md')) if p.name[:-3] == stem), None)
    if not f:
        return {'exists': False}
    d = day_card(f)
    d['is_today'] = d['mmdd'] == datetime.date.today().strftime('%m%d')
    d['redo_blocks'] = review.parse_blocks(f.read_text(encoding='utf-8'))
    d['prev'], d['next'] = day_nav(stem)
    return d


def get_state() -> dict:
    mode = 'local' if local_daemon() else 'remote'
    pull_err = pull() if mode == 'remote' else ''

    today = datetime.date.today()
    mmdd = today.strftime('%m%d')
    f = find_day_file(mmdd)

    src = _load_src_data()
    entries, redos = src['scores']['entries'], src['scores']['redos']
    stems = src['stems']
    next_day = max(entries, default=0) + 1

    t = {'exists': False, 'mmdd': mmdd, 'next_day': next_day}
    blocks = []
    if f:
        text = f.read_text(encoding='utf-8')
        t = day_card(f, text)
        t['next_day'] = next_day
        t['prev'], t['next'] = day_nav(t['stem'], stems)
        blocks = review.parse_blocks(text)
    else:
        # 今天还没建文件：左箭头退回到现存最新一天，仍可翻阅历史
        t['prev'] = stems[-1] if stems else ''
        t['next'] = ''

    rows = []
    for day in sorted(entries, reverse=True)[:10]:
        e = entries[day]
        rows.append({'day': day, 'date': f"{e['mmdd'][:2]}/{e['mmdd'][2:]}",
                     'first': e['score'],
                     'redos': [{'score': s, 'trend': tr, 'date': f'{m[:2]}/{m[2:]}'}
                               for m, s, tr in redos.get(day, [])]})

    log_tail = []
    log_file = REPO / '.auto-review.log'
    if mode == 'local' and log_file.exists():
        log_tail = log_file.read_text(encoding='utf-8', errors='ignore').splitlines()[-5:]

    return {
        'mode': mode,
        'theme': read_theme(),
        'pull_err': pull_err,
        'days_left': (exam_date() - today).days,
        'today': t,
        'redo_blocks': blocks,
        'today_iso': today.isoformat(),
        'heatmap': heatmap_cells(entries, today),
        'rows': rows,
        'total': len(entries),
        'daemon': {'auto_review': mode == 'local'},
        'log_tail': log_tail,
    }


# ── 动作 ──────────────────────────────────────────────────────────────────────

def do_save(payload: dict) -> dict:
    stem = payload.get('stem')
    kind, content = payload.get('kind'), payload.get('content', '')
    if stem and kind == 'redo':
        hits = sorted(REPO.glob(f'src/*/{stem}.md'))
        f = hits[0] if hits else None
        if not f:
            return {'ok': False, 'msg': f'找不到 {stem}'}
    else:
        f = find_day_file(datetime.date.today().strftime('%m%d'))
        if not f:
            return {'ok': False, 'msg': '今天的文件还不存在'}
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

    if not ok:
        return {'ok': False, 'msg': '写入失败'}

    if local_daemon():
        WAKE.touch()
        return {'ok': True, 'msg': '已保存，批改将在片刻后出现'}
    day = payload.get('day') or f.name
    return commit_push([str(f.relative_to(REPO))], f'studio: {kind} · {day}')


def do_new_day(payload: dict) -> dict:
    arg = ['tomorrow'] if payload.get('when') == 'tomorrow' else []
    r = subprocess.run(['bash', 'new-day.sh', *arg], cwd=REPO,
                       capture_output=True, text=True)
    if r.returncode != 0:
        return {'ok': False, 'msg': (r.stdout + r.stderr).strip()[-160:]}
    if not local_daemon():
        return commit_push(['src/', 'fool/'], 'studio: new day')
    return {'ok': True, 'msg': (r.stdout).strip()[-160:]}


def do_sync(_: dict) -> dict:
    """远程模式手动同步：先把本地未推的整理出去，再强制 pull。"""
    res = commit_push(['src/'], 'studio: sync')
    err = pull(force=True)
    if err:
        return {'ok': False, 'msg': f'pull 失败：{err}'}
    return {'ok': True, 'msg': res['msg'] if res['msg'] != '没有需要同步的变化' else '已同步'}


def do_scan(_: dict) -> dict:
    WAKE.touch()
    return {'ok': True, 'msg': '已通知 auto-review 立即扫描'}


def do_daemon_start(_: dict) -> dict:
    if local_daemon():
        return {'ok': True, 'msg': 'auto-review 已在运行'}
    subprocess.Popen('nohup ./auto-review.sh >> .auto-review.log 2>&1 &',
                     shell=True, cwd=REPO)
    return {'ok': True, 'msg': 'auto-review 已启动'}


def do_theme(payload: dict) -> dict:
    write_theme(payload.get('theme', ''))
    return {'ok': True, 'theme': read_theme()}


ACTIONS = {
    '/api/save': do_save,
    '/api/new-day': do_new_day,
    '/api/scan': do_scan,
    '/api/sync': do_sync,
    '/api/daemon-start': do_daemon_start,
    '/api/theme': do_theme,
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
        u = urlparse(self.path)
        q = parse_qs(u.query)
        if u.path == '/api/state':
            with _live_lock:
                s = _live_state
            return self._json(s or get_state())
        if u.path == '/api/day':
            return self._json(day_view(q.get('d', [''])[0]))
        if u.path in ('/api/fool', '/api/probe'):
            return self._json({'md': read_doc(u.path.rsplit('/', 1)[1], q.get('d', [''])[0])})
        if u.path in ('/', '/index.html'):
            page = PAGE.read_text(encoding='utf-8')
            with _live_lock:
                s = _live_state
            if s:
                state_json = json.dumps(s, ensure_ascii=False).replace('</', '<\\/')
                inject = f'<script>window.__INITIAL_STATE__={state_json};</script>\n'
                body = (page.replace('</body>', inject + '</body>')).encode('utf-8')
            else:
                body = page.encode('utf-8')
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


def _bg_state_worker():
    """后台每 3 秒刷新 _live_state，请求路径只做内存读取。"""
    global _live_state
    while True:
        try:
            s = get_state()
            with _live_lock:
                _live_state = s
        except Exception:
            pass
        time.sleep(3)


def main():
    threading.Thread(target=_bg_state_worker, daemon=True).start()
    server = ThreadingHTTPServer(('127.0.0.1', PORT), Handler)
    mode = '本地模式（daemon 在本机）' if local_daemon() else '远程模式（经 GitHub 同步）'
    print(f'studio → http://127.0.0.1:{PORT}   {mode}   (Ctrl-C 退出)')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == '__main__':
    sys.exit(main())
