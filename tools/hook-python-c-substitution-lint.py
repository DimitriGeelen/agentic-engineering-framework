#!/usr/bin/env python3
"""T-4782: no backtick or $( inside double-quoted `python3 -c "..."` blocks in hooks.

Inside `python3 -c "..."` bash performs command substitution on the python
SOURCE before python starts. A backtick or `$(` there runs as a shell command,
even when it sits inside a python `#` comment, on every call of the script.
In a hook that is every tool call of every session.

Origin (055 T-641, 2026-10-26): a local edit to the vendored
agents/context/check-tier0.sh added a python comment that named a tmux command
in markdown-style backticks. Every Bash tool call then ran it, and the host's
tmux servers went down repeatedly for six hours.

Sibling: tests/lint/no-backticks-in-inline-python.bats (T-2707) flags backticks
in the same blocks tree-wide but deliberately allows `$(`. Hook scripts get the
stricter rule here: a hook's python takes shell values through the environment
or argv, so `$(` has no business in it. Escaped `\\$(` and `\\``, and plain
`$VAR` / `${VAR}` expansion, stay allowed. The fix for a hit is a quoted
heredoc (`python3 - ARGS <<'PY'`) or a lib/*.py module, not an escape.

Scope (default, relative to --root): agents/context/*.sh, agents/context/lib/*.sh,
lib/hook-dispatch.sh, lib/hook-telemetry.sh, and every script that
.claude/settings.json names directly. `fw hook NAME` dispatches to
agents/context/NAME.sh (lib/hook-dispatch.sh), which the first glob covers.

Usage:
    tools/hook-python-c-substitution-lint.py [--root DIR] [FILE ...]

Exit 0 when clean, 1 on a hit (file:line: kind: snippet), 2 on bad usage.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Iterator, List, Tuple

# `python3 -c "`, also `python -c`, `python3 -I -c`, `"$PYTHON" -c`.
_OPEN = re.compile(r'(?:\bpython3?(?:\.\d+)?|\$\{?PYTHON[A-Z_]*\}?"?)(?:\s+-[A-Za-z]+)*\s+-c\s+"')
_SUBST = re.compile(r"`|\$\(")
_SETTINGS_SCRIPT = re.compile(r"\$\{?CLAUDE_PROJECT_DIR\}?/(\S+\.sh)\b")

DEFAULT_GLOBS = ("agents/context/*.sh", "agents/context/lib/*.sh")
DEFAULT_FILES = ("lib/hook-dispatch.sh", "lib/hook-telemetry.sh")


def hook_files(root: Path) -> List[Path]:
    files = set()
    for pat in DEFAULT_GLOBS:
        files.update(p for p in root.glob(pat) if p.is_file())
    for rel in DEFAULT_FILES:
        if (root / rel).is_file():
            files.add(root / rel)
    settings = root / ".claude" / "settings.json"
    try:
        data = json.loads(settings.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        data = {}
    for groups in (data.get("hooks") or {}).values():
        for group in groups or []:
            for hook in group.get("hooks", []) or []:
                for rel in _SETTINGS_SCRIPT.findall(hook.get("command", "") or ""):
                    if (root / rel).is_file():
                        files.add(root / rel)
    return sorted(files)


def blocks(src: str) -> Iterator[Tuple[int, int]]:
    """Yield (start, end) of each double-quoted python -c body.

    Inside the bash string a bare `"` would end it, so the first unescaped `"`
    after the opening is the terminator (same invariant as T-2707's scanner).
    """
    pos = 0
    while True:
        m = _OPEN.search(src, pos)
        if not m:
            return
        i = m.end()
        while i < len(src):
            if src[i] == "\\":
                i += 2
                continue
            if src[i] == '"':
                break
            i += 1
        yield m.end(), i
        pos = i + 1


def scan(path: Path) -> List[str]:
    try:
        src = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    lines = src.splitlines()
    hits = []
    for start, end in blocks(src):
        # Backslash-escaped pairs are literal in a double-quoted bash string;
        # blank them out, keeping length so line numbers stay right.
        body = re.sub(r"\\(.)", "\x00\x00", src[start:end], flags=re.S)
        for m in _SUBST.finditer(body):
            ln = src.count("\n", 0, start + m.start()) + 1
            kind = "backtick" if m.group(0) == "`" else "$("
            hits.append(f"{path}:{ln}: {kind}: {lines[ln - 1].strip()[:120]}")
    return hits


def main(argv: List[str]) -> int:
    root = Path(".")
    files: List[Path] = []
    args = iter(argv)
    for a in args:
        if a == "--root":
            try:
                root = Path(next(args))
            except StopIteration:
                print("--root needs a directory", file=sys.stderr)
                return 2
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            files.append(Path(a))
    if not files:
        files = hook_files(root)
    hits = [h for f in files for h in scan(f)]
    if hits:
        print("command substitution inside a double-quoted python -c block in a hook script:")
        for h in hits:
            print(f"  {h}")
        print("bash runs these on every call, before python starts (comments included).")
        print("Fix: move the block to a quoted heredoc (python3 - ARGS <<'PY') or a lib/*.py module.")
        return 1
    print(f"clean: {len(files)} hook script(s), no command substitution in python -c blocks")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
