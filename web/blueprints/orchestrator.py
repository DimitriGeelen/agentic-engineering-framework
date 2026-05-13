"""T-1647 (W10 #2 of T-1641 Arc C) — Watchtower /orchestrator page.

Surfaces orchestrator-arc state for the operator. Direct response to the
T-1641 trigger ("absolutely seeing nothing that indicates we are now
orchestrating"). Three panels:

1. **MCP audit summary** — reads `.context/audits/orchestrator-LATEST.yaml`
   produced by `agents/audit/orchestrator-mcp-scan.sh` (T-1646). Shows
   gated/total counts, drift findings, last-run timestamp.

2. **Live sessions** — parses `termlink list --json` for session task-type,
   role, model, and task tags. Per-task-type aggregation. Cleanly degrades
   when TermLink is not running.

3. **Reconsideration arc** — cross-link panel to T-1641 artefact and the
   four follow-up arcs (T-1642/T-1643/T-1644/T-1645) so the reviewer can
   navigate the open work.

Data sources:
- `.context/audits/orchestrator-LATEST.yaml` (T-1646)
- `termlink list --json` (subprocess; bounded timeout; degrades on failure)
- `.tasks/active/T-1641-*.md`, T-1642/3/4/5 — task-file metadata
"""

import json
import os
import re
import subprocess
from collections import Counter, defaultdict
from pathlib import Path

import yaml
from flask import Blueprint

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("orchestrator", __name__)


_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---", re.DOTALL)
_TAG_PREFIXES = ("task-type:", "role:", "task:", "model:", "host=", "project=")


def _read_audit() -> dict:
    """Parse the latest MCP audit; return {} if missing."""
    path = PROJECT_ROOT / ".context" / "audits" / "orchestrator-LATEST.yaml"
    if not path.is_file():
        return {}
    try:
        return yaml.safe_load(path.read_text()) or {}
    except (yaml.YAMLError, OSError):
        return {}


def _read_baseline() -> dict:
    """Parse the MCP baseline classification; return {} if missing."""
    path = PROJECT_ROOT / ".context" / "audits" / "orchestrator-mcp-baseline.yaml"
    if not path.is_file():
        return {}
    try:
        return yaml.safe_load(path.read_text()) or {}
    except (yaml.YAMLError, OSError):
        return {}


def _termlink_sessions() -> tuple[list[dict], str | None]:
    """Return (sessions, error). Bounded subprocess; degrades on failure."""
    try:
        proc = subprocess.run(
            ["termlink", "list", "--json"],
            capture_output=True,
            text=True,
            timeout=4,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as exc:
        return [], f"TermLink unreachable: {type(exc).__name__}"
    if proc.returncode != 0:
        return [], f"termlink list exited {proc.returncode}"
    try:
        data = json.loads(proc.stdout or "{}")
    except json.JSONDecodeError as exc:
        return [], f"json parse: {exc}"
    return data.get("sessions", []) or [], None


def _split_tags(session: dict) -> dict[str, list[str]]:
    """Parse session.tags string ('a=1,b=2,task-type:build') into prefix-grouped lists."""
    raw = session.get("tags") or ""
    if isinstance(raw, list):
        items = [str(t) for t in raw]
    else:
        items = [t.strip() for t in str(raw).split(",") if t.strip()]
    grouped: dict[str, list[str]] = {p: [] for p in _TAG_PREFIXES}
    other: list[str] = []
    for item in items:
        matched = False
        for prefix in _TAG_PREFIXES:
            if item.startswith(prefix):
                grouped[prefix].append(item[len(prefix):])
                matched = True
                break
        if not matched:
            other.append(item)
    grouped["_other"] = other
    return grouped


def _recent_dispatches(limit: int = 20) -> list[dict]:
    """T-1643/W5: surface recent fw termlink dispatch worker meta.json files.

    Reads /tmp/tl-dispatch/<name>/meta.json — orchestrator-relevant fields only:
    name, task, task_type, model, model_used, fallback_used, status, started.
    Sorted newest first. Empty list if directory missing or no workers.
    """
    dispatch_dir = Path("/tmp/tl-dispatch")
    if not dispatch_dir.is_dir():
        return []
    out = []
    for worker_dir in dispatch_dir.iterdir():
        if not worker_dir.is_dir():
            continue
        meta_path = worker_dir / "meta.json"
        if not meta_path.is_file():
            continue
        try:
            meta = json.loads(meta_path.read_text())
        except (json.JSONDecodeError, OSError):
            continue
        # Status: prefer exit_code presence over the meta status field
        # (meta.status is set to "running" at spawn and never updated).
        exit_code_path = worker_dir / "exit_code"
        if exit_code_path.is_file():
            try:
                exit_code = exit_code_path.read_text().strip()
                meta["status"] = "done" if exit_code == "0" else f"exit:{exit_code}"
            except OSError:
                pass
        out.append({
            "name": meta.get("name", worker_dir.name),
            "task": meta.get("task") or "",
            "task_type": meta.get("task_type") or "",
            "model": meta.get("model") or "",
            "model_used": meta.get("model_used"),
            "fallback_used": meta.get("fallback_used"),
            "status": meta.get("status", "?"),
            "started": meta.get("started", ""),
        })
    out.sort(key=lambda r: r["started"], reverse=True)
    return out[:limit]


def _route_cache_path() -> Path:
    """Resolve route-cache.json path consistently with agents/termlink/termlink.sh.

    Order: TERMLINK_RUNTIME_DIR > XDG_RUNTIME_DIR/termlink > /var/lib/termlink.
    """
    env_runtime = os.environ.get("TERMLINK_RUNTIME_DIR")
    if env_runtime:
        return Path(env_runtime) / "route-cache.json"
    xdg = os.environ.get("XDG_RUNTIME_DIR")
    if xdg:
        return Path(xdg) / "termlink" / "route-cache.json"
    return Path("/var/lib/termlink/route-cache.json")


def _route_cache_learned() -> dict:
    """T-1669 Step 3 — surface learned per-task-type model preferences.

    Reads route-cache.json (written by /opt/termlink hub AND framework
    record-outcome) and returns a structure ready for the template:

      {
        "available": bool,
        "path": str,
        "by_task_type": [
            {"task_type": "build",
             "best": {"model": "haiku", "successes": 8, "failures": 2, "rate": 0.8},
             "candidates": [{"model": "haiku", ...}, {"model": "opus", ...}]},
            ...
        ],
        "total_stats": int,
      }

    Empty `by_task_type` when the cache has no model_stats (the framework
    hasn't recorded any dispatches yet — that's the headline_mechanic's
    "before" state on a fresh deployment).
    """
    path = _route_cache_path()
    if not path.is_file():
        return {"available": False, "path": str(path), "by_task_type": [], "total_stats": 0}
    try:
        cache = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError):
        return {"available": False, "path": str(path), "by_task_type": [], "total_stats": 0}
    stats = cache.get("model_stats") or {}
    if not isinstance(stats, dict):
        stats = {}
    by_tt: dict[str, list[dict]] = defaultdict(list)
    for stat in stats.values():
        if not isinstance(stat, dict):
            continue
        tt = stat.get("task_type")
        model = stat.get("model")
        if not tt or not model:
            continue
        succ = int(stat.get("successes", 0) or 0)
        fail = int(stat.get("failures", 0) or 0)
        total = succ + fail
        if total <= 0:
            continue
        by_tt[tt].append({
            "model": model,
            "successes": succ,
            "failures": fail,
            "total": total,
            "rate": succ / total,
            "last_used": stat.get("last_used"),
        })
    rows = []
    for tt, candidates in sorted(by_tt.items()):
        candidates.sort(key=lambda c: (-c["rate"], -c["total"], c["model"]))
        rows.append({
            "task_type": tt,
            "best": candidates[0],
            "candidates": candidates,
        })
    return {
        "available": True,
        "path": str(path),
        "by_task_type": rows,
        "total_stats": sum(len(r["candidates"]) for r in rows),
    }


def _dispatch_substrate() -> dict:
    """T-1792 — surface dispatch substrate (`.context/dispatches.jsonl`) for /orchestrator.

    Mirrors `fw orchestrator status`'s headline shape so the web view has
    CLI parity. Minimum slice: totals + by_model. by_task_type /
    by_worker_kind / outcomes are deferred to follow-on slices (separate
    tasks) — keep this panel scoped to the routing-decision view that
    T-1788 introduced on the CLI.

    Synthetic rows (`task_id` startswith `T-stress-`) are excluded from
    `total` and `by_model`, consistent with the CLI's `_is_synthetic`
    rule (T-1712). Synthetic count is surfaced separately for context.

    Returns:
      {
        "available": bool,
        "path": str,
        "total": int,                # real dispatches only
        "synthetic_total": int,
        "by_model": [{"model": "X", "count": N}, ...],              # sorted count desc
        "by_task_type": [{"task_type": "X", "count": N}, ...],      # sorted count desc
        "by_worker_kind": [{"worker_kind": "X", "count": N}, ...],  # sorted count desc
      }

    T-1794: added `by_task_type` companion. T-1795: added `by_worker_kind`.
    Same row-exclusion rule for all three (rows missing the field are
    excluded from that breakdown only — they still contribute to `total`).
    """
    empty = {
        "available": False,
        "path": "",
        "total": 0,
        "synthetic_total": 0,
        "by_model": [],
        "by_task_type": [],
        "by_worker_kind": [],
    }
    path = PROJECT_ROOT / ".context" / "dispatches.jsonl"
    if not path.is_file():
        return {**empty, "path": str(path)}
    real_rows: list[dict] = []
    synthetic_count = 0
    try:
        for line in path.read_text().splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue  # skip malformed line, continue parsing
            tid = row.get("task_id") or ""
            if tid.startswith("T-stress-"):
                synthetic_count += 1
                continue
            real_rows.append(row)
    except OSError:
        return {**empty, "path": str(path)}
    model_counter: Counter = Counter()
    task_type_counter: Counter = Counter()
    worker_kind_counter: Counter = Counter()
    for row in real_rows:
        model = row.get("model")
        if model:
            model_counter[model] += 1
        tt = row.get("task_type")
        if tt:
            task_type_counter[tt] += 1
        wk = row.get("worker_kind")
        if wk:
            worker_kind_counter[wk] += 1
    def _to_rows(counter: Counter, key: str) -> list[dict]:
        return [
            {key: k, "count": v}
            for k, v in sorted(counter.items(), key=lambda kv: (-kv[1], kv[0]))
        ]
    return {
        "available": True,
        "path": str(path),
        "total": len(real_rows),
        "synthetic_total": synthetic_count,
        "by_model": _to_rows(model_counter, "model"),
        "by_task_type": _to_rows(task_type_counter, "task_type"),
        "by_worker_kind": _to_rows(worker_kind_counter, "worker_kind"),
    }


def _outcome_quality() -> dict:
    """T-1796 — surface outcome-quality (verification pass/fail per task_type).

    Mirrors `fw orchestrator status --outcomes` verification-style
    aggregation. Reads dispatches.jsonl + dispatch-outcomes.jsonl,
    joins on dispatch_id, dedupes by latest ts (T-1757 rule), excludes
    synthetic dispatches, returns per-task-type pass/fail counts.

    Returns:
      {
        "available": bool,
        "total_outcomes": int,         # after dedup + synthetic-exclusion
        "by_task_type": [{
            "task_type": str,
            "passed": int,
            "failed": int,
            "total": int,
            "pass_rate": float,        # 0..1
        }, ...],                        # sorted total desc
      }

    Notes:
    - "verdict-style" outcomes (escalation-scan-v0.5 shape) are still
      counted toward `total_outcomes` but contribute to neither passed
      nor failed (no verification_passed field).
    """
    empty: dict = {"available": False, "total_outcomes": 0, "by_task_type": []}
    dispatches_path = PROJECT_ROOT / ".context" / "dispatches.jsonl"
    outcomes_path = PROJECT_ROOT / ".context" / "dispatch-outcomes.jsonl"
    if not outcomes_path.is_file():
        return empty
    # Build dispatch_id -> task_type map for non-synthetic dispatches.
    did_to_type: dict[str, str] = {}
    if dispatches_path.is_file():
        try:
            for line in dispatches_path.read_text().splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue
                tid = row.get("task_id") or ""
                if tid.startswith("T-stress-"):
                    continue
                did = row.get("dispatch_id")
                if did:
                    did_to_type[did] = row.get("task_type") or "?"
        except OSError:
            return empty
    # Dedupe outcomes by dispatch_id, latest ts wins (T-1757).
    latest_per_did: dict[str, dict] = {}
    try:
        for line in outcomes_path.read_text().splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            did = row.get("dispatch_id")
            if not did or did not in did_to_type:
                continue  # outcome for synthetic or unknown dispatch
            prev = latest_per_did.get(did)
            if prev is None or (row.get("ts") or "") > (prev.get("ts") or ""):
                latest_per_did[did] = row
    except OSError:
        return empty
    # Aggregate per task_type.
    per_type: dict[str, dict] = {}
    for did, o in latest_per_did.items():
        tt = did_to_type[did]
        bucket = per_type.setdefault(tt, {"passed": 0, "failed": 0, "total": 0})
        bucket["total"] += 1
        outcome_body = o.get("outcome", {}) or {}
        if "verification_passed" in outcome_body:
            if bool(outcome_body["verification_passed"]):
                bucket["passed"] += 1
            else:
                bucket["failed"] += 1
    rows = []
    for tt, b in per_type.items():
        decided = b["passed"] + b["failed"]
        rate = (b["passed"] / decided) if decided else 0.0
        rows.append({
            "task_type": tt,
            "passed": b["passed"],
            "failed": b["failed"],
            "total": b["total"],
            "pass_rate": rate,
        })
    rows.sort(key=lambda r: (-r["total"], r["task_type"]))
    return {
        "available": True,
        "total_outcomes": len(latest_per_did),
        "by_task_type": rows,
    }


def _workflow_coverage() -> dict:
    """T-1799: workflow → dispatcher coverage report for the web panel.

    Thin facade over ``lib.workflow_coverage.check_workflow_dispatcher_coverage``.
    Returns ``{"available": False}`` when the helper can't be imported (e.g.
    consumer projects without the framework's lib/ on path) so the template
    can show an empty state instead of crashing.
    """
    import sys
    lib_dir = PROJECT_ROOT / "lib"
    if str(lib_dir) not in sys.path:
        sys.path.insert(0, str(lib_dir))
    try:
        import workflow_coverage  # noqa: PLC0415
    except Exception:
        return {"available": False}
    try:
        report = workflow_coverage.check_workflow_dispatcher_coverage()
    except Exception:
        return {"available": False}
    # T-1802: enrich each workflow row with last-dispatch timestamp +
    # task_id. Wrap separately so a dispatches.jsonl issue doesn't kill
    # the whole panel — coverage data still renders, recency column
    # falls back to "never" for every row.
    try:
        report = workflow_coverage.enrich_with_dispatch_recency(report)
    except Exception:
        pass
    # T-1803: flag stale workflows (no dispatch in 90d) as WARN. Same
    # try/except guard — staleness is a maintenance signal, not a
    # crash-the-panel condition.
    try:
        report = workflow_coverage.flag_stale_workflows(report)
    except Exception:
        pass
    report["available"] = True
    return report


def _arc_tasks() -> list[dict]:
    """Surface T-1641 + follow-up arc parents for the cross-link panel."""
    targets = ["T-1641", "T-1642", "T-1643", "T-1644", "T-1645", "T-1646", "T-1647"]
    tasks_dir = PROJECT_ROOT / ".tasks"
    out = []
    for tid in targets:
        path = None
        for sub in ("active", "completed"):
            for cand in (tasks_dir / sub).glob(f"{tid}-*.md"):
                path = cand
                break
            if path:
                break
        if not path:
            continue
        try:
            text = path.read_text()
        except OSError:
            continue
        m = _FRONTMATTER_RE.search(text)
        if not m:
            continue
        try:
            fm = yaml.safe_load(m.group(1)) or {}
        except yaml.YAMLError:
            continue
        out.append({
            "id": tid,
            "name": fm.get("name", "(no name)"),
            "status": fm.get("status", "?"),
            "horizon": fm.get("horizon", "?"),
            "type": fm.get("workflow_type", "?"),
            "completed": (path.parent.name == "completed"),
        })
    return out


@bp.route("/orchestrator")
def orchestrator_page():
    """Orchestrator-arc state surface (T-1647 / Arc C from T-1641)."""
    audit = _read_audit()
    baseline = _read_baseline()
    sessions, sessions_err = _termlink_sessions()

    # Aggregate sessions by task-type tag
    task_type_counts: Counter[str] = Counter()
    role_counts: Counter[str] = Counter()
    task_counts: Counter[str] = Counter()
    untagged_sessions = 0
    session_rows = []
    for s in sessions:
        tags = _split_tags(s)
        tt = tags["task-type:"]
        if tt:
            for t in tt:
                task_type_counts[t] += 1
        else:
            untagged_sessions += 1
        for r in tags["role:"]:
            role_counts[r] += 1
        for t in tags["task:"]:
            task_counts[t] += 1
        session_rows.append({
            "id": s.get("id") or "",
            "name": s.get("name") or "",
            "state": s.get("state") or "?",
            "task_types": tt,
            "roles": tags["role:"],
            "models": tags["model:"],
            "tasks": tags["task:"],
        })

    # Sort: tagged sessions first, then by name
    session_rows.sort(key=lambda r: (0 if r["task_types"] or r["tasks"] else 1, r["name"]))

    # Audit findings condensed
    findings = audit.get("findings", {}) if audit else {}
    has_drift = bool(
        findings.get("new_unclassified_tools")
        or findings.get("gate_drop_outs")
        or findings.get("gate_added_ratchet_candidates")
        or findings.get("removed_tools")
        or findings.get("tag_format_warnings")
    )

    return render_page(
        "orchestrator.html",
        page_title="Orchestrator",
        audit=audit,
        baseline=baseline,
        has_drift=has_drift,
        sessions_total=len(sessions),
        sessions_err=sessions_err,
        task_type_counts=sorted(task_type_counts.items(), key=lambda x: (-x[1], x[0])),
        role_counts=sorted(role_counts.items(), key=lambda x: (-x[1], x[0])),
        task_counts_total=len(task_counts),
        untagged_sessions=untagged_sessions,
        session_rows=session_rows[:50],  # cap render width
        session_rows_truncated=max(0, len(session_rows) - 50),
        arc_tasks=_arc_tasks(),
        recent_dispatches=_recent_dispatches(),
        learned=_route_cache_learned(),
        substrate=_dispatch_substrate(),
        outcome_quality=_outcome_quality(),
        workflow_coverage=_workflow_coverage(),
    )
