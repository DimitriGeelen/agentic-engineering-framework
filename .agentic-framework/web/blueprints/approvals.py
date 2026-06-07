"""Approvals blueprint — Unified approval surface (T-611, T-639).

Shows four urgency-ordered sections:
  A. Tier 0 approvals (agent blocked)
  B. Pending GO/NO-GO inception decisions
  C. Paused dispatches (T-1808 / dispatch-safety slice 4)
  D. Tasks with unchecked Human ACs
"""

import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import yaml
from flask import Blueprint, request

from web.shared import PROJECT_ROOT, render_page, parse_frontmatter, task_id_sort_key, get_all_task_metadata, extract_recommendation_verdict, extract_recommendation_state, extract_reviewer_verdict, count_unchecked_human_acs, needs_human_review, mtime_cached_get

# T-1808: paused-dispatch surface — needs lib/ on the path so the helper imports cleanly.
sys.path.insert(0, str(PROJECT_ROOT / "lib"))
try:
    from dispatch_pause import list_paused_dispatches, format_age, truncate as _trunc_q
except Exception:  # pragma: no cover - fallback for consumer projects without lib/
    def list_paused_dispatches(_=None):
        return []
    def format_age(_):
        return "?"
    def _trunc_q(s, w):
        return s

bp = Blueprint("approvals", __name__)

APPROVALS_DIR = PROJECT_ROOT / ".context" / "approvals"
APPROVAL_FILE = PROJECT_ROOT / ".context" / "working" / ".tier0-approval"

# Approvals older than this are considered expired (seconds)
EXPIRY_SECONDS = 3600  # 1 hour

# T-2102: per-file body cache keyed on path -> (mtime_ns, body).
# /approvals scans ~170 active task bodies per request through three hot loaders
# (_load_pending_go_decisions, _load_pending_human_acs, _load_close_ready_arcs).
# Profile (S-2026-0529): disk read all = 9ms; parse_frontmatter all = 571ms;
# section extracts on already-parsed body = 48-85ms. The yaml.safe_load on the
# frontmatter chunk is the dominant cost. Caching the body (after frontmatter
# strip) keyed by (path, mtime_ns) eliminates the repeat yaml parse and brings
# /approvals from 14.8s → <3s on warm cache. Memory cost: ~170 body strings
# (a few MB) in the long-running Flask process — amortises across requests.
# Same shape as T-1954 _FM_CACHE in web/blueprints/bvp.py.
_BODY_CACHE: dict[str, tuple[int, str]] = {}


def _parse_body_from_path(p: Path) -> str:
    """Read file, strip frontmatter, return body. Empty string on read failure."""
    try:
        content = p.read_text()
    except OSError:
        return ""
    _, body = parse_frontmatter(content)
    return body


def _get_body_cached(path: Path | str) -> str:
    """Return task body (after frontmatter strip), mtime-invalidated.

    Returns "" on any read or parse failure (matches existing callers'
    behaviour of skipping the task on continue).

    T-2109: migrated to shared.mtime_cached_get; semantics unchanged.
    """
    return mtime_cached_get(Path(path), _parse_body_from_path, _BODY_CACHE, default="")


def _load_pending_approvals():
    """Load all pending approval YAML files. Returns list of dicts."""
    approvals = []
    if not APPROVALS_DIR.exists():
        return approvals

    now = time.time()
    for f in sorted(APPROVALS_DIR.glob("pending-*.yaml"), reverse=True):
        try:
            with open(f) as fh:
                data = yaml.safe_load(fh)
            if not isinstance(data, dict):
                continue
            data["_file"] = f.name

            # Check expiry
            ts = data.get("timestamp", "")
            if ts:
                try:
                    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    age = now - dt.timestamp()
                    if age > EXPIRY_SECONDS:
                        data["status"] = "expired"
                except (ValueError, OSError):
                    pass

            approvals.append(data)
        except yaml.YAMLError:
            continue
    return approvals


def _load_resolved_approvals():
    """Load recently resolved (approved/rejected) approvals."""
    resolved = []
    if not APPROVALS_DIR.exists():
        return resolved

    for f in sorted(APPROVALS_DIR.glob("resolved-*.yaml"), reverse=True):
        try:
            with open(f) as fh:
                data = yaml.safe_load(fh)
            if isinstance(data, dict):
                resolved.append(data)
        except yaml.YAMLError:
            continue
    return resolved[:20]  # Last 20


# T-1415 (T-1388 B5 / F2): Count inline `- A\d+:` assumption bullets in task body.
# Most inception tasks list assumptions inline under ## Assumptions rather than
# registering via `fw assumption add`, so the /approvals badge read "0" even
# when the body clearly showed several. Fall back to the body count and mark
# source=body so the template can render the provenance.
_INLINE_ASSUMPTION_RE = re.compile(r"^- A\d+:", re.MULTILINE)


def _count_body_assumptions(body: str) -> int:
    """Count inline `- A\\d+:` assumption bullets under the ## Assumptions section."""
    from web.blueprints.inception import _extract_section

    section = _extract_section(body, "Assumptions")
    if not section:
        return 0
    return len(_INLINE_ASSUMPTION_RE.findall(section))


def _load_pending_go_decisions():
    """Scan active inception tasks where decision is still pending.

    Returns list of dicts with: task_id, name, status, problem_excerpt,
    assumption_counts, artifacts.
    """
    from web.blueprints.inception import _extract_decision, _extract_section, _load_assumptions

    assumptions = _load_assumptions()
    results = []

    # T-1244: Use shared task metadata cache to filter to active+inception tasks
    # before reading bodies. Avoids re-globbing 100+ active tasks per request.
    candidates = [
        fm for fm in get_all_task_metadata()
        if fm.get("_location") == "active" and fm.get("workflow_type") == "inception"
    ]
    candidates.sort(key=lambda fm: task_id_sort_key(fm.get("_path", "")))

    for fm in candidates:
        path = fm.get("_path")
        if not path:
            continue
        # T-2102: use mtime-keyed body cache (was: re-read + parse_frontmatter per request).
        body = _get_body_cached(path)
        if not body:
            continue
        if _extract_decision(body) != "pending":
            continue

        # T-1123 / T-1570 (F4): Only drop captured/unexplored inceptions when the
        # Recommendation is missing. Started-work inceptions without a Recommendation
        # are exactly the cases where the human needs to see "agent is stuck — write
        # recommendation or escalate" — keep them, the template fallback handles
        # rendering (T-1214). Aligns display gate with the completion gate (T-1529).
        rec_section = _extract_section(body, "Recommendation")
        rec_substantive = bool(rec_section and len(rec_section.strip()) >= 20)
        if not rec_substantive and fm.get("status", "") != "started-work":
            continue

        task_id = fm.get("id", "")
        linked = [a for a in assumptions if a.get("linked_task") == task_id]

        # Find research artifacts
        artifacts = []
        reports_dir = PROJECT_ROOT / "docs" / "reports"
        if reports_dir.exists():
            tid_lower = task_id.lower().replace("-", "")
            for rpt in sorted(reports_dir.iterdir()):
                if rpt.suffix == ".md" and tid_lower in rpt.name.lower().replace("-", ""):
                    artifacts.append({"name": rpt.name, "path": f"docs/reports/{rpt.name}"})

        problem = _extract_section(body, "Problem Statement")
        # Truncate to first 2 lines
        problem_lines = problem.split("\n")[:2]
        problem_excerpt = " ".join(line.strip() for line in problem_lines if line.strip())
        if len(problem_excerpt) > 200:
            problem_excerpt = problem_excerpt[:197] + "..."

        # Extract recommendation for display (T-1119: show full recommendation)
        rec_raw = _extract_section(body, "Recommendation")
        rec_display = ""  # Full recommendation for visible display
        if rec_raw and len(rec_raw) > 10:
            rec_display = rec_raw.strip()
        # T-1537: use canonical helper for the verdict so inception + partial-complete
        # sections share extraction logic. Returns "GO"/"DEFER"/"NO-GO"/"?".
        verdict = extract_recommendation_verdict(body)
        # rec_decision retained for backward compat with the existing collapsible
        # summary (T-1119 contract); blank string preserved when no recommendation.
        rec_decision = verdict if verdict in ("GO", "DEFER", "NO-GO") else ""

        # Fallback to GO criteria for rationale hint
        # T-1150: NO truncation — the textarea pre-fill becomes the permanent decision
        # rationale when the human clicks approve. Truncating here = truncating the decision.
        # (Previous 200-char cap caused data loss in recorded decisions.)
        rationale_hint = ""
        if rec_raw and len(rec_raw) > 10:
            rationale_hint = rec_raw.replace("**", "").replace("*", "").strip()
        else:
            gonogo = _extract_section(body, "Go/No-Go Criteria")
            if gonogo:
                go_lines = []
                in_go = False
                for line in gonogo.split("\n"):
                    stripped = line.strip()
                    if stripped.startswith("**GO if:**"):
                        in_go = True
                        continue
                    if stripped.startswith("**NO-GO if:**"):
                        break
                    if in_go and stripped.startswith("- "):
                        go_lines.append(stripped[2:].strip())
                rationale_hint = "; ".join(go_lines) if go_lines else ""

        # T-1214: Extract Go/No-Go Criteria for fallback display when recommendation missing
        go_nogo_raw = _extract_section(body, "Go/No-Go Criteria")

        # T-1415 (T-1388 B5 / F2): Fall back to body-inline assumptions when none registered.
        if linked:
            assumption_counts = {
                "total": len(linked),
                "validated": sum(1 for a in linked if a.get("status") == "validated"),
                "source": "ledger",
            }
        else:
            body_count = _count_body_assumptions(body)
            assumption_counts = {
                "total": body_count,
                "validated": 0,
                "source": "body" if body_count else "ledger",
            }

        # T-1569 / F3: surface reviewer agent's mechanical verdict at decision time.
        reviewer = extract_reviewer_verdict(body)

        results.append({
            "task_id": task_id,
            "name": fm.get("name", ""),
            "status": fm.get("status", ""),
            "problem_excerpt": problem_excerpt,
            "problem_full": problem,
            "assumption_counts": assumption_counts,
            "artifacts": artifacts,
            "rationale_hint": rationale_hint,
            "recommendation": rec_display,
            "rec_decision": rec_decision,
            "verdict": verdict,
            "go_nogo_criteria": go_nogo_raw,
            "reviewer": reviewer,
        })

    return results


def _load_pending_human_acs():
    """Scan active tasks for unchecked Human ACs.

    Returns list of dicts with: task_id, name, status, human_acs list, age_days, is_stale, sort_priority.
    Sorted by priority: REVIEW first, then stale (>7d), then RUBBER-STAMP.
    """
    import time
    from datetime import datetime

    from web.blueprints.tasks import _parse_acceptance_criteria

    results = []
    now = time.time()

    # T-1244: Pull active-task frontmatter from shared cache instead of
    # re-globbing per request. Body still required for AC parse.
    candidates = [
        fm for fm in get_all_task_metadata()
        if fm.get("_location") == "active"
    ]
    candidates.sort(key=lambda fm: task_id_sort_key(fm.get("_path", "")))

    for fm in candidates:
        path = fm.get("_path")
        if not path:
            continue
        # T-2102: use mtime-keyed body cache (was: re-read + parse_frontmatter per request).
        body = _get_body_cached(path)
        if not body:
            continue

        # T-2075 (T-2064 GO): canonical predicate — shared with `fw review-queue`.
        # Gate FIRST on the cheap predicate, then run the full per-AC parse for
        # display detail. Previously this used `_parse_acceptance_criteria` →
        # filter on `section == "human"` → filter on `not checked` — which
        # drifted from the CLI's inline regex on tasks with HTML-commented
        # template stubs. Centralising the predicate kills the drift class.
        if not needs_human_review(body):
            continue

        all_acs = _parse_acceptance_criteria(body)
        human_acs = [ac for ac in all_acs if ac.get("section") == "human"]
        unchecked = [ac for ac in human_acs if not ac["checked"]]

        # Calculate age from date_finished or last_update
        age_days = 0
        for date_field in ("date_finished", "last_update", "created"):
            ts = fm.get(date_field, "")
            if ts:
                try:
                    dt = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
                    age_days = int((now - dt.timestamp()) / 86400)
                    break
                except (ValueError, OSError):
                    pass

        is_stale = age_days > 7

        # Priority: has REVIEW AC unchecked → 0, stale → 1, RUBBER-STAMP only → 2
        has_review = any(ac.get("confidence") == "review" and not ac["checked"]
                        for ac in human_acs)
        sort_priority = 0 if has_review else (1 if is_stale else 2)

        # T-1531: extract agent recommendation verdict (GO/DEFER/NO-GO/?)
        # T-1533: helper now lives in web.shared (third call site arrived)
        # T-1576: also expose `state` so template can distinguish NO-REC
        # (agent owes a recommendation) from '?' (verdict unparseable).
        verdict = extract_recommendation_verdict(body)
        state = extract_recommendation_state(body)
        # T-1569 / F3: parallel surface for the reviewer's mechanical scan.
        reviewer = extract_reviewer_verdict(body)

        results.append({
            "task_id": fm.get("id", ""),
            "name": fm.get("name", ""),
            "status": fm.get("status", ""),
            "human_acs": human_acs,
            "age_days": age_days,
            "is_stale": is_stale,
            "sort_priority": sort_priority,
            "verdict": verdict,
            "state": state,
            "reviewer": reviewer,
        })

    # Sort: priority ascending, then age descending (oldest first within group)
    results.sort(key=lambda t: (t["sort_priority"], -t["age_days"]))
    return results


def _count_deferred_inceptions():
    """Count active inceptions with a recorded DEFER decision (T-1518).

    DEFER'd inceptions are excluded from /approvals (decision != pending) but
    remain visible on /inception?decision=defer. This count powers an exit-ramp
    hint when /approvals has no pending decisions.
    """
    count = 0
    for fm in get_all_task_metadata():
        if fm.get("_location") != "active" or fm.get("workflow_type") != "inception":
            continue
        path = fm.get("_path")
        if not path:
            continue
        try:
            body = Path(path).read_text()
        except OSError:
            continue
        # Match the canonical block emitted by do_inception_decide
        if re.search(r"^\*\*Decision\*\*:\s*DEFER\b", body, re.M):
            count += 1
    return count


def _load_paused_dispatches():
    """T-1808: load paused dispatches and decorate for template rendering."""
    rows = list_paused_dispatches(PROJECT_ROOT)
    out = []
    for r in rows:
        out.append({
            **r,
            "dispatch_id_short": (r["dispatch_id"][:8] + "..") if len(r["dispatch_id"]) > 8 else r["dispatch_id"],
            "age_label": format_age(r["age_seconds"]),
            "question_short": _trunc_q(r["question"] or "(no question)", 120),
        })
    return out


def _load_close_ready_arcs(threshold: float = 0.80) -> list[dict]:
    """T-1961: arcs ready for closure review on /approvals.

    Filters: status=='in-progress' AND completion_ratio >= threshold AND
    anchor-task `## Recommendation` block present. Returns one dict per
    qualifying arc with the fields the template needs to render a row.
    """
    import glob
    import yaml as _yaml
    from web.blueprints.arcs import (
        _resolve_constituents,
        _completion_stats,
        _anchor_recommendation,
    )
    out: list[dict] = []
    for f in sorted(glob.glob(str(PROJECT_ROOT / ".context" / "arcs" / "*.yaml"))):
        try:
            arc = _yaml.safe_load(open(f).read()) or {}
        except (OSError, _yaml.YAMLError):
            continue
        if str(arc.get("status") or "").strip() != "in-progress":
            continue
        constituents = _resolve_constituents(arc)
        stats = _completion_stats(constituents)
        if stats["ratio"] < threshold:
            continue
        rec = _anchor_recommendation(arc)
        if not rec.get("present"):
            continue
        out.append({
            "slug": str(arc.get("slug") or "").strip(),
            "id": str(arc.get("id") or "").strip(),
            "name": str(arc.get("name") or arc.get("slug") or ""),
            "anchor": rec.get("anchor_id", ""),
            "verdict": rec.get("verdict", "?"),
            "completion_ratio": stats["ratio"],
            "completed": stats["completed"],
            "total": stats["total"],
            "headline_mechanic": str(arc.get("headline_mechanic") or ""),
        })
    return out


def _build_approvals_context():
    """Build template context for approvals page."""
    pending_tier0 = _load_pending_approvals()
    resolved_tier0 = _load_resolved_approvals()
    pending_go = _load_pending_go_decisions()
    pending_acs = _load_pending_human_acs()
    deferred_count = _count_deferred_inceptions()
    paused_dispatches = _load_paused_dispatches()  # T-1808
    arcs_close_ready = _load_close_ready_arcs()  # T-1961

    tier0_count = sum(1 for a in pending_tier0 if a.get("status") == "pending")
    go_count = len(pending_go)
    ac_count = sum(
        sum(1 for ac in t["human_acs"] if not ac["checked"])
        for t in pending_acs
    )
    paused_count = len(paused_dispatches)  # T-1808
    arc_close_count = len(arcs_close_ready)  # T-1961
    total = tier0_count + go_count + len(pending_acs) + paused_count + arc_close_count

    # Count tasks ready for batch completion (all human ACs checked)
    ready_count = sum(
        1 for t in pending_acs
        if all(ac["checked"] for ac in t["human_acs"])
    )

    return dict(
        pending_tier0=pending_tier0,
        resolved_tier0=resolved_tier0,
        pending_go=pending_go,
        pending_acs=pending_acs,
        paused_dispatches=paused_dispatches,
        arcs_close_ready=arcs_close_ready,
        tier0_count=tier0_count,
        go_count=go_count,
        ac_count=ac_count,
        ac_task_count=len(pending_acs),
        paused_count=paused_count,
        arc_close_count=arc_close_count,
        total_count=total,
        active_count=tier0_count,
        ready_count=ready_count,
        deferred_count=deferred_count,
    )


@bp.route("/approvals")
def approvals():
    ctx = _build_approvals_context()
    return render_page("approvals.html", page_title="Approvals", **ctx)


@bp.route("/approvals/content")
def approvals_content():
    """htmx polling fragment — returns approvals content without page wrapper (T-669)."""
    from flask import render_template

    ctx = _build_approvals_context()
    return render_template("_approvals_content.html", **ctx)


@bp.route("/api/approvals/decide", methods=["POST"])
def decide_approval():
    """Approve or reject a pending Tier 0 request.

    This endpoint is the unfakeable surface — only the web UI (human) can POST here.
    It writes the approval token that check-tier0.sh reads on retry.
    """
    command_hash = request.form.get("command_hash", "").strip()
    decision = request.form.get("decision", "").strip()
    feedback = request.form.get("feedback", "").strip()

    if not command_hash:
        return '<p style="color:var(--pico-del-color);">Missing command hash</p>', 400
    if decision not in ("approved", "rejected"):
        return '<p style="color:var(--pico-del-color);">Invalid decision</p>', 400

    # Find the pending request
    pending_file = APPROVALS_DIR / f"pending-{command_hash[:12]}.yaml"
    if not pending_file.exists():
        return '<p style="color:var(--pico-del-color);">No pending request found</p>', 404

    try:
        with open(pending_file) as fh:
            data = yaml.safe_load(fh)
    except yaml.YAMLError:
        return '<p style="color:var(--pico-del-color);">Cannot read request</p>', 500

    now_ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    exec_result = None
    if decision == "approved":
        # Write the approval token that check-tier0.sh expects
        # Format: <command_hash> <unix_timestamp>
        APPROVAL_FILE.parent.mkdir(parents=True, exist_ok=True)
        APPROVAL_FILE.write_text(f"{command_hash} {int(time.time())}\n")

        # Self-consuming execution for idempotent bookkeeping commands that
        # would otherwise be orphaned if no agent retries (T-1192 structural
        # fix). Scope: `fw inception decide T-XXX go|no-go --rationale "..."`.
        command_preview = data.get("command_preview", "")
        if _is_inception_decide(command_preview):
            exec_result = _execute_inception_decide(command_preview)

    # Move pending → resolved
    data["status"] = decision
    response_dict = {
        "decision": decision,
        "feedback": feedback or None,
        "responded_at": now_ts,
        "mechanism": "watchtower",
    }
    if exec_result is not None:
        response_dict["auto_executed"] = exec_result
    data["response"] = response_dict

    resolved_file = APPROVALS_DIR / f"resolved-{command_hash[:12]}.yaml"
    with open(resolved_file, "w") as fh:
        yaml.dump(data, fh, default_flow_style=False, sort_keys=False)

    # Remove pending file
    pending_file.unlink(missing_ok=True)

    status_color = "var(--pico-ins-color)" if decision == "approved" else "var(--pico-del-color)"
    status_icon = "Approved" if decision == "approved" else "Rejected"
    msg = f'{status_icon}.'
    if exec_result is not None:
        if exec_result.get("ok"):
            msg += f' Auto-executed — {exec_result.get("summary", "decision recorded")}.'
        else:
            msg += f' Auto-execute failed: {exec_result.get("error", "unknown")}. Agent can retry.'
    else:
        msg += ' Agent can retry the command.'
    return f'<p style="color:{status_color};">{msg}</p>'


def _is_inception_decide(command_preview: str) -> bool:
    """Detect `fw inception decide T-XXX go|no-go --rationale ...` shape."""
    # T-1567 / F1: raw-string + double-escape produced literal `\d`/`\s`/`\b`
    # that never matched. Auto-exec on Watchtower-approved Tier-0 inception
    # decisions was dead code from T-1192 until this fix.
    return bool(re.search(r"(?:^|/|\s)fw inception decide T-\d+ (?:go|no-go)\b", command_preview))


def _execute_inception_decide(command_preview: str) -> dict:
    """Run the approved `fw inception decide` command and return a status dict."""
    import shlex
    import subprocess

    cmd_str = " ".join(command_preview.split())
    # T-1567 / F1: same dead-code regex bug as _is_inception_decide above.
    m = re.search(r"fw inception decide (T-\d+) (go|no-go)", cmd_str)
    if not m:
        return {"ok": False, "error": "could not parse command", "summary": "", "stdout_tail": ""}
    task_id, verdict = m.group(1), m.group(2)
    rat_m = re.search(r'--rationale\s+"(.*)"(?:\s|$)', cmd_str, re.DOTALL)
    rationale = rat_m.group(1) if rat_m else "Approved via Watchtower (no rationale captured)"

    fw_bin = str(PROJECT_ROOT / ".agentic-framework" / "bin" / "fw")
    if not Path(fw_bin).exists():
        fw_bin = "fw"

    argv = [fw_bin, "inception", "decide", task_id, verdict, "--rationale", rationale]
    try:
        # T-1193: strip CLAUDECODE so the inner gate (T-679/T-1259) treats this as a
        # human action routed through Watchtower, not an agent invocation. TIER0_AUTOEXEC
        # signals the outer hook that this subprocess was authorized via approvals.
        subproc_env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
        subproc_env["TIER0_AUTOEXEC"] = "1"
        proc = subprocess.run(
            argv, cwd=str(PROJECT_ROOT),
            env=subproc_env,
            capture_output=True, text=True, timeout=30,
        )
        stdout_tail = (proc.stdout or "")[-400:]
        if proc.returncode == 0:
            return {"ok": True, "summary": f"{task_id} decided {verdict}", "error": None, "stdout_tail": stdout_tail}
        return {"ok": False, "error": (proc.stderr or "").strip()[:400] or f"exit {proc.returncode}", "summary": "", "stdout_tail": stdout_tail}
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "timeout (30s)", "summary": "", "stdout_tail": ""}
    except Exception as e:
        return {"ok": False, "error": f"{type(e).__name__}: {e}", "summary": "", "stdout_tail": ""}


@bp.route("/api/approvals/complete-batch", methods=["POST"])
def complete_batch():
    """Complete all tasks where ALL Human ACs are checked (T-846).

    This is a human-initiated batch action from the Watchtower UI.
    Only completes tasks that are fully ready (no unchecked ACs).
    """
    import subprocess

    pending_acs = _load_pending_human_acs()

    # Find tasks where ALL human ACs are checked
    ready_tasks = []
    for t in pending_acs:
        unchecked = [ac for ac in t["human_acs"] if not ac["checked"]]
        if not unchecked:
            ready_tasks.append(t["task_id"])

    if not ready_tasks:
        return '<p style="color:var(--pico-muted-color);">No tasks ready for completion (all have unchecked ACs).</p>'

    completed = []
    errors = []
    fw_path = str(PROJECT_ROOT / "bin" / "fw")

    for task_id in ready_tasks:
        try:
            # T-1568 / F2: narrow flags instead of --force. Batch operates on
            # partial-complete tasks (already work-completed in active/) where
            # the human is authorising closure regardless of unchecked Human
            # ACs — same auth-flag semantics T-1559 fixed for the recheck
            # branch. Recommendation + RCA gates do not re-fire on the
            # partial-complete recheck path so no skip needed for those.
            result = subprocess.run(
                [fw_path, "task", "update", task_id, "--status", "work-completed",
                 "--skip-sovereignty", "--skip-verification", "--skip-acceptance-criteria",
                 "--reason", "Batch completed via Watchtower UI (human action)"],
                capture_output=True, text=True, timeout=30,
                cwd=str(PROJECT_ROOT)
            )
            if result.returncode == 0:
                completed.append(task_id)
            else:
                errors.append(f"{task_id}: {result.stderr[:100]}")
        except Exception as e:
            errors.append(f"{task_id}: {str(e)[:100]}")

    parts = []
    if completed:
        parts.append(f'<p style="color:var(--pico-ins-color);">Completed {len(completed)} task(s): {", ".join(completed)}</p>')
    if errors:
        parts.append(f'<p style="color:var(--pico-del-color);">Errors ({len(errors)}): {"<br>".join(errors)}</p>')

    return "\n".join(parts)
