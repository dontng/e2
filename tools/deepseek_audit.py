#!/usr/bin/env python3
import argparse
import os
import pathlib
import shlex
import shutil
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


def repo_path(path: pathlib.Path) -> str:
    return str(path.resolve().relative_to(ROOT))


def derive_output_path(target: pathlib.Path) -> pathlib.Path:
    stem = target.stem
    if "drill" in stem:
        stem = stem.replace("drill", "audit", 1)
    elif "review" in stem:
        stem = stem.replace("review", "audit", 1)
    else:
        stem = f"{stem}-audit"
    return target.with_name(f"{stem}{target.suffix or '.md'}")


def drill_files() -> list[pathlib.Path]:
    return sorted((ROOT / "t1").glob("**/*-drill.md"), key=lambda p: p.stat().st_mtime, reverse=True)


def audit_is_current(target: pathlib.Path, output: pathlib.Path) -> bool:
    return output.exists() and output.stat().st_mtime >= target.stat().st_mtime


def latest_pending_drill() -> pathlib.Path | None:
    files = drill_files()
    for path in files:
        if not audit_is_current(path, derive_output_path(path)):
            return path
    return None


def latest_drill() -> pathlib.Path | None:
    files = drill_files()
    return files[0] if files else None


def resolve_target(value: str | None) -> pathlib.Path:
    if not value:
        pending = latest_pending_drill()
        if pending:
            return pending.resolve()
        latest = latest_drill()
        if latest:
            output = derive_output_path(latest)
            raise SystemExit(
                "No drill needs audit. "
                f"Latest drill is already covered: {repo_path(latest)} -> {repo_path(output)}"
            )
        raise SystemExit("No drill files found under t1/.")

    raw = pathlib.Path(value)
    if raw.is_absolute() or raw.exists() or "/" in value:
        target = raw if raw.is_absolute() else ROOT / raw
        return target.resolve()

    matches = [path for path in drill_files() if value in path.name or value in repo_path(path)]
    if not matches:
        raise SystemExit(
            f"No matching drill found for '{value}'. "
            "Use a date like 0709, a day number like day75, or a file path."
        )
    if len(matches) > 1:
        options = "\n".join(f"- {repo_path(path)}" for path in matches)
        raise SystemExit(f"Multiple drills match '{value}':\n{options}")
    return matches[0].resolve()


def read_optional(path: pathlib.Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def build_prompt(target: pathlib.Path, target_text: str, protocol_text: str) -> str:
    rel_target = target.resolve().relative_to(ROOT)
    return f"""你是 DeepSeek，作为独立外部审核模型进入。

这次调用只做一件事：读取指定文件，独立发掘其中的问题、偏差、遗漏和可能的改进方向，并把你的判断写成 Markdown。

重要边界：
- Codex/GPT 只是把文件交给你并负责落盘，不能干涉你的输出结构、判断角度或结论。
- 不需要遵守固定模板，不需要按 Codex/GPT 的分类方式说话。
- 你可以自由发掘问题：目标偏移、归因偏差、训练设计缺陷、遗漏的深层问题、上下文误用、用户成本转嫁，或任何你认为重要但提示词没有点名的问题。
- 不需要为了礼貌而通过；如果目标文件本身思路有问题，请直接指出。
- 不要替 Codex 重写全文，除非你认为少量示例能帮助说明问题。

如果下面有参考背景，它只用于帮助你理解仓库目标，不构成输出格式约束：

```md
{protocol_text}
```

现在请审核这个文件：`{rel_target}`

```md
{target_text}
```
"""


def cc_command() -> list[str]:
    configured = os.environ.get("AUDIT_CC_CMD")
    if configured:
        return shlex.split(configured)
    if shutil.which("claude"):
        return ["claude", "-p"]
    raise SystemExit(
        "No Claude Code command found. Set AUDIT_CC_CMD to the command that sends stdin to "
        "your Claude Code + DeepSeek setup, for example: "
        "AUDIT_CC_CMD='claude -p' ./audit.sh 0709"
    )


def call_cc(prompt: str) -> str:
    cmd = cc_command()
    try:
        result = subprocess.run(
            cmd,
            input=prompt,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=ROOT,
            check=False,
        )
    except FileNotFoundError as exc:
        raise SystemExit(f"Audit command not found: {cmd[0]}") from exc

    if result.returncode != 0:
        raise SystemExit(
            f"Audit command failed with exit code {result.returncode}:\n{result.stderr.strip()}"
        )

    output = result.stdout.strip()
    if not output:
        raise SystemExit("Audit command returned empty output.")
    return output + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Ask DeepSeek to read a drill/file and write its independent Markdown audit."
    )
    parser.add_argument(
        "target",
        nargs="?",
        help="Input file, date shorthand like 0709, or day shorthand like day75. Defaults to latest drill needing audit.",
    )
    parser.add_argument(
        "output_positional",
        nargs="?",
        help="Output Markdown file. Defaults to replacing drill with audit, or appending -audit.",
    )
    parser.add_argument("-o", "--output", help="Output Markdown file. Overrides the optional positional output.")
    parser.add_argument("--dry-run", action="store_true", help="Print the output path without calling DeepSeek.")
    parser.add_argument("--force", action="store_true", help="Run even when the audit file is newer than the target.")
    parser.add_argument("--print-prompt", action="store_true", help="Print the prompt that would be sent to CC.")
    args = parser.parse_args()

    target = resolve_target(args.target)

    if not target.exists():
        raise SystemExit(f"Target file does not exist: {target}")
    if ROOT not in target.parents and target != ROOT:
        raise SystemExit(f"Target file must be inside repo: {target}")

    output_arg = args.output or args.output_positional
    output = pathlib.Path(output_arg) if output_arg else derive_output_path(target)
    if not output.is_absolute():
        output = ROOT / output
    output = output.resolve()

    if ROOT not in output.parents:
        raise SystemExit(f"Output file must be inside repo: {output}")

    if audit_is_current(target, output) and not args.force:
        print(f"Audit already current: {repo_path(target)} -> {repo_path(output)}")
        print("Use --force to run DeepSeek again.")
        return 0

    if args.dry_run:
        print(f"{repo_path(target)} -> {repo_path(output)}")
        return 0

    protocol = read_optional(ROOT / "docs" / "t1-self-convergence-analysis.md")
    target_text = target.read_text(encoding="utf-8")
    prompt = build_prompt(target, target_text, protocol)
    if args.print_prompt:
        print(prompt)
        return 0

    audit = call_cc(prompt)

    output.write_text(audit, encoding="utf-8")
    print(f"Wrote {repo_path(output)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
