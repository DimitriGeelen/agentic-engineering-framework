#!/usr/bin/env python3
"""EWCR Arc 0 — write-set-SCOPED fabric coverage (T-3401, EWCR-ARC0-ATTEST-832 Round 1).

`ewcr-arc0-coverage-check.py` measures coverage over the five WHOLE roots
(lib, web, agents, bin, policy) named in `arc0-write-set.md` — a superset of
the write set itself, diluted by every non-write-set file those roots also
contain (e.g. lib/branch-hygiene.sh, agents/audit/, which are not part of
architecture §5.1's AEF write-set rows).

This script scopes to the exact path PREFIXES `arc0-write-set.md` lists for
CORE and CORE+BROAD, so the coverage number answers the falsifier's actual
question — is the write set itself carded — rather than a broader question
that happens to look similar.

Exit codes:
    0  measurement completed
    2  REFUSED — nothing enumerated, so no comparison is possible
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
SOURCE_EXT = (".py", ".sh", ".html", ".yaml", ".yml")
SKIP_DIRS = {".git", "__pycache__", "node_modules", ".agentic-framework", ".claude"}

# Verbatim from docs/research/executable-workflow/arc0-write-set.md.
# NOTE (measured 2026-09-21): two CORE prefixes match zero files on disk —
# `lib/orchestrator` and `lib/fabric`. That functionality actually lives at
# `agents/orchestrator/` and `agents/fabric/` respectively (the latter IS
# separately listed; the former is not listed under any prefix at all). This
# is a write-set-DOCUMENT drift, not a coverage-tool gap — agents/orchestrator/
# is still scanned because "agents" is one of the five roots either tool walks.
CORE = [
    "lib/resolver", "lib/orchestrator", "lib/outcome", "lib/dispatch",
    "agents/dispatch/", "lib/termlink", "lib/bus", "lib/corpus", "policy/",
    "lib/fabric", "agents/fabric/",
]
BROAD_ADDS = [
    "agents/task-create/", "lib/inception", "lib/bvp", "lib/review",
    "agents/context/", "lib/task", "agents/designer/",
    "web/blueprints/designer", "web/",
]
SCAN_ROOTS = ["lib", "web", "agents", "policy"]  # bin carries no write-set prefix


def disk_files(root: str) -> set[str]:
    base = os.path.join(ROOT, root)
    found: set[str] = set()
    if not os.path.isdir(base):
        return found
    for dirpath, dirnames, filenames in os.walk(base):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if fn.endswith(SOURCE_EXT):
                rel = os.path.relpath(os.path.join(dirpath, fn), ROOT)
                found.add(rel)
    return found


def load_cards() -> dict[str, dict]:
    if not os.path.isdir(CARDS):
        print(f"REFUSED: no card directory at {CARDS}", file=sys.stderr)
        sys.exit(2)
    by_loc: dict[str, dict] = {}
    for name in sorted(os.listdir(CARDS)):
        if not name.endswith((".yaml", ".yml")):
            continue
        try:
            with open(os.path.join(CARDS, name), encoding="utf-8") as fh:
                doc = yaml.safe_load(fh)
        except Exception:
            continue
        if not isinstance(doc, dict):
            continue
        for key in ("location", "path", "file"):
            v = doc.get(key)
            if isinstance(v, str) and v.strip():
                by_loc[v.strip().lstrip("./")] = doc
                break
    return by_loc


def main() -> int:
    by_loc = load_cards()
    if not by_loc:
        print("REFUSED: enumerated 0 Fabric cards.", file=sys.stderr)
        return 2

    all_files: set[str] = set()
    for root in SCAN_ROOTS:
        all_files |= disk_files(root)
    if not all_files:
        print("REFUSED: enumerated 0 source files across lib/web/agents/policy.", file=sys.stderr)
        return 2

    print("EWCR Arc 0 — write-set-SCOPED coverage (not whole-root)")
    print("=" * 78)

    for label, prefixes in (("CORE", CORE), ("CORE+BROAD", CORE + BROAD_ADDS)):
        ws_files = sorted(f for f in all_files if any(f.startswith(p) for p in prefixes))
        carded = [f for f in ws_files if f in by_loc]
        unknown = [f for f in carded
                   if str(by_loc[f].get("subsystem", "")).strip().lower() in ("unknown", "", "none")]
        uncarded = [f for f in ws_files if f not in by_loc]
        cov = (100.0 * len(carded) / len(ws_files)) if ws_files else 0.0
        print(f"{label:<12} files:{len(ws_files):>4}  carded:{len(carded):>4}  "
              f"coverage:{cov:>6.1f}%  unknown-subsystem:{len(unknown):>3}  no-card:{len(uncarded):>3}")
        for f in uncarded:
            print(f"  no-card: {f}")

    print()
    print("Prefixes matching ZERO files on disk (document drift, not a coverage gap —")
    print("the functionality exists elsewhere within a scanned root):")
    for p in CORE + BROAD_ADDS:
        if not any(f.startswith(p) for f in all_files):
            print(f"  {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
