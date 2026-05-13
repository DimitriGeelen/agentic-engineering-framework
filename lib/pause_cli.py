"""CLI dispatcher for `fw pause`. T-1809 (dispatch-safety slice 5).

Subcommands:
  list      — show paused dispatches awaiting resolution (CLI parity with
              Watchtower /approvals Paused panel from T-1808)
  resolve   — capture operator's answer and fire a retry via Resolver
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

# Put lib/ on path so siblings import cleanly.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from dispatch_pause import (  # noqa: E402
    format_age,
    list_paused_dispatches,
    truncate,
)
from pause_resolve import PauseResolveError, resolve_pause  # noqa: E402


PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", ".")).resolve()


def cmd_list(args: argparse.Namespace) -> int:
    rows = list_paused_dispatches(PROJECT_ROOT)
    if args.json:
        print(json.dumps(rows, indent=2))
        return 0
    if not rows:
        print("No paused dispatches awaiting resolution.")
        return 0
    print(f"PAUSED — Workers awaiting resolution ({len(rows)})")
    print(f"{'AGE':>5}  {'DISPATCH':<10}  {'TASK':<10}  {'SEV':<6}  QUESTION")
    for r in rows:
        age = format_age(r["age_seconds"])
        did = (r["dispatch_id"][:8] + "..") if len(r["dispatch_id"]) > 8 else r["dispatch_id"]
        sev = r["severity"] or "?"
        q = truncate(r["question"] or "(no question)", 60)
        print(f"{age:>5}  {did:<10}  {r['task_id']:<10}  {sev:<6}  {q}")
    return 0


def cmd_resolve(args: argparse.Namespace) -> int:
    try:
        envelope, row = resolve_pause(
            args.dispatch_id,
            args.answer,
            project_root=PROJECT_ROOT,
            dry_run=args.dry_run,
        )
    except PauseResolveError as e:
        print(f"fw pause resolve: {e}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps({"envelope": envelope, "row": row}, indent=2, default=str))
        return 0
    print(f"new dispatch_id:    {envelope['dispatch_id']}")
    print(f"task_id:            {envelope['task_id']}")
    print(f"task_type:          {envelope['task_type']}")
    print(f"worker_kind:        {envelope['worker_kind']}")
    print(f"retry_of_dispatch:  {row.get('retry_of_dispatch_id')}")
    print(f"prompt:             {len(envelope['prompt'])} chars")
    if args.dry_run:
        print("dry-run:            no JSONL append, no blob written")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="fw pause",
        description="Pause re-dispatch chain (dispatch-safety arc slice 5).",
    )
    sub = p.add_subparsers(dest="subcommand", required=True)

    sp_l = sub.add_parser("list", help="show paused dispatches awaiting resolution")
    sp_l.add_argument("--json", action="store_true", help="emit JSON")
    sp_l.set_defaults(func=cmd_list)

    sp_r = sub.add_parser(
        "resolve",
        help="capture operator's answer and re-dispatch via Resolver",
    )
    sp_r.add_argument("dispatch_id", help="paused dispatch ID (full or 6+ char prefix)")
    sp_r.add_argument("--answer", required=True, help="operator's answer text")
    sp_r.add_argument("--dry-run", action="store_true", help="build envelope, do not write")
    sp_r.add_argument("--json", action="store_true", help="emit JSON")
    sp_r.set_defaults(func=cmd_resolve)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
