#!/usr/bin/env python3
"""Regenerate the dispatch-outcome table cited in CLAUDE.md §Execution Model.

Joins .context/dispatches.jsonl to .context/dispatch-outcomes.jsonl on
dispatch_id, maps each dispatch's task_id to that task's workflow_type from
frontmatter, and reports verification/AC pass rates per workflow_type.

CLAUDE.md instructs agents to regenerate rather than trust the snapshot in the
doc. This is that regeneration path.

Origin: T-3037. The table's headline result — inception dispatches produce zero
passing outcomes — is what grounds the "dispatch the review, never the
exploration" rule.

Usage:
    python3 tools/dispatch_outcome_table.py            # human-readable table
    python3 tools/dispatch_outcome_table.py --json     # machine-readable
"""

import collections
import glob
import json
import os
import re
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DISPATCHES = os.path.join(PROJECT_ROOT, ".context", "dispatches.jsonl")
OUTCOMES = os.path.join(PROJECT_ROOT, ".context", "dispatch-outcomes.jsonl")

_WT_RE = re.compile(r"^workflow_type:\s*(\S+)", re.M)
# Task files are T-<id>-<slug>.md; the id is the first two hyphen-joined fields.
_TASK_ID_FIELDS = 2


def load_workflow_types():
    """task_id -> workflow_type, from active/ and completed/ frontmatter."""
    wt = {}
    for pattern in ("active", "completed"):
        for path in glob.glob(os.path.join(PROJECT_ROOT, ".tasks", pattern, "T-*.md")):
            task_id = "-".join(os.path.basename(path).split("-")[:_TASK_ID_FIELDS])
            try:
                with open(path, encoding="utf-8", errors="replace") as fh:
                    head = fh.read(1500)
            except OSError:
                continue
            m = _WT_RE.search(head)
            if m:
                wt[task_id] = m.group(1).strip()
    return wt


def _read_jsonl(path):
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except (ValueError, TypeError):
                continue


def load_dispatches():
    """dispatch_id -> record. Later records win; only full records (with ts)."""
    out = {}
    for rec in _read_jsonl(DISPATCHES):
        did = rec.get("dispatch_id")
        if did and rec.get("ts"):
            out[did] = rec
    return out


def load_outcomes():
    """dispatch_id -> outcome dict. Later events win."""
    out = {}
    for rec in _read_jsonl(OUTCOMES):
        did = rec.get("dispatch_id")
        if did:
            out[did] = rec.get("outcome") or {}
    return out


def build_table():
    wt = load_workflow_types()
    dispatches = load_dispatches()
    outcomes = load_outcomes()

    rows = collections.defaultdict(lambda: {"n": 0, "verified": 0, "ac": 0})
    for did, rec in dispatches.items():
        task_id = rec.get("task_id", "")
        # T-stress-* are synthetic load-test dispatches, excluded from headline.
        if task_id.startswith("T-stress"):
            continue
        outcome = outcomes.get(did)
        if outcome is None:
            continue
        key = wt.get(task_id, "(unknown)")
        row = rows[key]
        row["n"] += 1
        if outcome.get("verification_passed"):
            row["verified"] += 1
        if outcome.get("ac_satisfied"):
            row["ac"] += 1

    return {
        "dispatches_total": len(dispatches),
        "outcomes_total": len(outcomes),
        "joined": sum(r["n"] for r in rows.values()),
        "by_workflow_type": {
            k: {
                **v,
                "verified_pct": round(100.0 * v["verified"] / v["n"], 1) if v["n"] else 0.0,
                "ac_pct": round(100.0 * v["ac"] / v["n"], 1) if v["n"] else 0.0,
            }
            for k, v in rows.items()
        },
    }


def linkage_counts():
    """How many dispatch records carry retry/parent lineage (T-3037 gap check)."""
    retry = parent = total = 0
    for rec in _read_jsonl(DISPATCHES):
        if not rec.get("ts"):
            continue
        total += 1
        if rec.get("retry_of_dispatch_id"):
            retry += 1
        if rec.get("parent_dispatch_id"):
            parent += 1
    return {"total": total, "retry_of_dispatch_id": retry, "parent_dispatch_id": parent}


def main():
    table = build_table()
    linkage = linkage_counts()

    if "--json" in sys.argv:
        print(json.dumps({"table": table, "linkage": linkage}, indent=2, sort_keys=True))
        return 0

    print(
        f"Dispatch outcomes — {table['dispatches_total']} dispatches, "
        f"{table['outcomes_total']} outcome events, {table['joined']} joined"
    )
    print()
    print(f"{'workflow_type':22} {'N':>5} {'verif pass':>14} {'AC satisfied':>14}")
    print("-" * 58)
    rows = sorted(table["by_workflow_type"].items(), key=lambda kv: -kv[1]["n"])
    for name, r in rows:
        print(
            f"{name:22} {r['n']:5} "
            f"{r['verified']:6} ({r['verified_pct']:5.1f}%) "
            f"{r['ac']:6} ({r['ac_pct']:5.1f}%)"
        )
    print()
    print("Dispatch lineage (T-3037 telemetry gap):")
    print(f"  retry_of_dispatch_id populated: {linkage['retry_of_dispatch_id']}/{linkage['total']}")
    print(f"  parent_dispatch_id  populated: {linkage['parent_dispatch_id']}/{linkage['total']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
