#!/usr/bin/env python3
"""Probe: when the index is queried, which handovers come back, and how old are they?

T-3032. The recall telemetry (`.context/working/recall-telemetry.jsonl`) records
ts / surface / query_hash / n_hits / top_score / latency_ms / outcome — and no
field naming a document, path or source. It measures whether recall was fast and
whether it hit; it cannot say what it hit. So the retention-window question
(is an old handover ever the thing that answers a query?) is unanswerable from
usage data, and this probe stands in for it.

READ THE LIMITATION BEFORE THE NUMBERS: this measures what a REPLAYED QUERY
WOULD RETRIEVE, not what any human or agent actually retrieved and used. Those
are different claims. A chunk surfacing in the top-k is not evidence anyone
needed it — retrieval is not usefulness. Treat the output as an upper bound on
what a retention window could cost, which is the direction that keeps the
conclusion conservative: if even the upper bound shows old handovers rarely
surfacing, the window is safe; if they surface constantly, it is not, and no
amount of usage data would rescue it.

Usage:
    python3 tools/probe_handover_recall.py [--limit 20] [--json]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", os.getcwd())).resolve()
sys.path.insert(0, str(PROJECT_ROOT))

# Queries chosen to span the kinds of thing the corpus is actually asked, and
# written down so this is repeatable rather than a one-off. Deliberately mixed:
# some are the "what happened in a past session" shape a handover is uniquely
# positioned to answer — if handovers never win even THOSE, the window is safe
# by a wide margin.
QUERIES = [
    # Durable knowledge — should be answered by learnings/decisions/tasks.
    "why does the framework refuse a commit on master",
    "how do I bypass the focus drift gate",
    "what is the difference between REVIEW and REVIEWER acceptance criteria",
    "how does the verification gate handle pipefail",
    "what causes self-vendor drift on push",
    # Historical / session-shaped — the handover's home turf.
    "what did the session decide about the handover digest",
    "what was blocking the push at the end of the last session",
    "which tasks were left partial-complete",
    "what happened with the cron registry drift",
    "what did we learn about TermLink identity rotation",
    # Operational.
    "how do I recover a consumer project that was vendored before T-2232",
    "what is the retention policy for dispatch blobs",
]

_HANDOVER_RE = re.compile(r"\.context/handovers/")
_SESSION_RE = re.compile(r"S-(\d{4})-(\d{2})(\d{2})")


def handover_age_days(path: str, now: datetime) -> int | None:
    """Age from the session stamp in the filename, falling back to mtime.

    The stamp is preferred: it is what the file is ABOUT, whereas mtime moves
    when anything rewrites the file (a vendor sync, a checkout) and would make
    an old handover look fresh."""
    m = _SESSION_RE.search(path)
    if m:
        try:
            stamped = datetime(int(m.group(1)), int(m.group(2)), int(m.group(3)),
                               tzinfo=timezone.utc)
            return (now - stamped).days
        except ValueError:
            pass
    try:
        mtime = (PROJECT_ROOT / path).stat().st_mtime
        return (now - datetime.fromtimestamp(mtime, timezone.utc)).days
    except OSError:
        return None


def bucket(days: int | None) -> str:
    if days is None:
        return "unknown"
    for edge, name in ((7, "0-7d"), (30, "8-30d"), (90, "31-90d"), (180, "91-180d")):
        if days <= edge:
            return name
    return ">180d"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--limit", type=int, default=20)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    from web import embeddings  # noqa: PLC0415

    if not embeddings.is_index_ready():
        print("probe: index not ready — cannot answer", file=sys.stderr)
        return 2

    now = datetime.now(timezone.utc)
    per_query = []
    age_hits: Counter = Counter()
    total_hits = 0
    total_handover_hits = 0
    top1_handover = 0

    for q in QUERIES:
        try:
            res = embeddings.search(q, limit=args.limit)
        except Exception as exc:  # noqa: BLE001 — a failed query is a finding
            per_query.append({"query": q, "error": str(exc)})
            continue
        hits = res.get("results") or res.get("hits") or []
        paths = [str(h.get("path") or h.get("file") or "") for h in hits]
        h_idx = [i for i, p in enumerate(paths) if _HANDOVER_RE.search(p)]
        total_hits += len(paths)
        total_handover_hits += len(h_idx)
        if paths and _HANDOVER_RE.search(paths[0]):
            top1_handover += 1
        ages = []
        for i in h_idx:
            d = handover_age_days(paths[i], now)
            ages.append(d)
            age_hits[bucket(d)] += 1
        per_query.append({
            "query": q,
            "n_hits": len(paths),
            "handover_hits": len(h_idx),
            "handover_ranks": h_idx,
            "handover_ages_days": ages,
            "top1_is_handover": bool(paths and _HANDOVER_RE.search(paths[0])),
        })

    summary = {
        "measures": "what a replayed query WOULD retrieve, not what anyone actually retrieved",
        "queries": len(QUERIES),
        "limit": args.limit,
        "total_hits": total_hits,
        "handover_hits": total_handover_hits,
        "handover_share_pct": round(100 * total_handover_hits / total_hits, 1) if total_hits else 0.0,
        "queries_where_top1_is_handover": top1_handover,
        "handover_hits_by_age": dict(age_hits),
    }

    if args.json:
        print(json.dumps({"summary": summary, "per_query": per_query}, indent=2))
        return 0

    print("PROBE — replayed queries, not observed usage\n")
    for r in per_query:
        if "error" in r:
            print(f"  ERROR  {r['query'][:60]}: {r['error'][:60]}")
            continue
        flag = " TOP1" if r["top1_is_handover"] else ""
        print(f"  {r['handover_hits']:>2}/{r['n_hits']:<3} handover hits{flag:<5}  {r['query'][:58]}")
        if r["handover_ages_days"]:
            print(f"          ages(d): {r['handover_ages_days']}  ranks: {r['handover_ranks']}")
    print("\nSUMMARY")
    for k, v in summary.items():
        print(f"  {k}: {v}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
