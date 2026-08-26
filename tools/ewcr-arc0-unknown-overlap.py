#!/usr/bin/env python3
"""EWCR Arc 0, falsifier 1 — do the Unknown-subsystem Fabric entries intersect
the runtime write set?

Roadmap §6 fence 1 ("Component Fabric non-empty, enriched, validated") is
currently NOT passable: `bin/fw fabric overview` reports a large `Unknown`
subsystem. The dossier's disposition (questions-and-dispositions.md C1) reads
"Unmeasured, not zero" — the right encoding, and the reason this task exists.

The re-scoping in that disposition is the whole point: fence 1 does NOT require
a full-corpus enrichment. It requires resolving `Unknown` for the subsystems in
the RUNTIME'S WRITE SET. This script measures that intersection so the operator
can size the fence instead of guessing at it.

WHY THIS IS A SCRIPT AND NOT A NUMBER IN A REPORT. The Unknown count moves —
it was 512 when the dossier measured and 519 by the time Arc 0 opened, without
anyone working on it. A fence keyed to a number that drifts needs a command,
not a citation.

WHAT THIS DELIBERATELY DOES NOT DO. It does not classify anything, write any
Fabric card, or touch the runtime. Arc 0 is measurement-only by its own scope
fence (`.context/arcs/ewcr-arc0-contract-evidence.yaml`).

Exit codes:
    0  measurement completed
    2  REFUSED — the corpus could not be read, or zero components were
       enumerated. Zero enumerated is not "no overlap"; it is "nothing was
       looked at", and reporting 0% overlap from an empty scan is the exact
       false-green this programme exists to eliminate.
"""

from __future__ import annotations

import json
import os
import sys
from collections import Counter, defaultdict

try:
    import yaml
except ImportError:
    print("REFUSED: PyYAML unavailable — cannot read Fabric cards.", file=sys.stderr)
    sys.exit(2)

ROOT = os.environ.get("FRAMEWORK_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CARDS = os.path.join(ROOT, ".fabric", "components")

# ── The runtime write set, derived from architecture §5.1 (AEF column) ────────
#
# §5.1 is an OWNERSHIP contract, not a file list, so the mapping below is a
# derivation and is stated explicitly rather than hidden in a glob. Two
# definitions are measured because the honest answer is a range: "the runtime's
# write set" is not yet frozen, and picking one definition silently would hand
# the operator a number with a hidden assumption inside it.
#
# CORE  — surfaces the runtime kernel itself must write (Arc 1-3).
# BROAD — every surface §5.1 assigns to AEF, including those the runtime only
#         projects through (Arc 4-6).

CORE = {
    "runner/ledger/actions (§5.1 row 5)": (
        "lib/resolver", "lib/orchestrator", "lib/outcome", "lib/dispatch",
        "agents/dispatch/", "lib/termlink", "lib/bus",
    ),
    "procedure/runtime semantics (§5.1 row 2)": (
        "lib/corpus", "policy/",
    ),
    "fabrics — canonical/derived records (§5.1 row 6)": (
        "lib/fabric", "agents/fabric/",
    ),
}

BROAD_EXTRA = {
    "tasks/inception/approvals/BVP/gates (§5.1 row 1)": (
        "agents/task-create/", "lib/inception", "lib/bvp", "lib/review",
        "agents/context/", "lib/task",
    ),
    "diagram→procedure mapping validation (§5.1 row 4)": (
        "agents/designer/", "web/blueprints/designer",
    ),
    "operator interaction / projection (§5.1 row 7)": (
        "web/",
    ),
}


def load_cards() -> list[dict]:
    if not os.path.isdir(CARDS):
        print(f"REFUSED: no Fabric card directory at {CARDS}", file=sys.stderr)
        sys.exit(2)
    out = []
    for name in sorted(os.listdir(CARDS)):
        if not name.endswith((".yaml", ".yml")):
            continue
        path = os.path.join(CARDS, name)
        try:
            with open(path, encoding="utf-8") as fh:
                doc = yaml.safe_load(fh)
        except Exception:
            continue
        if isinstance(doc, dict):
            doc["_card"] = name
            out.append(doc)
    return out


def location_of(card: dict) -> str:
    for key in ("location", "path", "file"):
        val = card.get(key)
        if isinstance(val, str) and val.strip():
            return val.strip().lstrip("./")
    return ""


def matches(loc: str, prefixes: tuple[str, ...]) -> bool:
    return any(loc.startswith(p) for p in prefixes)


def main() -> int:
    cards = load_cards()
    if not cards:
        print("REFUSED: enumerated 0 Fabric cards.", file=sys.stderr)
        print("  This is not 'no overlap' — it is 'nothing was looked at'.", file=sys.stderr)
        return 2

    unknown = [c for c in cards if str(c.get("subsystem", "")).strip().lower() in ("unknown", "", "none")]

    if not unknown:
        print("REFUSED: enumerated 0 Unknown-subsystem cards.", file=sys.stderr)
        print("  `fw fabric overview` reports a non-zero Unknown subsystem, so a zero", file=sys.stderr)
        print("  here means this script's subsystem predicate is wrong, not that the", file=sys.stderr)
        print("  fence is clear. Fix the predicate before trusting any number below.", file=sys.stderr)
        return 2

    core_prefixes = tuple(p for group in CORE.values() for p in group)
    broad_prefixes = core_prefixes + tuple(p for group in BROAD_EXTRA.values() for p in group)

    no_location = [c for c in unknown if not location_of(c)]
    in_core = [c for c in unknown if location_of(c) and matches(location_of(c), core_prefixes)]
    in_broad = [c for c in unknown if location_of(c) and matches(location_of(c), broad_prefixes)]

    print("EWCR Arc 0 — falsifier 1: Unknown-subsystem overlap with the runtime write set")
    print("=" * 78)
    print(f"Fabric cards enumerated          : {len(cards)}")
    print(f"Unknown-subsystem cards          : {len(unknown)}")
    print(f"  ...of which carry no location  : {len(no_location)}   <- cannot be placed either way")
    print()
    print(f"Intersection with CORE write set : {len(in_core)}"
          f"   ({100.0 * len(in_core) / len(unknown):.1f}% of Unknown)")
    print(f"Intersection with BROAD write set: {len(in_broad)}"
          f"   ({100.0 * len(in_broad) / len(unknown):.1f}% of Unknown)")
    print()

    print("── CORE breakdown by §5.1 row ──")
    for label, prefixes in CORE.items():
        hits = [c for c in unknown if location_of(c) and matches(location_of(c), prefixes)]
        print(f"  {len(hits):>4}  {label}")
    print()
    print("── BROAD-only additions by §5.1 row ──")
    for label, prefixes in BROAD_EXTRA.items():
        hits = [c for c in unknown if location_of(c) and matches(location_of(c), prefixes)]
        print(f"  {len(hits):>4}  {label}")
    print()

    top = Counter()
    for c in unknown:
        loc = location_of(c)
        top[loc.split("/")[0] if "/" in loc else (loc or "(no location)")] += 1
    print("── Where the Unknown cards actually live (top 12 roots) ──")
    for root, n in top.most_common(12):
        print(f"  {n:>4}  {root}")

    payload = {
        "cards_total": len(cards),
        "unknown_total": len(unknown),
        "unknown_without_location": len(no_location),
        "overlap_core": len(in_core),
        "overlap_broad": len(in_broad),
        "core_paths": sorted(location_of(c) for c in in_core),
    }
    out_path = os.path.join(ROOT, ".context", "audits", "ewcr-arc0-unknown-overlap.json")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)
    print()
    print(f"Machine-readable result: {os.path.relpath(out_path, ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
