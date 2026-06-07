#!/usr/bin/env python3
"""
workflow_coverage — audit-time check for workflow → dispatcher coverage.

T-1798 prevention slice: T-1776 surfaced a workflow whose declared
``worker_kind`` had no spawn handler (``default.yaml`` → ``TermLink``,
which raised ``NotImplementedError`` at runtime). The fix landed in T-1797
(added the handler), but the structural blind spot remains: nothing in the
substrate flags this class of gap before it fires.

This helper closes the blind spot. It cross-references every workflow's
declared ``worker_kind`` against the actually-routable set
(``lib.spawn._DISPATCHERS.keys()``) and against the declarable superset
(``lib.resolver.VALID_WORKER_KINDS``), then returns a structured report
for the audit script to render.

Decoupled from the audit driver so unit tests can pin behaviour without
spawning audit.sh.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path
from typing import Any, Dict


PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", os.getcwd()))
WORKFLOWS_DIR = PROJECT_ROOT / ".context" / "project" / "workflows"
DISPATCHES_JSONL = PROJECT_ROOT / ".context" / "dispatches.jsonl"
LIB_DIR = Path(__file__).resolve().parent

# T-1803: a workflow declared but not dispatched in this many days is "stale" —
# a maintenance signal (consider deprecating), not a runtime failure. Surfaced
# as audit WARN, not FAIL. Threshold picked as ≈ one quarter; param-injectable
# for tests, no config plumbing until pressure (T-819 pattern).
STALE_THRESHOLD_DAYS = 90


def _import_dispatcher_keys() -> set:
    """Read ``_DISPATCHERS.keys()`` from ``lib.spawn`` without side effects.

    spawn.py uses sibling-imports (sys.path insert); add lib/ to path before
    importing. Returns empty set on import failure so the caller can degrade
    gracefully (rather than crashing the audit).
    """
    if str(LIB_DIR) not in sys.path:
        sys.path.insert(0, str(LIB_DIR))
    try:
        import spawn  # noqa: PLC0415 — deferred import by design
    except Exception:
        return set()
    return set(getattr(spawn, "_DISPATCHERS", {}).keys())


def _import_valid_worker_kinds() -> set:
    """Read ``VALID_WORKER_KINDS`` from ``lib.resolver``. Same import
    contract as ``_import_dispatcher_keys``."""
    if str(LIB_DIR) not in sys.path:
        sys.path.insert(0, str(LIB_DIR))
    try:
        import resolver  # noqa: PLC0415
    except Exception:
        return set()
    return set(getattr(resolver, "VALID_WORKER_KINDS", set()))


def _parse_workflows(workflows_dir: Path) -> Dict[str, Dict[str, str]]:
    """Return ``{workflow_name: {"worker_kind", "provider"}}`` for every
    YAML file in ``workflows_dir``. Missing fields → empty string. Malformed
    YAML files are skipped.

    T-1800: provider field also parsed (used to flag pi workflows missing
    their required provider — `lib/spawn._spawn_pi` raises SpawnError when
    both envelope and workflow lack it).
    """
    import yaml  # local — lazy so module imports without PyYAML

    out: Dict[str, Dict[str, str]] = {}
    if not workflows_dir.is_dir():
        return out
    for path in sorted(workflows_dir.glob("*.yaml")):
        try:
            data = yaml.safe_load(path.read_text()) or {}
        except Exception:
            continue
        if not isinstance(data, dict):
            continue
        out[path.stem] = {
            "worker_kind": str(data.get("worker_kind") or ""),
            "provider": str(data.get("provider") or ""),
            # T-1872: `inline: true` workflows are driven by non-resolver flows
            # (fw inception start, fw grill, fw design-dialogue) and will never
            # appear in dispatches.jsonl. The staleness detector must skip them
            # or every inline workflow surfaces as a permanent false-positive WARN.
            "inline": bool(data.get("inline")),
        }
    return out


def check_workflow_dispatcher_coverage(
    workflows_dir: Path = None,
) -> Dict[str, Any]:
    """Cross-reference workflow worker_kinds against the spawn dispatcher set.

    Returns::

        {
          "workflows": [{"name": str, "worker_kind": str}, ...],
          "routable": [str, ...],                # _DISPATCHERS.keys()
          "valid_kinds": [str, ...],             # VALID_WORKER_KINDS
          "declarable_but_unroutable": [str, ...],  # VALID - routable
          "unroutable_workflows": [{"name", "worker_kind"}, ...],
          "ok": bool                              # True when no unroutables
        }

    Graceful on missing/malformed inputs: returns ok=True with empty lists.
    """
    wf_dir = workflows_dir or WORKFLOWS_DIR
    workflow_data = _parse_workflows(wf_dir)
    routable = _import_dispatcher_keys()
    valid = _import_valid_worker_kinds()

    workflows = [
        {
            "name": name,
            "worker_kind": d["worker_kind"],
            "provider": d["provider"],
            "inline": d.get("inline", False),  # T-1872: carry inline through
        }
        for name, d in workflow_data.items()
    ]
    unroutable_workflows = [
        {"name": name, "worker_kind": d["worker_kind"]}
        for name, d in workflow_data.items()
        if d["worker_kind"] and d["worker_kind"] not in routable
    ]
    # T-1800: pi workflows MUST declare a provider field — lib/spawn._spawn_pi
    # raises SpawnError when both envelope and workflow lack one. Audit-time
    # detection of that runtime-trap class.
    pi_workflows_missing_provider = [
        {"name": name, "worker_kind": "pi"}
        for name, d in workflow_data.items()
        if d["worker_kind"] == "pi" and not d["provider"]
    ]
    declarable_but_unroutable = sorted(valid - routable) if valid else []

    return {
        "workflows": workflows,
        "routable": sorted(routable),
        "valid_kinds": sorted(valid),
        "declarable_but_unroutable": declarable_but_unroutable,
        "unroutable_workflows": unroutable_workflows,
        "pi_workflows_missing_provider": pi_workflows_missing_provider,
        "ok": (
            len(unroutable_workflows) == 0
            and len(pi_workflows_missing_provider) == 0
        ),
    }


def format_audit_line(report: Dict[str, Any]) -> str:
    """Compact one-line summary used by audit.sh's PASS/WARN/FAIL emitter."""
    n_total = len(report["workflows"])
    n_unroutable = len(report["unroutable_workflows"])
    n_missing_provider = len(report.get("pi_workflows_missing_provider", []))
    n_stale = len(report.get("stale_workflows", []))
    declarable_unroutable = report["declarable_but_unroutable"]
    parts: list[str] = []
    if report["ok"]:
        ok_line = (
            f"all {n_total} workflows route to a registered dispatcher and "
            f"pi workflows declare a provider; "
            f"declarable-but-unroutable: {declarable_unroutable or 'none'}"
        )
        # T-1803: surface stale WARN inline. WARN doesn't fail the audit,
        # but the line itself should name them so the operator sees the
        # signal without diffing two artefacts.
        if report.get("warn") and n_stale:
            stale_names = ", ".join(w["name"] for w in report["stale_workflows"])
            return f"{ok_line}; {n_stale} stale workflow(s): {stale_names}"
        return ok_line
    if n_unroutable:
        bad = ", ".join(
            f"{w['name']}({w['worker_kind']})"
            for w in report["unroutable_workflows"]
        )
        parts.append(f"{n_unroutable}/{n_total} unroutable worker_kind: {bad}")
    if n_missing_provider:
        bad = ", ".join(
            w["name"] for w in report["pi_workflows_missing_provider"]
        )
        parts.append(f"{n_missing_provider} pi workflow(s) missing provider: {bad}")
    return "; ".join(parts)


def enrich_with_dispatch_recency(
    report: Dict[str, Any],
    dispatches_path: Path = None,
) -> Dict[str, Any]:
    """Annotate each workflow row with ``last_dispatched`` + ``last_dispatch_task_id``.

    Joins ``.context/dispatches.jsonl`` (per-dispatch records, one JSON object
    per line) to the coverage report on ``workflow_id == workflow.name``,
    taking max ``ts`` per workflow. Pure: returns a NEW report dict, does not
    mutate input. Graceful on missing path or malformed JSONL.

    T-1802: surfaces deprecation candidates on `/orchestrator` Workflow
    coverage panel — workflows declared but never dispatched are visible
    at a glance instead of buried in `fw orchestrator status` output.

    Args:
        report: A report dict from ``check_workflow_dispatcher_coverage``.
        dispatches_path: Override for testing; defaults to
            ``.context/dispatches.jsonl`` under PROJECT_ROOT.

    Returns:
        A new report dict. Each ``workflows[i]`` row gains:
          - ``last_dispatched``: ISO8601 string or None
          - ``last_dispatch_task_id``: task ID string or None
    """
    import copy
    import json as _json  # local — module shouldn't fail to import on missing json

    path = dispatches_path if dispatches_path is not None else DISPATCHES_JSONL
    by_workflow: Dict[str, Dict[str, str]] = {}
    if path.is_file():
        try:
            for line in path.read_text().splitlines():
                if not line.strip():
                    continue
                try:
                    d = _json.loads(line)
                except Exception:
                    continue
                if not isinstance(d, dict):
                    continue
                wf = d.get("workflow_id")
                ts = d.get("ts")
                if not wf or not ts:
                    continue
                cur = by_workflow.get(wf)
                if cur is None or ts > cur["ts"]:
                    by_workflow[wf] = {
                        "ts": ts,
                        "task_id": d.get("task_id") or "",
                    }
        except Exception:
            # Reading dispatches.jsonl must never crash the panel — degrade
            # to "no recency known" for every workflow.
            by_workflow = {}

    enriched = copy.deepcopy(report)
    for w in enriched.get("workflows", []):
        hit = by_workflow.get(w.get("name"))
        if hit:
            w["last_dispatched"] = hit["ts"]
            w["last_dispatch_task_id"] = hit["task_id"] or None
        else:
            w["last_dispatched"] = None
            w["last_dispatch_task_id"] = None
    return enriched


def flag_stale_workflows(
    report: Dict[str, Any],
    stale_threshold_days: int = STALE_THRESHOLD_DAYS,
    now_iso: str = None,
) -> Dict[str, Any]:
    """Add ``stale_workflows`` list + ``warn`` boolean to the report.

    A workflow is **stale** when:
      - ``last_dispatched`` is None (never dispatched), OR
      - ``last_dispatched`` is more than ``stale_threshold_days`` ago.

    Stale is a maintenance signal ("consider deprecating"), NOT a runtime
    failure. ``report["ok"]`` is left unchanged. The new ``warn`` boolean is
    True iff stale workflows exist AND ``ok`` is True (a WARN doesn't override
    a FAIL — FAIL absorbs WARN).

    T-1803: surfaces declared-but-dead workflows at audit time. Use the
    `enrich_with_dispatch_recency` output as input — this function reads
    `last_dispatched` from each row.

    Args:
        report: A report dict (typically post-``enrich_with_dispatch_recency``).
        stale_threshold_days: Days since last dispatch to consider stale.
            Defaults to ``STALE_THRESHOLD_DAYS`` (90).
        now_iso: ISO8601 string for "now" — test injection. Defaults to UTC now.

    Returns:
        A new report dict with two new fields:
          - ``stale_workflows``: list of ``{"name", "worker_kind", "last_dispatched"}``.
          - ``warn``: True iff stale list non-empty AND ``ok`` is True.
    """
    import copy
    import datetime

    if now_iso is None:
        now = datetime.datetime.now(datetime.timezone.utc)
    else:
        # Accept "...Z" suffix (RFC 3339) which fromisoformat rejects pre-3.11
        try:
            now = datetime.datetime.fromisoformat(now_iso.replace("Z", "+00:00"))
        except Exception:
            now = datetime.datetime.now(datetime.timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=datetime.timezone.utc)

    cutoff = now - datetime.timedelta(days=stale_threshold_days)

    stale: list = []
    for w in report.get("workflows", []):
        # T-1872: inline workflows (fw inception start, fw grill, etc.) are
        # driven by non-resolver flows and will never appear in dispatches.jsonl.
        # They are not stale "by design" — exclude from the staleness premise.
        if w.get("inline"):
            continue
        last = w.get("last_dispatched")
        if last is None:
            stale.append({
                "name": w.get("name"),
                "worker_kind": w.get("worker_kind", ""),
                "last_dispatched": None,
            })
            continue
        try:
            last_dt = datetime.datetime.fromisoformat(last.replace("Z", "+00:00"))
            if last_dt.tzinfo is None:
                last_dt = last_dt.replace(tzinfo=datetime.timezone.utc)
        except Exception:
            # Malformed timestamp → conservatively treat as stale (better
            # surface a maintenance signal than hide it under a parse error).
            stale.append({
                "name": w.get("name"),
                "worker_kind": w.get("worker_kind", ""),
                "last_dispatched": last,
            })
            continue
        if last_dt < cutoff:
            stale.append({
                "name": w.get("name"),
                "worker_kind": w.get("worker_kind", ""),
                "last_dispatched": last,
            })

    out = copy.deepcopy(report)
    out["stale_workflows"] = stale
    # WARN only when not already FAIL. FAIL absorbs WARN — the operator
    # shouldn't see "stale" surfaced on a workflow that's already crashing.
    out["warn"] = bool(stale) and bool(report.get("ok"))
    return out


if __name__ == "__main__":
    import json
    report = check_workflow_dispatcher_coverage()
    print(json.dumps(report, indent=2))
    sys.exit(0 if report["ok"] else 1)
