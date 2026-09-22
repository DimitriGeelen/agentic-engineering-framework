#!/usr/bin/env python3
"""Scan component cards for the under-populated class — a card that says nothing.

T-3430. `fw fabric drift` knew about three failure classes (unregistered,
orphaned, stale edges) and none of them can see a card that exists, points at a
real file, and describes nothing: it is registered, its file is present, and
its absent edges cannot be stale. 792 of 1314 cards on this repo carried the
template `purpose: "TODO: …"` and no health check had an opinion about it.

Three independent sub-classes, counted separately because they have different
fixes: a TODO purpose and an unknown subsystem are both filled by `fw fabric
enrich --describe-only`, while zero edges usually means the file's imports are
not detected by the enricher and wants a look rather than a re-run.

Usage:
    underpopulated.py <components-dir> [--limit N] [--json]
"""

import glob
import json
import os
import sys

import yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import describe  # noqa: E402


def scan(components_dir):
    """Return (rows, counts). `rows` is [(location, [flag, …])] for offenders."""
    rows = []
    counts = {"todo_purpose": 0, "unknown_subsystem": 0, "no_edges": 0, "total": 0}

    for card_path in sorted(glob.glob(os.path.join(components_dir, "*.yaml"))):
        try:
            with open(card_path) as f:
                card = yaml.safe_load(f)
        except (OSError, yaml.YAMLError):
            continue
        if not card:
            continue
        loc = card.get("location") or card.get("id") or os.path.basename(card_path)
        flags = []
        if describe.is_placeholder_purpose(card.get("purpose")):
            counts["todo_purpose"] += 1
            flags.append("TODO purpose")
        if describe.is_placeholder_subsystem(card.get("subsystem")):
            counts["unknown_subsystem"] += 1
            flags.append("unknown subsystem")
        if describe.card_edge_count(card) == 0:
            counts["no_edges"] += 1
            flags.append("no edges")
        if flags:
            counts["total"] += 1
            rows.append((loc, flags))

    return rows, counts


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    as_json = "--json" in argv
    if as_json:
        argv.remove("--json")
    limit = 10
    if "--limit" in argv:
        i = argv.index("--limit")
        limit = int(argv[i + 1])
        del argv[i:i + 2]
    if not argv:
        print("usage: underpopulated.py <components-dir> [--limit N] [--json]",
              file=sys.stderr)
        return 2

    rows, counts = scan(argv[0])

    if as_json:
        print(json.dumps({
            "counts": counts,
            "offenders": [{"location": loc, "flags": f} for loc, f in rows[:limit]],
        }))
        return 0

    for loc, flags in rows[:limit]:
        print(f"  ! {loc} ({', '.join(flags)})")
    if len(rows) > limit:
        print(f"  … and {len(rows) - limit} more")
    # Sentinels, stripped by the bash caller before printing.
    print(f"##UP_TODO={counts['todo_purpose']}##")
    print(f"##UP_UNKNOWN={counts['unknown_subsystem']}##")
    print(f"##UP_NOEDGES={counts['no_edges']}##")
    print(f"##UP_TOTAL={counts['total']}##")
    return 0


if __name__ == "__main__":
    sys.exit(main())
