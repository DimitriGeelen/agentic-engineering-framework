"""CLI shim for re-verification (T-1483 v1.5 Pass B).

Usage:
    fw reviewer reverify T-XXX [--json]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from lib.reviewer.reverify import WorktreePool, reverify_task


def _project_root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or Path.cwd())


def _find_task(task_id: str, root: Path) -> Path | None:
    for sub in ("active", "completed"):
        for p in (root / ".tasks" / sub).glob(f"{task_id}-*.md"):
            return p
    return None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="fw reviewer reverify")
    parser.add_argument("task_id", help="T-XXX")
    parser.add_argument("--json", action="store_true")
    parser.add_argument(
        "--timeout",
        type=int,
        default=30,
        help="Per-line timeout in seconds (default: 30)",
    )
    args = parser.parse_args(argv)

    root = _project_root()
    task_path = _find_task(args.task_id, root)
    if not task_path:
        print(f"ERROR: task {args.task_id} not found in .tasks/", file=sys.stderr)
        return 2

    with WorktreePool(root) as pool:
        rep = reverify_task(task_path, pool, timeout_per_line=args.timeout)

    if args.json:
        print(json.dumps(rep.to_dict(), indent=2))
    else:
        print(rep.render())

    return 0 if rep.overall == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
