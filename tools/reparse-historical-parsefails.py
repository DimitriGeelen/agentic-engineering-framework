#!/usr/bin/env python3
"""T-1756 — Re-parse historical PARSE-FAIL outcomes through the post-T-1748 parser.

Pre-T-1748 escalation-scan runs that hit a sloppy LLM envelope produced a
PARSE-FAIL outcome and stored the first 200 chars of raw LLM text in the
rationale field. T-1748 hardened parse_verdict_envelope so the same input now
yields a real verdict.

This tool walks .context/dispatch-outcomes.jsonl, finds every PARSE-FAIL with
evaluator = escalation-scan-v0.5, re-parses its rationale snippet, and appends
a corrective outcome row tagged `evaluator: escalation-scan-v0.5-replay` with a
`replayed_from` reference back to the original dispatch.

Idempotent: a replay row for a given (dispatch_id) means "already replayed" and
is skipped on subsequent runs. No mutation of original rows — only append.

Usage:
    python3 tools/reparse-historical-parsefails.py [--dry-run]
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

OUTCOMES_PATH = Path(".context/dispatch-outcomes.jsonl")
PARSER_PATH = Path("tools/escalation-scan-v0.5.py")
ORIGINAL_EVALUATOR = "escalation-scan-v0.5"
REPLAY_EVALUATOR = "escalation-scan-v0.5-replay"


def _load_parser():
    spec = importlib.util.spec_from_file_location("esc_v05", str(PARSER_PATH))
    if spec is None or spec.loader is None:
        raise RuntimeError(f"could not load parser from {PARSER_PATH}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _read_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    rows = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return rows


def _already_replayed_ids(rows: list[dict]) -> set[str]:
    """Dispatch IDs that already have a replay row — skip on re-run."""
    seen = set()
    for r in rows:
        if r.get("outcome", {}).get("evaluator") == REPLAY_EVALUATOR:
            origin = r.get("outcome", {}).get("replayed_from")
            if origin:
                seen.add(origin)
    return seen


def _candidates(rows: list[dict], skip: set[str]) -> list[dict]:
    """PARSE-FAIL rows from the original evaluator that haven't been replayed."""
    out = []
    for r in rows:
        oc = r.get("outcome", {}) or {}
        if oc.get("evaluator") != ORIGINAL_EVALUATOR:
            continue
        if oc.get("verdict") != "PARSE-FAIL":
            continue
        if r.get("dispatch_id") in skip:
            continue
        out.append(r)
    return out


def _build_replay_row(original: dict, recovered: dict) -> dict:
    """Append-only row with replay metadata. Original row is untouched."""
    return {
        "schema_version": 1,
        "ts": datetime.now(timezone.utc).isoformat(),
        "dispatch_id": original["dispatch_id"],
        "task_id": original.get("task_id"),
        "outcome": {
            "schema_version": 1,
            "evaluator": REPLAY_EVALUATOR,
            "verdict": recovered["verdict"],
            "rationale": recovered.get("rationale", "")
            or "(replayed from truncated 200-char snippet — rationale empty)",
            "confidence": recovered.get("confidence", 0.0),
            "replayed_from": original["dispatch_id"],
            "replayed_at": datetime.now(timezone.utc).isoformat(),
            "replay_reason": "T-1748 hardened parse_verdict_envelope; T-1756 back-prop",
        },
    }


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true",
                   help="Report counts; do not append corrective rows.")
    args = p.parse_args()

    parser = _load_parser()
    rows = _read_jsonl(OUTCOMES_PATH)
    skip = _already_replayed_ids(rows)
    candidates = _candidates(rows, skip)

    recovered_rows: list[dict] = []
    unrecoverable = 0
    for r in candidates:
        rationale = r.get("outcome", {}).get("rationale", "") or ""
        parsed = parser.parse_verdict_envelope(rationale)
        verdict = parsed.get("verdict") or "PARSE-FAIL"
        if verdict == "PARSE-FAIL":
            unrecoverable += 1
            continue
        recovered_rows.append(_build_replay_row(r, parsed))

    total = len(candidates)
    recoverable = len(recovered_rows)
    print(f"Scanned: {len(rows)} outcome rows")
    print(f"Already replayed (skipped): {len(skip)}")
    print(f"PARSE-FAIL candidates: {total}")
    print(f"Recoverable: {recoverable}/{total}")
    print(f"Unrecoverable: {unrecoverable}/{total}")

    if not recovered_rows:
        # Single canonical message for the idempotent / no-op path so callers
        # can grep for it (verification gate uses this).
        if total == 0 and skip:
            print("Idempotent: no new corrective outcomes (all candidates already replayed).")
        elif total == 0:
            print("Idempotent: no new corrective outcomes (no PARSE-FAIL candidates).")
        else:
            print(f"Idempotent: no new corrective outcomes ({total} unrecoverable, none replayable).")
        return 0

    if args.dry_run:
        print("\nDry-run preview (not written):")
        for r in recovered_rows:
            oc = r["outcome"]
            print(f"  {r['dispatch_id'][:8]} {r.get('task_id'):>6} → {oc['verdict']}")
        return 0

    with OUTCOMES_PATH.open("a") as f:
        for r in recovered_rows:
            f.write(json.dumps(r) + "\n")
    print(f"Wrote {recoverable} corrective outcome row(s) to {OUTCOMES_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
