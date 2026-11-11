#!/usr/bin/env python3
"""fw config components — choose which optional components a project leaves out (T-5080).

Interactive (a terminal): one line per optional component; Up/Down (or j/k) move,
Space toggles included/excluded, Enter saves, q or Esc leaves without saving.
Non-interactive: --list prints the state; --set "termlink node" writes the
excluded set ("" clears it). The result is the ABSENT_COMPONENTS setting that
fw doctor reads (T-4355). The component list is lib/optional_components.py.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from optional_components import COMPONENTS  # noqa: E402  (the one list, T-5080)
KEY = "ABSENT_COMPONENTS"


def components() -> list[tuple[str, str, str]]:
    return list(COMPONENTS)


def _fw() -> str:
    root = os.environ.get("FRAMEWORK_ROOT") or str(HERE.parent)
    return str(Path(root) / "bin" / "fw")


def _yaml() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or ".") / ".framework.yaml"


def current_absent() -> list[str]:
    """The excluded set as fw_config resolves it (env, then .framework.yaml)."""
    r = subprocess.run([_fw(), "config", "get", KEY], capture_output=True, text=True)
    return r.stdout.replace(",", " ").split() if r.returncode == 0 else []


def write_absent(names: list[str]) -> None:
    """Write through `fw config set` (same path as a person typing it); clearing removes the key."""
    if names:
        subprocess.run([_fw(), "config", "set", KEY, " ".join(names)], check=True,
                       stdout=subprocess.DEVNULL)
        return
    y = _yaml()
    if not y.is_file():
        return
    lines = y.read_text(encoding="utf-8").splitlines(keepends=True)
    kept = [ln for ln in lines if not ln.startswith(f"{KEY}:")]
    if kept != lines:
        tmp = y.with_name(y.name + ".tmp")
        tmp.write_text("".join(kept), encoding="utf-8")
        os.chmod(tmp, y.stat().st_mode & 0o7777)
        os.replace(tmp, y)


def validate(names: list[str]) -> list[str]:
    known = {c[0] for c in components()}
    return [n for n in names if n not in known]


def do_list() -> int:
    absent = set(current_absent())
    for name, cmd, desc in components():
        state = "excluded" if name in absent else "included"
        inst = "installed" if shutil.which(cmd) else "missing"
        print(f"  {name:<11} {state:<9} {inst:<10} {desc}")
    return 0


def do_set(value: str) -> int:
    names = value.replace(",", " ").split()
    bad = validate(names)
    if bad:
        known = " ".join(c[0] for c in components())
        print(f"Unknown component(s): {' '.join(bad)}. Known: {known}. Nothing written.", file=sys.stderr)
        return 2
    ordered = [c[0] for c in components() if c[0] in set(names)]
    write_absent(ordered)
    print(f"{KEY} = {' '.join(ordered) or '(empty: every component included)'}")
    return 0


def interactive() -> int:
    import curses

    comps = components()
    excluded = set(current_absent())
    pos = 0

    def draw(scr) -> str:
        nonlocal pos
        curses.curs_set(0)
        while True:
            scr.erase()
            scr.addstr(0, 0, "Optional components — what this project includes")
            scr.addstr(1, 0, "Up/Down move   Space include/exclude   Enter save   q quit without saving")
            for i, (name, cmd, desc) in enumerate(comps):
                mark = "[ ]" if name in excluded else "[x]"
                inst = "" if shutil.which(cmd) else "  (not installed)"
                line = f" {mark} {name:<11} {desc}{inst}"
                attr = curses.A_REVERSE if i == pos else curses.A_NORMAL
                scr.addnstr(3 + i, 0, line, max(1, curses.COLS - 1), attr)
            scr.addstr(4 + len(comps), 0, "[x] included   [ ] excluded on purpose (fw doctor shows OK, not a warning)")
            scr.refresh()
            k = scr.getch()
            if k in (curses.KEY_UP, ord("k")):
                pos = (pos - 1) % len(comps)
            elif k in (curses.KEY_DOWN, ord("j")):
                pos = (pos + 1) % len(comps)
            elif k == ord(" "):
                excluded.symmetric_difference_update({comps[pos][0]})
            elif k in (curses.KEY_ENTER, 10, 13):
                return "save"
            elif k in (ord("q"), 27):
                return "quit"

    result = curses.wrapper(draw)
    if result != "save":
        print("Left without saving; nothing changed.")
        return 0
    return do_set(" ".join(c[0] for c in comps if c[0] in excluded))


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(prog="fw config components",
                                 description="Choose which optional components this project leaves out.")
    ap.add_argument("--list", action="store_true", help="print each component's state and exit")
    ap.add_argument("--set", metavar="NAMES", help='write the excluded set, e.g. "termlink node"; "" clears it')
    a = ap.parse_args(argv)
    if a.list:
        return do_list()
    if a.set is not None:
        return do_set(a.set)
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        print("fw config components needs a terminal for the selection screen.\n"
              "Without one:  fw config components --list\n"
              '              fw config components --set "termlink node"   ("" clears it)',
              file=sys.stderr)
        return 2
    return interactive()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
