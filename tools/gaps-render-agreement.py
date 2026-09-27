#!/usr/bin/env python3
"""T-3140: assert `fw gaps` renders exactly the non-terminal half of the register.

Two independently-implemented scans, compared. This file re-derives the
outstanding set straight from the YAML with no shared code path into
`lib.gaps`, then checks it against the ids `fw gaps` actually printed. The
assertion is AGREEMENT, never a count — the register is edited continuously, so
a control that pins a number is a report about the corpus rather than a check on
the code, and goes stale the first time somebody closes a gap.

Why this exists as a standing check rather than a one-off measurement: the
defect it guards is silent by construction. `fw gaps` used to enumerate an
allowlist of statuses, so an entry in any status outside that list was not
rendered, not counted and not summarised — indistinguishable, on the surface,
from an entry that did not exist. 12 unresolved gaps were hidden that way, 6 of
them severity `high`, and nothing anywhere disagreed with anything.

Usage:
    tools/gaps-render-agreement.py [--json]

Exit 0 on agreement, 1 on disagreement, 2 if the register cannot be read.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

# Deliberately duplicated from lib.gaps.TERMINAL_GAP_STATUSES rather than
# imported. Importing would make both sides of the comparison the same side:
# a bug in the constant would move the render and the reference together and
# this check would stay green through it. Consolidation buys consistency and
# spends the cross-check (L-575); here the cross-check is the point.
TERMINAL = {"closed", "resolved", "decided-build", "decided-simplify"}

_ANSI = re.compile(r"\x1b\[[0-9;]*m")


def _register_path(root: Path) -> Path:
    p = root / ".context" / "project" / "concerns.yaml"
    return p if p.exists() else root / ".context" / "project" / "gaps.yaml"


def main() -> int:
    import yaml

    root = Path(os.environ.get("PROJECT_ROOT") or ".").resolve()
    path = _register_path(root)
    if not path.exists():
        print(f"no gap register at {path}", file=sys.stderr)
        return 2
    data = yaml.safe_load(path.read_text()) or {}
    entries = [
        e
        for e in (data.get("concerns") or data.get("gaps") or [])
        if isinstance(e, dict)
    ]

    def outstanding(e: dict) -> bool:
        s = e.get("status")
        return not isinstance(s, str) or s.strip().lower() not in TERMINAL

    want = {e.get("id") for e in entries if outstanding(e) and e.get("id")}
    all_ids = {e.get("id") for e in entries if e.get("id")}

    proc = subprocess.run(
        [str(root / "bin" / "fw"), "gaps"],
        capture_output=True, text=True, cwd=str(root),
    )
    # ANSI must go before the id match: ids are printed wrapped in colour codes,
    # so a word-boundary anchor sees `mG-020` and matches nothing. That cost a
    # measurement round on the very run that produced this file.
    text = _ANSI.sub("", proc.stdout)
    got = {
        i for i in all_ids
        if re.search(r"(?<![\w-])" + re.escape(i) + r"(?![\w-])", text)
    }

    missing, extra = sorted(want - got), sorted(got - want)
    ok = not missing and not extra
    if "--json" in sys.argv:
        print(json.dumps({
            "verdict": "READY" if ok else "NOT_READY",
            "register_total": len(entries),
            "outstanding_expected": len(want),
            "rendered": len(got),
            "missing_from_render": missing,
            "rendered_but_terminal": extra,
        }, indent=2))
    else:
        print(f"register {len(entries)} | outstanding {len(want)} | rendered {len(got)}")
        if missing:
            print(f"  MISSING from fw gaps output: {', '.join(missing)}")
        if extra:
            print(f"  rendered but terminal: {', '.join(extra)}")
        if ok:
            print("  agreement: exact")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
