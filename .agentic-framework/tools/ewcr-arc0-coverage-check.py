#!/usr/bin/env python3
"""EWCR Arc 0 — the control for falsifier 1.

`ewcr-arc0-unknown-overlap.py` reports a LOW overlap between the Unknown
subsystem and the runtime write set. That number has two possible meanings and
they are opposite:

    (a) the runtime write set is well classified   -> fence 1 is nearly passable
    (b) the runtime write set is barely IN the Fabric -> fence 1 is not measurable

Both produce a low overlap count. Reading (a) off the number alone is exactly
the false green this programme exists to eliminate — a check that cannot see its
subject reports the same thing as one that looked and was satisfied.

This script discriminates them: for each runtime write-set root it compares the
number of source files ON DISK against the number carrying a Fabric card, and
reports the classified/unclassified split of those cards.

Exit codes:
    0  measurement completed
    2  REFUSED — nothing enumerated on one side, so no comparison is possible
"""

from __future__ import annotations

import os
import sys

try:
    import yaml
except ImportError:
    print("REFUSED: PyYAML unavailable.", file=sys.stderr)
    sys.exit(2)

ROOT = os.environ.get("FRAMEWORK_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARDS = os.path.join(ROOT, ".fabric", "components")

# Roots that make up the runtime write set (architecture §5.1, AEF column).
ROOTS = ["lib", "web", "agents", "bin", "policy"]
SOURCE_EXT = (".py", ".sh", ".html", ".yaml", ".yml")

SKIP_DIRS = {".git", "__pycache__", "node_modules", ".agentic-framework", ".claude"}


def disk_files(root: str) -> set[str]:
    base = os.path.join(ROOT, root)
    found: set[str] = set()
    if not os.path.isdir(base):
        return found
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if fn.endswith(SOURCE_EXT) or (root == "bin" and "." not in fn):
                rel = os.path.relpath(os.path.join(dirpath, fn), ROOT)
                found.add(rel)
    return found


def load_cards() -> list[dict]:
    if not os.path.isdir(CARDS):
        print(f"REFUSED: no card directory at {CARDS}", file=sys.stderr)
        sys.exit(2)
    out = []
    for name in sorted(os.listdir(CARDS)):
        if not name.endswith((".yaml", ".yml")):
            continue
        try:
            with open(os.path.join(CARDS, name), encoding="utf-8") as fh:
                doc = yaml.safe_load(fh)
        except Exception:
            continue
        if isinstance(doc, dict):
            out.append(doc)
    return out


def location_of(card: dict) -> str:
    for key in ("location", "path", "file"):
        v = card.get(key)
        if isinstance(v, str) and v.strip():
            return v.strip().lstrip("./")
    return ""


def main() -> int:
    cards = load_cards()
    if not cards:
        print("REFUSED: enumerated 0 Fabric cards.", file=sys.stderr)
        return 2

    by_loc: dict[str, dict] = {}
    for c in cards:
        loc = location_of(c)
        if loc:
            by_loc[loc] = c

    total_disk = 0
    print("EWCR Arc 0 — control: is the runtime write set actually IN the Fabric?")
    print("=" * 78)
    print(f"{'root':<10}{'files on disk':>15}{'with a card':>14}{'coverage':>11}"
          f"{'card=Unknown':>15}")
    print("-" * 78)

    for root in ROOTS:
        files = disk_files(root)
        total_disk += len(files)
        carded = [f for f in files if f in by_loc]
        unknown = [f for f in carded
                   if str(by_loc[f].get("subsystem", "")).strip().lower() in ("unknown", "", "none")]
        cov = (100.0 * len(carded) / len(files)) if files else 0.0
        print(f"{root:<10}{len(files):>15}{len(carded):>14}{cov:>10.1f}%{len(unknown):>15}")

    if total_disk == 0:
        print("\nREFUSED: enumerated 0 source files across every runtime root.", file=sys.stderr)
        print("  A 0% overlap computed from an empty disk scan is not evidence.", file=sys.stderr)
        return 2

    print("-" * 78)
    print()
    print("READING THIS TABLE.")
    print("  High coverage + low Unknown  -> the low overlap is real; fence 1 is")
    print("                                  passable by resolving a small set.")
    print("  Low coverage                 -> the low overlap is an ARTEFACT of the")
    print("                                  write set not being in the Fabric. Fence 1")
    print("                                  is NOT measurable yet, whatever the")
    print("                                  overlap number says.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
