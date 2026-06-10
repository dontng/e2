#!/usr/bin/env python3
"""
Stop hook: session 被意外中断时自动创建 wish 接力执行。
触发条件：
  1. token 耗尽（session limit 消息）
  2. 进程被强杀：assistant 正在执行工具调用，JSONL 没有后续的收尾文字
     （正常结束的 session，最后一条必定是 assistant 的文字总结）
"""
import sys, json, re, subprocess
from pathlib import Path
from datetime import datetime

REPO_DIR          = Path(__file__).parent.parent
SPELL_DIR         = REPO_DIR / 'wishes' / 'spell'
PROJECTS_DIR      = Path.home() / '.claude' / 'projects' / '-home-djology-english2-daily'
PROCESSING_LOCK   = REPO_DIR / '.auto-review-processing'

FILE_TOOLS = {'Bash', 'Edit', 'Write'}

def find_session_jsonl(stdin_data):
    if 'transcript_path' in stdin_data:
        p = Path(stdin_data['transcript_path'])
        if p.exists():
            return p
    if 'session_id' in stdin_data:
        p = PROJECTS_DIR / f"{stdin_data['session_id']}.jsonl"
        if p.exists():
            return p
    files = list(PROJECTS_DIR.glob('*.jsonl'))
    return max(files, key=lambda f: f.stat().st_mtime) if files else None

def parse_session(jsonl_path):
    first_prompt     = None
    token_limited    = False
    had_file_ops     = False
    # Track the last thing the assistant did
    last_assistant_had_tool_use  = False
    last_assistant_had_final_text = False

    with open(jsonl_path, encoding='utf-8') as f:
        for line in f:
            try:
                d = json.loads(line.strip())
            except Exception:
                continue

            if d.get('type') == 'user' and first_prompt is None:
                content = d.get('message', {}).get('content', '')
                if isinstance(content, list):
                    for block in content:
                        if isinstance(block, dict) and block.get('type') == 'text':
                            text = block.get('text', '').strip()
                            if text:
                                first_prompt = text
                                break
                elif isinstance(content, str) and content.strip():
                    first_prompt = content.strip()

            if d.get('type') == 'assistant':
                content = d.get('message', {}).get('content', '')
                if not isinstance(content, list):
                    # plain string response — session ended cleanly
                    last_assistant_had_tool_use   = False
                    last_assistant_had_final_text = bool(content.strip())
                    if re.search(r'session.?limit|resets\s+\d', content, re.IGNORECASE):
                        token_limited = True
                    continue

                has_tool_use  = False
                has_text_after_tool = False
                seen_tool_use = False
                last_text_in_turn = ''

                for block in content:
                    if not isinstance(block, dict):
                        continue
                    if block.get('type') == 'tool_use':
                        has_tool_use = True
                        seen_tool_use = True
                        if block.get('name') in FILE_TOOLS:
                            had_file_ops = True
                    if block.get('type') == 'text':
                        text = block.get('text', '').strip()
                        if text:
                            last_text_in_turn = text
                            if seen_tool_use:
                                has_text_after_tool = True

                last_assistant_had_tool_use   = has_tool_use
                # Cleanly finished: either no tool use at all, or had text after tool use
                last_assistant_had_final_text = (not has_tool_use) or has_text_after_tool

                if re.search(r'session.?limit|resets\s+\d', last_text_in_turn, re.IGNORECASE):
                    token_limited = True

    # Interrupted = assistant was mid-tool-call with no subsequent wrap-up text
    interrupted = (
        not token_limited
        and had_file_ops
        and last_assistant_had_tool_use
        and not last_assistant_had_final_text
    )

    return first_prompt, token_limited, interrupted

def prompt_already_pending(spell_file, prompt):
    """Return True if this exact prompt already has a pending/running entry today."""
    if not spell_file.exists():
        return False
    content = spell_file.read_text(encoding='utf-8')
    # Find all pending/running blocks and check their prompts
    for m in re.finditer(r'^--- wish-\S+ \[(?:pending|running)\]\n(.*?)(?=^--- wish-|\Z)',
                         content, re.MULTILINE | re.DOTALL):
        block_prompt = m.group(1).strip()
        if block_prompt.startswith(prompt[:80]):
            return True
    return False

def get_next_wish_id(spell_file):
    if not spell_file.exists():
        return 'wish-01'
    ids = re.findall(r'^--- (wish-\d+)', spell_file.read_text(encoding='utf-8'), re.MULTILINE)
    if not ids:
        return 'wish-01'
    nums = [int(re.search(r'\d+', w).group()) for w in ids]
    return f"wish-{max(nums) + 1:02d}"

def create_wish(prompt, reason):
    today = datetime.now().strftime('%m%d')
    spell_file = SPELL_DIR / f'{today}.md'
    SPELL_DIR.mkdir(parents=True, exist_ok=True)

    if prompt_already_pending(spell_file, prompt):
        return None, spell_file, today

    wish_id = get_next_wish_id(spell_file)
    if not spell_file.exists():
        spell_file.write_text(f'# {today}\n\n', encoding='utf-8')
    content = spell_file.read_text(encoding='utf-8')
    body = f'{prompt}\n\n（接续上次未完成的工作，从当前文件状态继续。）'
    spell_file.write_text(content + f'\n--- {wish_id} [pending]\n{body}\n', encoding='utf-8')
    return wish_id, spell_file, today

def processing_locked():
    if not PROCESSING_LOCK.exists():
        return False
    try:
        pid = int(PROCESSING_LOCK.read_text().strip())
        import os
        os.kill(pid, 0)
        return True
    except (ValueError, OSError):
        return False

def main():
    try:
        raw = sys.stdin.read() or '{}'
        stdin_data = json.loads(raw)
    except Exception:
        stdin_data = {}
        raw = ''

    log = REPO_DIR / '.auto_wish_debug.log'
    with open(log, 'a') as f:
        f.write(f"{datetime.now()} stdin_keys={list(stdin_data.keys())} raw_prefix={raw[:200]}\n")

    jsonl = find_session_jsonl(stdin_data)
    if not jsonl:
        return

    first_prompt, token_limited, interrupted = parse_session(jsonl)

    if not (token_limited or interrupted):
        return
    if not first_prompt:
        return

    reason = 'token limit' if token_limited else 'interrupted'
    wish_id, spell_file, today = create_wish(first_prompt, reason)

    if wish_id is None:
        print(f'[auto_wish] {reason} — duplicate prompt, skipped', file=sys.stderr)
        return

    cwd = str(REPO_DIR)
    subprocess.run(['git', 'add', str(spell_file)], cwd=cwd)
    subprocess.run(['git', 'commit', '-m', f'wish: {today}/{wish_id} [auto: {reason}]'], cwd=cwd)

    if processing_locked():
        print('[auto_wish] processing lock held — skipping push', file=sys.stderr)
        return

    subprocess.run(['git', 'push'], cwd=cwd)
    print(f'[auto_wish] {reason} → {today}/{wish_id} created', file=sys.stderr)

if __name__ == '__main__':
    main()
