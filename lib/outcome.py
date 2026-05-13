#!/usr/bin/env python3
"""
Outcome enrichment — default evaluator + back-prop + read-path join.

Append-only design (T-1690 GO with design pivot, 2026-05-03):
  - dispatches.jsonl       — append-only, one row per dispatch (T-1696 writes)
  - dispatch-outcomes.jsonl — NEW append-only, one row per outcome event,
                              keyed by dispatch_id; v2 read-path joins
  - This eliminates cross-row last-writer-wins exposure entirely.

Default evaluator parses `## Verification` + `### Agent` ACs from a task
file, runs the verification commands, counts ticked vs total ACs, returns
a structured outcome dict.

Back-prop is fired by `update-task.sh` on `--status work-completed`. It
finds matching dispatch_ids in dispatches.jsonl and appends one outcome
row per match. Failure of back-prop is best-effort: it logs but does NOT
block task completion (decoupling: outcome telemetry is desirable, not
load-bearing for the task lifecycle).

Origin spike: docs/reports/T-1690-spikes/eval_backprop_spike.py
Build task: T-1697.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional


PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", os.getcwd()))
DISPATCHES_LOG = PROJECT_ROOT / ".context" / "dispatches.jsonl"
OUTCOMES_LOG = PROJECT_ROOT / ".context" / "dispatch-outcomes.jsonl"
TASKS_ACTIVE = PROJECT_ROOT / ".tasks" / "active"
TASKS_COMPLETED = PROJECT_ROOT / ".tasks" / "completed"

OUTCOME_SCHEMA_VERSION = 1


# ---------------------------------------------------------------------------
# Default evaluator
# ---------------------------------------------------------------------------
def parse_task_file(task_path: Path) -> Dict[str, Any]:
    """Extract Verification commands + Agent AC checkbox states.

    Returns:
      verification_commands: list[str]   — non-comment lines from ## Verification
      ac_total:              int         — total Agent AC checkboxes
      ac_checked:            int         — AC checkboxes marked [x]
    """
    text = task_path.read_text()

    ver_match = re.search(
        r"^## Verification\s*\n(.*?)(?=^## |\Z)", text, re.MULTILINE | re.DOTALL
    )
    ver_block = ver_match.group(1) if ver_match else ""
    ver_commands = [
        line.strip()
        for line in ver_block.splitlines()
        if line.strip() and not line.strip().startswith("#")
    ]

    ac_match = re.search(
        r"^### Agent\s*\n(.*?)(?=^### |\Z)",
        text,
        re.MULTILINE | re.DOTALL,
    )
    ac_block = ac_match.group(1) if ac_match else ""
    ac_lines = [
        m.group(1) for m in re.finditer(r"^- \[([x ])\]", ac_block, re.MULTILINE)
    ]
    return {
        "verification_commands": ver_commands,
        "ac_total": len(ac_lines),
        "ac_checked": sum(1 for c in ac_lines if c == "x"),
    }


def find_task_file(task_id: str) -> Optional[Path]:
    """Look up a task file in active/ then completed/."""
    for d in (TASKS_ACTIVE, TASKS_COMPLETED):
        if d.is_dir():
            matches = list(d.glob(f"{task_id}-*.md"))
            if matches:
                return matches[0]
    return None


def default_evaluator(task_id: str, *, run_verification: bool = True) -> Dict[str, Any]:
    """Run Verification + count Agent ACs. Returns outcome dict.

    run_verification=False: skip running shell commands (test mode + speed
    optimization for hook path). The caller is responsible for running
    verification separately (the framework's update-task.sh already runs
    them via the P-011 gate before this evaluator is called).
    """
    task_file = find_task_file(task_id)
    if not task_file:
        return {
            "schema_version": OUTCOME_SCHEMA_VERSION,
            "verification_passed": False,
            "ac_satisfied": False,
            "ac_total": 0,
            "ac_checked": 0,
            "verification_failed_commands": [],
            "notes": f"task file not found for {task_id}",
            "evaluator": "default",
        }
    parsed = parse_task_file(task_file)

    failed: List[str] = []
    if run_verification:
        for cmd in parsed["verification_commands"]:
            try:
                r = subprocess.run(
                    ["bash", "-c", cmd],
                    cwd=PROJECT_ROOT,
                    capture_output=True,
                    timeout=30,
                )
                if r.returncode != 0:
                    failed.append(f"exit={r.returncode}: {cmd[:80]}")
            except subprocess.TimeoutExpired:
                failed.append(f"timeout: {cmd[:80]}")

    return {
        "schema_version": OUTCOME_SCHEMA_VERSION,
        "verification_passed": len(failed) == 0,
        "ac_satisfied": parsed["ac_checked"] == parsed["ac_total"]
        and parsed["ac_total"] > 0,
        "ac_total": parsed["ac_total"],
        "ac_checked": parsed["ac_checked"],
        "verification_failed_commands": failed,
        "notes": f"evaluated {task_file.name}",
        "evaluator": "default",
    }


# ---------------------------------------------------------------------------
# Back-prop (append-only)
# ---------------------------------------------------------------------------
def find_dispatch_ids(task_id: str) -> List[str]:
    """List dispatch_ids in dispatches.jsonl matching the task_id."""
    if not DISPATCHES_LOG.exists():
        return []
    ids: List[str] = []
    try:
        with DISPATCHES_LOG.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if row.get("task_id") == task_id and row.get("dispatch_id"):
                    ids.append(row["dispatch_id"])
    except OSError:
        return []
    return ids


def backprop_outcome(task_id: str, outcome: Dict[str, Any]) -> int:
    """Append one outcome row per matching dispatch_id to dispatch-outcomes.jsonl.

    Returns count of outcome rows appended (0 if no matching dispatches).

    Append-only design: NEVER touches dispatches.jsonl. Concurrent
    back-prop on distinct task_ids is naturally safe because:
      - find_dispatch_ids is read-only on dispatches.jsonl
      - O_APPEND is atomic for small writes (<= PIPE_BUF, ~4KB) on POSIX
      - Each outcome row is a single line (well under 4KB)

    Failure of OUTCOMES_LOG write logs to stderr but does not raise — this
    is by design (the hook is best-effort, not load-bearing).
    """
    dispatch_ids = find_dispatch_ids(task_id)
    if not dispatch_ids:
        return 0

    ts = datetime.now(timezone.utc).isoformat()
    rows = [
        {
            "schema_version": OUTCOME_SCHEMA_VERSION,
            "ts": ts,
            "dispatch_id": did,
            "task_id": task_id,
            "outcome": outcome,
        }
        for did in dispatch_ids
    ]
    try:
        OUTCOMES_LOG.parent.mkdir(parents=True, exist_ok=True)
        with OUTCOMES_LOG.open("a") as f:
            for row in rows:
                f.write(json.dumps(row) + "\n")
    except OSError as e:
        sys.stderr.write(f"outcome: backprop write failed: {e}\n")
        return 0
    return len(rows)


# ---------------------------------------------------------------------------
# Read-path join (dispatches.jsonl × dispatch-outcomes.jsonl)
# ---------------------------------------------------------------------------
def read_dispatch(dispatch_id_prefix: str) -> Optional[Dict[str, Any]]:
    """Look up a dispatch by id-prefix, attach the latest outcome from
    outcomes log. Returns merged dict or None if no dispatch matched."""
    dispatch_row: Optional[Dict[str, Any]] = None
    if DISPATCHES_LOG.exists():
        with DISPATCHES_LOG.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if row.get("dispatch_id", "").startswith(dispatch_id_prefix):
                    dispatch_row = row
    if not dispatch_row:
        return None

    full_id = dispatch_row["dispatch_id"]
    latest_outcome: Optional[Dict[str, Any]] = None
    if OUTCOMES_LOG.exists():
        with OUTCOMES_LOG.open() as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if row.get("dispatch_id") == full_id:
                    latest_outcome = row
    merged = dict(dispatch_row)
    if latest_outcome:
        merged["outcome_event"] = latest_outcome
    return merged


def _dispatch_terminal_map() -> Dict[str, Dict[str, Any]]:
    """Build {dispatch_id: terminal_event} from dispatches.jsonl.

    Skips rows without terminal_event. Single-pass; O(n) build, O(1) lookup
    afterwards. Empty dict if log missing or no row carries the field.
    (T-1782 — pair to T-1780 / T-1781 surfaces of T-1777-persisted data.)
    """
    out: Dict[str, Dict[str, Any]] = {}
    if not DISPATCHES_LOG.exists():
        return out
    with DISPATCHES_LOG.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            te = row.get("terminal_event")
            did = row.get("dispatch_id")
            if did and isinstance(te, dict) and te.get("type"):
                out[did] = te
    return out


def _terminal_suffix(te: Optional[Dict[str, Any]]) -> str:
    """Render `terminal=<type>(<suffix>)` per T-1781 idiom; "" if absent.

    T-1805 / ADR-0004: `pause_requested` events get a `(question="...")`
    suffix when the Worker provided a question — gives operators scan-time
    triage signal without cracking open events.jsonl.
    """
    if not isinstance(te, dict) or not te.get("type"):
        return ""
    ttype = te["type"]
    suffix = ""
    if ttype == "error" and "retryable" in te:
        suffix = "(retryable)" if te["retryable"] else "(non-retryable)"
    elif ttype == "result" and te.get("is_error") is True:
        suffix = "(is_error)"
    elif ttype == "pause_requested":
        # T-1805: short question summary for at-a-glance triage
        q = (te.get("question") or "").strip()
        if q:
            if len(q) > 40:
                q = q[:37] + "..."
            suffix = f"(question={q!r})"
    return f" terminal={ttype}{suffix}"


def list_outcomes_for_task(task_id: str) -> List[Dict[str, Any]]:
    """Return all outcome rows for a task_id from outcomes log."""
    if not OUTCOMES_LOG.exists():
        return []
    rows = []
    with OUTCOMES_LOG.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("task_id") == task_id:
                rows.append(row)
    return rows


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def cmd_evaluate(args: argparse.Namespace) -> int:
    outcome = default_evaluator(args.task_id, run_verification=not args.skip_verification)
    if args.json:
        print(json.dumps(outcome, indent=2))
    else:
        print(f"task:                 {args.task_id}")
        print(f"verification_passed:  {outcome['verification_passed']}")
        print(f"ac_satisfied:         {outcome['ac_satisfied']}")
        print(f"ac_checked/total:     {outcome['ac_checked']}/{outcome['ac_total']}")
        if outcome["verification_failed_commands"]:
            print(f"failed_commands:      {len(outcome['verification_failed_commands'])}")
            for f in outcome["verification_failed_commands"][:5]:
                print(f"  - {f}")
        print(f"notes:                {outcome['notes']}")
    return 0 if outcome["verification_passed"] and outcome["ac_satisfied"] else 1


def cmd_backprop(args: argparse.Namespace) -> int:
    outcome = default_evaluator(args.task_id, run_verification=not args.skip_verification)
    n = backprop_outcome(args.task_id, outcome)
    if args.json:
        print(json.dumps({"task_id": args.task_id, "outcomes_appended": n, "outcome": outcome}, indent=2))
    else:
        print(f"task:               {args.task_id}")
        print(f"outcomes appended:  {n}")
        print(f"target:             {OUTCOMES_LOG.relative_to(PROJECT_ROOT)}")
    # Always exit 0 — best-effort hook semantics
    return 0


def cmd_read(args: argparse.Namespace) -> int:
    n = getattr(args, "tail_events", None)
    if n is not None and n < 1:
        print("outcome: --tail-events N must be >= 1", file=sys.stderr)
        return 1
    merged = read_dispatch(args.dispatch_id)
    if not merged:
        print(f"outcome: no dispatch matching '{args.dispatch_id}'", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(merged, indent=2))
    else:
        print(f"dispatch_id:    {merged.get('dispatch_id')}")
        print(f"ts:             {merged.get('ts')}")
        print(f"task_id:        {merged.get('task_id')}")
        print(f"task_type:      {merged.get('task_type')}")
        print(f"worker_kind:    {merged.get('worker_kind')}")
        print(f"model:          {merged.get('model')}")
        # T-1780: surface terminal_event sub-fields (mirrors T-1778 pattern
        # in resolver cmd_run / cmd_explain). Quiet on agent.done / missing.
        te = merged.get("terminal_event")
        if isinstance(te, dict) and te.get("type"):
            print(f"terminal:       {te['type']}")
            if te["type"] == "error" and "retryable" in te:
                print(f"retryable:      {te['retryable']}")
            elif te["type"] == "result" and "is_error" in te:
                print(f"is_error:       {te['is_error']}")
            elif te["type"] == "pause_requested":
                # T-1805 / ADR-0004: pause-specific fields (one per line)
                if te.get("question"):
                    print(f"question:       {te['question']}")
                a = te.get("assessment")
                if isinstance(a, dict):
                    if "severity" in a:
                        print(f"severity:       {a['severity']}")
                    if "likelihood" in a:
                        print(f"likelihood:     {a['likelihood']}")
                elif a:
                    print(f"assessment:     {a}")
                if te.get("state_ref"):
                    print(f"state_ref:      {te['state_ref']}")
        oe = merged.get("outcome_event")
        if oe:
            o = oe.get("outcome", {})
            print(f"outcome_ts:     {oe.get('ts')}")
            print(f"  verification_passed: {o.get('verification_passed')}")
            print(f"  ac_satisfied:        {o.get('ac_satisfied')}")
            print(f"  ac_checked/total:    {o.get('ac_checked')}/{o.get('ac_total')}")
        else:
            print("outcome_event:  (none — back-prop has not fired)")
        # T-1783: optional --tail-events N tail of <blob_dir>/events.jsonl.
        # Opt-in (default behavior unchanged when flag omitted).
        n = getattr(args, "tail_events", None)
        if n is not None:
            _render_event_tail(merged, n)
    return 0


def _event_summary(event: Dict[str, Any]) -> str:
    """Render a single event as `<type> (<key-summary>)` per T-1783 idiom."""
    etype = event.get("type", "?")
    summary = ""
    if etype == "error":
        retry = event.get("retryable")
        msg = (event.get("message") or "")[:60]
        parts = []
        if retry is not None:
            parts.append(f"retryable={retry}")
        if msg:
            parts.append(f"message={msg!r}")
        summary = ", ".join(parts)
    elif etype == "result":
        is_err = event.get("is_error")
        if is_err is not None:
            summary = f"is_error={is_err}"
    elif etype == "pause_requested":
        # T-1805: question summary for event-tail visibility
        q = (event.get("question") or "")[:40]
        if q:
            summary = f"question={q!r}"
    elif etype == "agent.done":
        summary = ""
    else:
        # Unknown type — fall back to a truncated json dump for visibility.
        try:
            blob = json.dumps({k: v for k, v in event.items() if k != "type"})
            summary = blob[:60]
        except (TypeError, ValueError):
            summary = ""
    if summary:
        return f"{etype} ({summary})"
    return etype


def _render_event_tail(merged: Dict[str, Any], n: int) -> None:
    """Print the last N events from <blob_dir>/events.jsonl as a summary list."""
    blob_dir = merged.get("blob_dir")
    if not blob_dir:
        print("events:         (no event log for this dispatch)")
        return
    events_path = Path(blob_dir) / "events.jsonl"
    if not events_path.exists():
        print("events:         (no event log for this dispatch)")
        return
    events: List[Dict[str, Any]] = []
    with events_path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                continue  # T-1783: malformed lines skipped, do not crash
    tail = events[-n:]
    print(f"events (last {len(tail)} of {len(events)}):")
    for ev in tail:
        print(f"  · {_event_summary(ev)}")


def cmd_list(args: argparse.Namespace) -> int:
    rows = list_outcomes_for_task(args.task_id)
    if args.json:
        print(json.dumps(rows, indent=2))
        return 0
    if not rows:
        print(f"(no outcome events for {args.task_id})")
        return 0
    # T-1782: one-pass build of {did → terminal_event}; lookup O(1) per row.
    term_map = _dispatch_terminal_map()
    for r in rows:
        o = r.get("outcome", {})
        ok = "✓" if o.get("verification_passed") and o.get("ac_satisfied") else "·"
        did = r.get("dispatch_id", "?")
        suffix = _terminal_suffix(term_map.get(did))
        print(
            f"{ok} {r.get('ts', '?')} [{did[:8]}] "
            f"ac={o.get('ac_checked', '?')}/{o.get('ac_total', '?')}"
            f"{suffix}"
        )
    return 0


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        prog="fw outcome",
        description="Default outcome evaluator + back-prop into dispatch-outcomes.jsonl",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    sp_e = sub.add_parser("evaluate", help="Run default evaluator on a task")
    sp_e.add_argument("task_id")
    sp_e.add_argument("--skip-verification", action="store_true",
                      help="Skip running ## Verification commands (count ACs only)")
    sp_e.add_argument("--json", action="store_true")
    sp_e.set_defaults(func=cmd_evaluate)

    sp_b = sub.add_parser("backprop", help="Evaluate task + append outcome rows")
    sp_b.add_argument("task_id")
    sp_b.add_argument("--skip-verification", action="store_true")
    sp_b.add_argument("--json", action="store_true")
    sp_b.set_defaults(func=cmd_backprop)

    sp_r = sub.add_parser("read", help="Read merged dispatch + latest outcome")
    sp_r.add_argument("dispatch_id", help="Dispatch UUID (or prefix)")
    sp_r.add_argument("--json", action="store_true")
    sp_r.add_argument("--tail-events", type=int, default=None,
                      metavar="N",
                      help="Tail last N events from <blob_dir>/events.jsonl (T-1783)")
    sp_r.set_defaults(func=cmd_read)

    sp_l = sub.add_parser("list", help="List all outcome events for a task")
    sp_l.add_argument("task_id")
    sp_l.add_argument("--json", action="store_true")
    sp_l.set_defaults(func=cmd_list)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
