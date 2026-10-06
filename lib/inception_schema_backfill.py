#!/usr/bin/env python3
"""T-3948: add the T-2188 inception schema fields to inceptions that lack them.

T-2188 (2026-06-03) made `target_blast_radius` and `voi_score` mandatory on every inception
and installed a PreToolUse gate that refuses edits to an inception without them. T-2193
backfilled AEF's OWN 378 inceptions the same day, but `fw upgrade` never did the same for a
consumer: an upgraded project kept its older inceptions without the fields, and the first
agent edit to one was refused. This is that backfill, as a reusable step.

The values are the inception template's defaults (3 and 0.5) — placeholders the BVP
estimator and the operator refine later, exactly as a freshly created inception starts.

Usage:
  inception_schema_backfill.py [--dry-run] <tasks-dir | task-file>...
Prints one line per file it changes (or would change) and a final count. Exit 0.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

DEFAULTS = (("target_blast_radius", "3"), ("voi_score", "0.5"))
_FM = re.compile(r"\A---\n(.*?\n)---\n", re.S)
_TYPE = re.compile(r"^workflow_type:\s*inception\s*(#.*)?$", re.M)


def missing(text: str) -> list[str]:
    """The schema keys this inception lacks; [] for a non-inception or a complete one."""
    m = _FM.match(text)
    if not m or not _TYPE.search(m.group(1)):
        return []
    return [k for k, _ in DEFAULTS if not re.search(rf"^{k}:\s*\S", m.group(1), re.M)]


def backfill_text(text: str) -> str:
    """`text` with the missing keys inserted right after `workflow_type: inception`."""
    need = missing(text)
    if not need:
        return text
    m = _FM.match(text)
    assert m is not None                       # missing() returned keys, so it matched
    fm = m.group(1)
    # Drop empty `key:` lines first so the inserted value is the only one.
    for k in need:
        fm = re.sub(rf"^{k}:\s*$\n?", "", fm, flags=re.M)
    tl = _TYPE.search(fm)
    assert tl is not None
    add = "".join(f"{k}: {v}\n" for k, v in DEFAULTS if k in need)
    fm = fm[:tl.end() + 1] + add + fm[tl.end() + 1:]
    return "---\n" + fm + "---\n" + text[m.end():]


def _files(args: list[str]) -> list[Path]:
    out: list[Path] = []
    for a in args:
        p = Path(a)
        if p.is_dir():
            for sub in ("active", "completed"):
                out += sorted((p / sub).glob("T-*.md"))
        elif p.is_file():
            out.append(p)
    return out


def main(argv: list[str]) -> int:
    dry = "--dry-run" in argv
    args = [a for a in argv if a != "--dry-run"]
    n = 0
    for f in _files(args):
        try:
            text = f.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        need = missing(text)
        if not need:
            continue
        n += 1
        print(f"{'WOULD BACKFILL' if dry else 'BACKFILLED'} {f}: {', '.join(need)}")
        if not dry:
            f.write_text(backfill_text(text), encoding="utf-8")
    print(f"inception schema backfill: {n} file(s) {'would change' if dry else 'changed'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
