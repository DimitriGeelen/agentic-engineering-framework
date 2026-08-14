#!/usr/bin/env python3
"""G-064 closure-readiness gauge — substrate-aware check.

G-064 (orchestrator substrate has zero production consumers) status_notes
name `route_cache.json` as the closure precondition artefact. That file
does NOT exist on disk on this host — the actual substrate is
`.context/dispatches.jsonl` + `.context/dispatch-outcomes.jsonl`
(post T-1687 / T-1697 / T-1749 substrate consolidation). This script
reads the real substrate and reports closure readiness mechanically.

Closure precondition (per concerns.yaml G-064 status_notes 2026-05-05):
  - escalation-triage dispatches present in dispatches.jsonl
  - timestamps spread across >= 3 distinct dates
  - those dates contain firings at the scheduled cron hour
    (5:33 UTC, +/- 5 min window for jitter)
  - i.e. NOT all from the manual T-1727 backfill or --force re-runs

Synthetic dispatches (T-stress-* prefix per T-1712) are excluded.

Two cron-fire evidence sources (T-1952, post-2026-05-20 incident):
  1. dispatch.jsonl rows with ts in cron window  (primary — strongest signal)
  2. .context/working/escalation-drift-LATEST-v0.5.yaml `generated` field
     (fallback — catches idempotency-saturation case where cron correctly
     no-ops because manual runs filled the 7-day skip window)

The v0.5 yaml is rewritten on every cron fire regardless of whether
candidates were dispatched. Reading its `generated` timestamp lets the
gauge detect a cron-fire whose dispatched=0 due to skipped_idempotent>0.
Without this, idempotency saturation makes correctly-firing crons
indistinguishable from a broken cron — exactly the G-064 signature
(substrate exists, observability lies). Only the most-recent fire is
detected via this fallback (yaml is overwritten).

Cron TZ semantics (T-1953): crontab `33 5 * * *` is interpreted in LOCAL
time. To match real cron fires on non-UTC hosts (e.g. Europe/Amsterdam +02
summer → cron fires at UTC 03:33), `_is_cron_firing` converts the
dispatch timestamp to the system local TZ before comparing against
`CRON_HOUR_LOCAL:CRON_MIN_LOCAL`. Tests pin `TZ=UTC` via the
`enforce_utc_tz` autouse fixture so they remain portable across runner
TZs. Origin: T-1952 surfaced the bug via v0.5 LATEST fallback; T-1953
fixed it.

Usage:
  python3 tools/g064-readiness.py            # human-readable
  python3 tools/g064-readiness.py --json     # machine-readable
  python3 tools/g064-readiness.py --strict   # exit 1 if not ready

Exit codes:
  0 = report emitted; readiness state shown
  1 = not ready AND --strict was passed
  2 = substrate file missing or malformed
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

CRON_HOUR_LOCAL = 5
CRON_MIN_LOCAL = 33
CRON_WINDOW_MIN = 5
CLOSURE_DATE_THRESHOLD = 3
SYNTHETIC_PREFIX = "T-stress-"
WORKFLOW = "escalation-triage"


def _parse_ts(ts: str) -> datetime | None:
    if not ts or not isinstance(ts, str):
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None


def _is_cron_firing(dt: datetime) -> bool:
    """True if dt is within +/- CRON_WINDOW_MIN of CRON_HOUR_LOCAL:CRON_MIN_LOCAL.

    Converts dt to system local TZ before comparing. crontab schedules are
    LOCAL-time (T-1953); on non-UTC hosts the dispatch row's UTC timestamp
    must be projected into local time to match the cron window correctly.
    """
    local = dt.astimezone()
    target = CRON_HOUR_LOCAL * 60 + CRON_MIN_LOCAL
    actual = local.hour * 60 + local.minute
    return abs(actual - target) <= CRON_WINDOW_MIN


def _read_dispatches(path: Path) -> list[dict]:
    rows: list[dict] = []
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


def _read_v0_5_latest(path: Path | None) -> dict | None:
    """Read the v0.5 LATEST yaml as cron-fire fallback evidence (T-1952).

    Returns a dict with `generated`, `dispatched`, `skipped_idempotent` when
    the file exists and parses; None when missing or unparseable. Uses a tiny
    line-grep parser instead of pyyaml so the gauge stays dependency-free.
    """
    if path is None or not path.is_file():
        return None
    try:
        text = path.read_text()
    except OSError:
        return None
    result: dict = {}
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("generated:"):
            val = line.split(":", 1)[1].strip()
            result["generated"] = val.strip("'\"")
        elif line.startswith("dispatched:"):
            try:
                result["dispatched"] = int(line.split(":", 1)[1].strip())
            except ValueError:
                pass
        elif line.startswith("skipped_idempotent:"):
            try:
                result["skipped_idempotent"] = int(line.split(":", 1)[1].strip())
            except ValueError:
                pass
    return result if "generated" in result else None


def assess(rows: list[dict], v0_5_latest: dict | None = None) -> dict:
    """Return readiness assessment dict from dispatch rows + optional v0.5 LATEST.

    `v0_5_latest` is the dict from `_read_v0_5_latest` or None. When supplied
    and its `generated` timestamp falls within the cron window, its date is
    added to cron_firing_dates (T-1952: idempotency-saturation fallback).
    """
    cron_dates: set[str] = set()
    manual_dates: set[str] = set()
    cron_count = 0
    manual_count = 0
    synthetic_skipped = 0
    total = 0
    earliest: str | None = None
    latest: str | None = None

    for r in rows:
        if r.get("task_type") != WORKFLOW:
            continue
        task_id = r.get("task_id", "") or ""
        if task_id.startswith(SYNTHETIC_PREFIX):
            synthetic_skipped += 1
            continue
        ts = r.get("ts", "")
        dt = _parse_ts(ts)
        if dt is None:
            continue
        total += 1
        date_str = dt.astimezone(timezone.utc).strftime("%Y-%m-%d")
        if earliest is None or ts < earliest:
            earliest = ts
        if latest is None or ts > latest:
            latest = ts
        if _is_cron_firing(dt):
            cron_dates.add(date_str)
            cron_count += 1
        else:
            manual_dates.add(date_str)
            manual_count += 1

    # T-1952: v0.5 LATEST fallback. A v0.5 cron fire that no-ops due to
    # idempotency saturation still rewrites the LATEST yaml — its `generated`
    # timestamp is reliable cron-fire evidence even when dispatched=0.
    v0_5_generated: str | None = None
    v0_5_dispatched: int | None = None
    v0_5_skipped: int | None = None
    v0_5_date_added = False
    if v0_5_latest:
        v0_5_generated = v0_5_latest.get("generated")
        v0_5_dispatched = v0_5_latest.get("dispatched")
        v0_5_skipped = v0_5_latest.get("skipped_idempotent")
        dt = _parse_ts(v0_5_generated or "")
        if dt is not None and _is_cron_firing(dt):
            date_str = dt.astimezone(timezone.utc).strftime("%Y-%m-%d")
            if date_str not in cron_dates:
                cron_dates.add(date_str)
                v0_5_date_added = True

    ready = len(cron_dates) >= CLOSURE_DATE_THRESHOLD
    return {
        "workflow": WORKFLOW,
        "total_dispatches": total,
        "cron_firings": cron_count,
        "manual_runs": manual_count,
        "synthetic_skipped": synthetic_skipped,
        "cron_firing_dates": sorted(cron_dates),
        "manual_run_dates": sorted(manual_dates),
        "earliest_ts": earliest,
        "latest_ts": latest,
        "closure_threshold_dates": CLOSURE_DATE_THRESHOLD,
        "cron_window": f"{CRON_HOUR_LOCAL:02d}:{CRON_MIN_LOCAL:02d} LOCAL +/- {CRON_WINDOW_MIN} min",
        "v0_5_last_generated": v0_5_generated,
        "v0_5_last_dispatched": v0_5_dispatched,
        "v0_5_last_skipped_idempotent": v0_5_skipped,
        "v0_5_date_added_to_cron": v0_5_date_added,
        "ready": ready,
        "verdict": "READY" if ready else "NOT_READY",
    }


def render_human(a: dict) -> str:
    """Render assessment as a human-readable block."""
    lines = []
    lines.append("G-064 closure-readiness gauge")
    lines.append("=" * 32)
    lines.append(f"Workflow:           {a['workflow']}")
    lines.append(f"Cron schedule:      {a['cron_window']}")
    lines.append(f"Closure threshold:  >= {a['closure_threshold_dates']} distinct cron-firing dates")
    lines.append("")
    lines.append(f"Total dispatches:   {a['total_dispatches']}")
    lines.append(f"  Cron firings:     {a['cron_firings']} across {len(a['cron_firing_dates'])} date(s)")
    lines.append(f"  Manual runs:      {a['manual_runs']} across {len(a['manual_run_dates'])} date(s)")
    if a["synthetic_skipped"]:
        lines.append(f"  Synthetic skipped:{a['synthetic_skipped']}")
    lines.append("")
    if a.get("v0_5_last_generated"):
        marker = " (+1 cron-firing date)" if a.get("v0_5_date_added_to_cron") else ""
        lines.append(f"v0.5 LATEST:        {a['v0_5_last_generated']}{marker}")
        d = a.get("v0_5_last_dispatched")
        s = a.get("v0_5_last_skipped_idempotent")
        if d is not None or s is not None:
            lines.append(f"  dispatched={d if d is not None else '?'} "
                         f"skipped_idempotent={s if s is not None else '?'}")
        if d == 0 and s and s > 0:
            lines.append(f"  NOTE: idempotency saturation — cron fired but {s} candidates")
            lines.append("        were already scanned within 7d window. Avoid manual re-runs")
            lines.append("        of tools/escalation-scan-v0.5.py to let cron own the workload.")
        lines.append("")
    if a["cron_firing_dates"]:
        lines.append("Cron-firing dates: " + ", ".join(a["cron_firing_dates"]))
    else:
        lines.append("Cron-firing dates: (none)")
    if a["manual_run_dates"]:
        lines.append("Manual-run dates:  " + ", ".join(a["manual_run_dates"]))
    lines.append("")
    if a["ready"]:
        lines.append(
            f"VERDICT: READY -- {len(a['cron_firing_dates'])} cron-firing dates "
            f"meets threshold ({a['closure_threshold_dates']})."
        )
        lines.append(
            "Action: human can close G-064 via Watchtower (gap is satisfied; "
            "autonomous workload is exercising the substrate)."
        )
    else:
        needed = a["closure_threshold_dates"] - len(a["cron_firing_dates"])
        lines.append(
            f"VERDICT: NOT_READY -- need {needed} more distinct cron-firing date(s) "
            f"({len(a['cron_firing_dates'])}/{a['closure_threshold_dates']})."
        )
        lines.append(
            f"Action: wait for next cron firings at {a['cron_window']}, re-run this gauge."
        )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--json", action="store_true", help="emit JSON instead of human text")
    parser.add_argument("--strict", action="store_true", help="exit 1 if not ready")
    parser.add_argument(
        "--dispatches",
        default=None,
        help="path to dispatches.jsonl (default: $PROJECT_ROOT/.context/dispatches.jsonl)",
    )
    parser.add_argument(
        "--v0-5-latest",
        default=None,
        help="path to escalation-drift-LATEST-v0.5.yaml (default: "
             "$PROJECT_ROOT/.context/working/escalation-drift-LATEST-v0.5.yaml)",
    )
    args = parser.parse_args(argv)

    project_root = os.environ.get("PROJECT_ROOT") or str(Path(__file__).resolve().parents[1])
    if args.dispatches:
        path = Path(args.dispatches)
    else:
        path = Path(project_root) / ".context" / "dispatches.jsonl"

    if args.v0_5_latest:
        v0_5_path: Path | None = Path(args.v0_5_latest)
    else:
        v0_5_path = Path(project_root) / ".context" / "working" / "escalation-drift-LATEST-v0.5.yaml"

    if not path.is_file():
        msg = {"error": "dispatches.jsonl not found", "path": str(path)}
        if args.json:
            print(json.dumps(msg))
        else:
            print(f"ERROR: dispatches.jsonl not found at {path}", file=sys.stderr)
        return 2

    try:
        rows = _read_dispatches(path)
    except OSError as e:
        if args.json:
            print(json.dumps({"error": str(e), "path": str(path)}))
        else:
            print(f"ERROR: cannot read {path}: {e}", file=sys.stderr)
        return 2

    v0_5_latest = _read_v0_5_latest(v0_5_path)
    a = assess(rows, v0_5_latest=v0_5_latest)
    if args.json:
        print(json.dumps(a, indent=2))
    else:
        print(render_human(a))

    if args.strict and not a["ready"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
