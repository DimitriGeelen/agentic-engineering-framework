#!/usr/bin/env python3
"""T-3582 live proof: real review dispatches of the harness worker kinds on a FIXTURE task.

    python3 tests/manual/t3582_live_review.py panel        # rung 5: claude + codex + opencode
    python3 tests/manual/t3582_live_review.py single KIND  # rung 1: one seat of KIND

Builds a throwaway fixture project under /tmp/t3582-live/<stamp> (a consumer-shaped repo whose
.agentic-framework points at this framework, so the dispatcher, ledger and registry are this
framework's COMMITTED ones), files a fixture task with one reviewer-judged Human criterion, and
runs `fw reviewer judge`'s own code path (judge_cli.judge with the real `fw termlink dispatch`).
Nothing in this repository is judged, ticked or written; the fixture keeps the ledger rows.
Prints one JSON summary: per seat the dispatch id, kind, vendor, wall time, signed completion,
recorded row and the outcome the ledger validated. Costs are logged by the caller with
`bin/fw review cost log --task T-3582 ...` (all internal-class backends).
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

FW = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW))

TID = "T-9582"
CRIT = ("- [ ] [REVIEW] The module docstring of `calc.py` reads clearly to a new contributor\n"
        "  **Steps:**\n  1. Read `calc.py`\n  **Expected:** the docstring says what `add` does, "
        "in plain words, and matches the code\n  **If not:** say what is unclear\n")


def _git(root: Path, *args: str, ident: str = "Builder Bot") -> None:
    mail = ident.lower().replace(" ", ".") + "@x.y"
    env = {**os.environ, "GIT_AUTHOR_NAME": ident, "GIT_AUTHOR_EMAIL": mail,
           "GIT_COMMITTER_NAME": ident, "GIT_COMMITTER_EMAIL": mail}
    subprocess.run(["git", "-c", "core.hooksPath=/dev/null", *args], cwd=root, check=True,
                   capture_output=True, env=env)


def fixture(high_impact: bool) -> Path:
    root = Path("/tmp/t3582-live") / time.strftime("%Y%m%dT%H%M%S")
    root.mkdir(parents=True)
    _git(root, "init", "-q")
    (root / ".agentic-framework").symlink_to(FW)
    (root / "bin").mkdir()
    shim = root / "bin" / "fw"
    shim.write_text(f'#!/bin/bash\n[ "$1 $2" = "reviewer verdict" ] && shift 2 && '
                    f'exec python3 {FW}/lib/verdict_ledger.py "$@"\nexec {FW}/bin/fw "$@"\n')
    shim.chmod(0o755)
    (root / "calc.py").write_text('"""Tiny calculator: `add(a, b)` returns the sum of two numbers."""\n\n\n'
                                  "def add(a, b):\n    return a + b\n")
    d = root / ".tasks" / "active"
    d.mkdir(parents=True)
    fm = "cost_estimate:\n  blast_radius: 9\n" if high_impact else ""
    (d / f"{TID}-fixture.md").write_text(
        f"---\nid: {TID}\nname: \"t3582 live fixture\"\nstatus: started-work\nworkflow_type: build\n"
        f"owner: human\nhorizon: now\ncreated: 2026-10-01T00:00:00Z\nlast_update: 2026-10-01T00:00:00Z\n"
        f"{fm}---\n\n## Acceptance Criteria\n\n### Agent\n- [x] built\n\n### Human\n{CRIT}\n"
        f"## Verification\n\n## Updates\n")
    (root / ".gitignore").write_text(".context/working/\n")
    # cmd_dispatch reads the issuer session from here and exits 2, silently, when it is missing
    # (pipefail on a failing sed — a pre-existing dispatcher gap, recorded in T-3582).
    (root / ".context" / "working").mkdir(parents=True)
    (root / ".context" / "working" / "session.yaml").write_text("session_id: S-t3582-live\n")
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", f"{TID}: build the calculator")
    return root


def main(argv: list[str]) -> int:
    mode = argv[1] if len(argv) > 1 else "panel"
    kinds = {"claude", "codex", "opencode"} if mode == "panel" else {argv[2]}
    root = fixture(high_impact=(mode == "panel"))
    os.environ.update(PROJECT_ROOT=str(root), FRAMEWORK_ROOT=str(FW))
    from lib import verdict_ledger as vl
    from lib.reviewer import judge_cli

    times: dict[str, float] = {}
    real = judge_cli._dispatch_real

    def timed(**kw):
        t0 = time.time()
        try:
            return real(**kw)
        finally:
            times[kw["vendor"]] = round(time.time() - t0, 1)

    res = judge_cli.judge(TID, root, dispatcher=timed, worker_kinds=kinds,
                          capture=lambda url, pages, out: ([], "no render criterion"))
    seats = []
    for d in res.get("dispatches", []):
        did = d.get("dispatch_id", "")
        rec = vl.dispatch_record(root, did)[0] if did else None
        comps = vl._completions_for(root, did) if did else []
        rows = [r for r in vl._read(vl.VERDICTS, root) if r.get("dispatch_id") == did]
        seats.append({"seat": d.get("seat"), "dispatch_id": did, "error": d.get("error", ""),
                      "kind": (rec or {}).get("worker_kind"), "vendor": (rec or {}).get("vendor"),
                      "model": (rec or {}).get("model"), "wall_s": times.get((rec or {}).get("worker_kind") or ""),
                      "started": bool(did and vl._starts_for(root, did)),
                      "completion_signed": len(comps) == 1, "exit_code": comps[0]["exit_code"] if comps else None,
                      "rows": [{"outcome": r["outcome"], "id": r["id"]} for r in rows],
                      "validated": d.get("results")})
    print(json.dumps({"fixture": str(root), "rung": res.get("rung"), "degraded": res.get("degraded"),
                      "outcomes": res.get("outcomes"), "why": res.get("why"), "error": res.get("error"),
                      "seats": seats}, indent=1, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
