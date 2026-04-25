"""CLI shim for drift detection (T-1483 v1.5 Pass A).

Usage:
    fw reviewer drift T-XXX [--json] [--baseline]

Modes:
    default:   compare current file hashes against the recorded baseline
    --baseline: write the current hashes as the new baseline (one-shot init)
    --json:    emit DriftReport as JSON instead of human-readable text
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from lib.reviewer.drift import (
    compute_hashes,
    detect_drift,
    extract_file_refs,
    write_baseline,
)
from lib.reviewer.static_scan import extract_section, parse_task_file


def _project_root() -> Path:
    return Path(os.environ.get("PROJECT_ROOT") or Path.cwd())


def _find_task(task_id: str, root: Path) -> Path | None:
    for sub in ("active", "completed"):
        for p in (root / ".tasks" / sub).glob(f"{task_id}-*.md"):
            return p
    return None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="fw reviewer drift")
    parser.add_argument("task_id", help="T-XXX")
    parser.add_argument("--json", action="store_true", help="JSON output")
    parser.add_argument(
        "--baseline",
        action="store_true",
        help="Write current hashes as the new baseline (one-shot init)",
    )
    args = parser.parse_args(argv)

    root = _project_root()
    task_path = _find_task(args.task_id, root)
    if not task_path:
        print(f"ERROR: task {args.task_id} not found in .tasks/active/ or completed/", file=sys.stderr)
        return 2

    if args.baseline:
        text = task_path.read_text()
        body = text.split("---", 2)[2] if text.startswith("---") else text
        verification = extract_section(body, "Verification") or ""
        refs = extract_file_refs(verification, root)
        baseline = compute_hashes(refs, root)
        new_text = write_baseline(text, baseline)
        task_path.write_text(new_text)
        print(f"Wrote drift baseline for {args.task_id}: {len(baseline)} files hashed")
        return 0

    rep = detect_drift(task_path, root)
    if args.json:
        print(json.dumps(rep.to_dict(), indent=2))
    else:
        print(rep.render())
    return 1 if rep.has_drift else 0


if __name__ == "__main__":
    sys.exit(main())
