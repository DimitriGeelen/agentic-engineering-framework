#!/usr/bin/env python3
"""Measure the indexed corpus by source class — size and growth, separately.

T-3031. The ranking that chose T-3028 (handovers = 68% of the corpus, 79% of
its growth) is stale by construction: the digest cut handovers 15.3x, so the
thing that measurement described no longer exists at that size. This script
exists so the next candidate is picked from a number anyone can regenerate
rather than from a pipeline that lived in one session's transcript.

Two questions, deliberately kept apart:

  SIZE   — what occupies the corpus right now.
  GROWTH — what is adding to it. T-3028's win came from a class that led both,
           and there is no reason the next one will. A class that is 2% of the
           corpus and 40% of its growth is a better target than a 30% class
           that stopped moving two months ago, because reduction work on a
           static class is paid once and reduction work on a growing class
           keeps paying.

The inclusion set is `web.search_utils.collect_files()` — the same function the
indexer walks — rather than a glob written here. A measurement whose scope
drifts from the indexer's is a measurement of something else.

Usage:
    python3 tools/measure_corpus_classes.py [--growth-days 30] [--json]
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", os.getcwd())).resolve()
sys.path.insert(0, str(PROJECT_ROOT))


# Ordered: first match wins, so the specific precedes the general. Each entry is
# (class name, path predicate on the PROJECT_ROOT-relative posix path).
_CLASSES = (
    ("handovers", lambda p: p.startswith(".context/handovers/")),
    ("episodics", lambda p: p.startswith(".context/episodic/")),
    ("tasks-active", lambda p: p.startswith(".tasks/active/")),
    ("tasks-completed", lambda p: p.startswith(".tasks/completed/")),
    ("tasks-other", lambda p: p.startswith(".tasks/")),
    ("generated-component-docs", lambda p: p.startswith("docs/generated/")),
    ("reports", lambda p: p.startswith("docs/reports/")),
    ("docs-other", lambda p: p.startswith("docs/")),
    ("agent-docs", lambda p: p.startswith("agents/")),
    ("policy", lambda p: p.startswith("policy/")),
    ("arcs", lambda p: p.startswith(".context/arcs/")),
    ("context-other", lambda p: p.startswith(".context/")),
    ("top-level-specs", lambda p: "/" not in p),
)


def classify(rel: str) -> str:
    for name, pred in _CLASSES:
        if pred(rel):
            return name
    return "unclassified"


def measure_size() -> dict:
    from web.search_utils import collect_files  # noqa: PLC0415

    by_class: dict[str, dict] = defaultdict(lambda: {"bytes": 0, "files": 0})
    seen: set[Path] = set()
    for f in collect_files():
        # collect_files can yield the same path twice (a top-level *.md that is
        # also inside an AUTHORED_DIR). Counting it twice would inflate whichever
        # class it lands in, so dedupe on the resolved path.
        try:
            resolved = f.resolve()
        except OSError:
            continue
        if resolved in seen:
            continue
        seen.add(resolved)
        try:
            size = resolved.stat().st_size
            rel = resolved.relative_to(PROJECT_ROOT).as_posix()
        except (OSError, ValueError):
            continue
        cls = by_class[classify(rel)]
        cls["bytes"] += size
        cls["files"] += 1
    return dict(by_class)


def measure_growth(days: int) -> dict:
    """Bytes ADDED per class over the window, from git's own numstat.

    Added lines rather than net change: the question is what is producing
    corpus, and a class that adds 10k lines and deletes 9k is still generating
    10k lines of embedding work every cycle. Net would hide that.

    Binary files report '-' in numstat and are skipped; the corpus is text.
    """
    try:
        proc = subprocess.run(
            [
                "git", "-C", str(PROJECT_ROOT), "log",
                f"--since={days}.days.ago", "--numstat", "--format=",
            ],
            capture_output=True, text=True, timeout=120,
        )
    except (OSError, subprocess.SubprocessError):
        return {}
    if proc.returncode != 0:
        return {}

    by_class: dict[str, dict] = defaultdict(lambda: {"added": 0, "removed": 0})
    for line in proc.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        added, removed, path = parts
        if added == "-" or removed == "-":
            continue
        if Path(path).suffix not in {".md", ".yaml", ".yml", ".txt"}:
            continue
        cls = by_class[classify(path)]
        try:
            cls["added"] += int(added)
            cls["removed"] += int(removed)
        except ValueError:
            continue
    return dict(by_class)


def _table(title: str, rows: list[tuple], headers: tuple, total: int) -> None:
    print(f"\n{title}")
    print("-" * len(title))
    width = max((len(r[0]) for r in rows), default=10)
    print(f"{headers[0]:<{width}}  {headers[1]:>12}  {headers[2]:>8}  {headers[3]:>7}")
    for name, value, count in rows:
        share = (value / total * 100) if total else 0.0
        print(f"{name:<{width}}  {value:>12,}  {count:>8,}  {share:>6.1f}%")
    print(f"{'TOTAL':<{width}}  {total:>12,}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--growth-days", type=int, default=30)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    size = measure_size()
    growth = measure_growth(args.growth_days)

    total_bytes = sum(v["bytes"] for v in size.values())
    total_added = sum(v["added"] for v in growth.values())

    if args.json:
        print(json.dumps({
            "project_root": str(PROJECT_ROOT),
            "growth_days": args.growth_days,
            "total_bytes": total_bytes,
            "total_added_lines": total_added,
            "size": size,
            "growth": growth,
        }, indent=2, sort_keys=True))
        return 0

    _table(
        f"SIZE — indexed corpus by class ({sum(v['files'] for v in size.values()):,} files)",
        sorted(((k, v["bytes"], v["files"]) for k, v in size.items()),
               key=lambda r: -r[1]),
        ("class", "bytes", "files", "share"),
        total_bytes,
    )
    _table(
        f"GROWTH — lines added, last {args.growth_days} days",
        sorted(((k, v["added"], v["removed"]) for k, v in growth.items()),
               key=lambda r: -r[1]),
        ("class", "added", "removed", "share"),
        total_added,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
