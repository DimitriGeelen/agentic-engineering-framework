"""Inline CLI for the arc-scoped-driver judge (T-3527).

    python3 -m lib.arc_driver_judge_cli <arc-id> "<name>" [--json]
    python3 -m lib.arc_driver_judge_cli <arc-id> --all [--json]

Read-only: judges a proposed or approved scoped driver against the arc's own
goal, wrapping (not replacing) `lib/arc-driver-review.sh`'s static checks.
Writes nothing — see `lib/arc_driver_judge.py` module docstring.

`fw arc judge-driver` routes here (see `lib/arc.sh:arc_judge_driver`).
"""

from __future__ import annotations

import argparse
import json
import sys

from lib.arc_driver_judge import ARCS_DIR, JUDGE_ID, judge_driver, list_driver_names, load_arc, resolve_arc_file
from lib.judge_verdict import format_verdict, may_proceed


def main(argv: list[str] | None = None) -> int:
    argv = argv if argv is not None else sys.argv[1:]

    parser = argparse.ArgumentParser(
        prog="fw arc judge-driver",
        description="Judge an arc-scoped driver against the arc's own goal (T-3527).")
    parser.add_argument("arc_id", help="Arc slug or arc-NNN id")
    parser.add_argument("name", nargs="?", default=None,
                         help="Driver name (omit and pass --all instead to judge "
                              "every proposed/approved driver on the arc)")
    parser.add_argument("--all", action="store_true",
                         help="Judge every proposed/approved driver on the arc")
    parser.add_argument("--json", action="store_true", help="Emit verdict(s) as JSON")
    args = parser.parse_args(argv)

    if not args.all and not args.name:
        print("ERROR: driver name is required (or pass --all)", file=sys.stderr)
        return 2

    arc_file = resolve_arc_file(args.arc_id)
    if arc_file is None:
        print(f"ERROR: arc {args.arc_id!r} not found under {ARCS_DIR}", file=sys.stderr)
        return 2

    arc_data = load_arc(arc_file)
    if not arc_data:
        print(f"ERROR: could not parse {arc_file}", file=sys.stderr)
        return 2

    names = list_driver_names(arc_data) if args.all else [args.name]
    if not names:
        out = {"skipped": True, "arc_id": args.arc_id,
               "reason": "no proposed or scoped drivers on this arc"}
        if args.json:
            print(json.dumps(out))
        else:
            print(f"SKIPPED: no proposed or scoped drivers on arc {args.arc_id}")
        return 0

    results = []
    overall_ok = True
    for name in names:
        v, reason = judge_driver(args.arc_id, arc_file, arc_data, name, judge_id=JUDGE_ID)
        if v is None:
            results.append({"skipped": True, "name": name, "reason": reason})
            continue
        results.append(v)
        if not may_proceed(v):
            overall_ok = False

    if args.json:
        if len(results) == 1:
            print(json.dumps(results[0]))
        else:
            print(json.dumps({"arc_id": args.arc_id, "reviewed": results}))
    else:
        for r in results:
            if r.get("skipped"):
                print(f"SKIPPED {r['name']}: {r['reason']}")
            else:
                print(format_verdict(r))
                print()

    return 0 if overall_ok else 1


if __name__ == "__main__":
    sys.exit(main())
