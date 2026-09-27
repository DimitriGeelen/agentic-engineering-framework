"""Inline CLI for the BVP score judge (T-3526).

    python3 -m lib.bvp_judge_cli T-XXX [--json]

Read-only: judges the latest `bvp_scores_proposed:` entry on one task and
prints the verdict. Writes nothing — see `lib/bvp_judge.py` module docstring.

`fw bvp judge T-XXX` routes here (see `lib/bvp.sh:bvp_dispatch`). `fw bvp judge
T-XXX --dispatch` routes to `lib.bvp_judge_dispatch_cli` instead (T-1951 shape).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from lib.bvp_judge import judge_task
from lib.judge_verdict import format_verdict, may_proceed


def _resolve_task_path(root: Path, task_id: str) -> Path | None:
    for sub in ("active", "completed"):
        for p in (root / ".tasks" / sub).glob(f"{task_id}-*.md"):
            return p
        direct = root / ".tasks" / sub / f"{task_id}.md"
        if direct.is_file():
            return direct
    return None


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]

    parser = argparse.ArgumentParser(prog="fw bvp judge",
                                      description="Judge a proposed BVP score (T-3526).")
    parser.add_argument("task_id", help="Task ID to judge (e.g. T-3526)")
    parser.add_argument("--json", action="store_true", help="Emit the verdict as JSON")
    args = parser.parse_args(argv)

    import os
    root = Path(os.environ.get("PROJECT_ROOT") or os.getcwd())
    task_path = _resolve_task_path(root, args.task_id)
    if task_path is None:
        print(f"ERROR: task {args.task_id} not found under {root}/.tasks/{{active,completed}}",
              file=sys.stderr)
        return 2

    v, reason = judge_task(task_path)
    if v is None:
        out = {"skipped": True, "task_id": args.task_id, "reason": reason}
        if args.json:
            print(json.dumps(out))
        else:
            print(f"SKIPPED {args.task_id}: {reason}")
        return 0

    if args.json:
        print(json.dumps(v))
    else:
        print(format_verdict(v))
        print(f"  reason: {reason}")

    return 0 if may_proceed(v) else 1


if __name__ == "__main__":
    sys.exit(main())
