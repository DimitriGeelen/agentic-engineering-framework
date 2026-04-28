# web/blueprints/cockpit.py
"""Cockpit blueprint — scan-driven interactive dashboard.

Renders the Watchtower cockpit when scan data exists, with:
- Needs Decision (amber) — items requiring SOVEREIGNTY
- Framework Recommends (blue) — Tier 1 suggestions
- Work Direction — prioritized work queue
- Opportunities (green) — low priority improvements
- System Health + Recent Activity

All control actions shell out to existing fw CLI commands.
"""

import logging
import re as re_mod
from datetime import datetime, timezone
from pathlib import Path

import yaml
from flask import Blueprint, request, render_template

logger = logging.getLogger(__name__)

from web.shared import PROJECT_ROOT, render_page, load_scan, extract_recommendation_verdict, extract_recommendation_state
from web.subprocess_utils import run_fw_command

bp = Blueprint("cockpit", __name__)



def get_scan_age(scan_data: dict) -> str:
    """Human-readable age of the scan."""
    ts = scan_data.get("timestamp")
    if not ts:
        return "unknown"
    try:
        scan_time = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        delta = datetime.now(timezone.utc) - scan_time
        minutes = int(delta.total_seconds() // 60)
        if minutes < 1:
            return "just now"
        elif minutes < 60:
            return f"{minutes}m ago"
        elif minutes < 1440:
            return f"{minutes // 60}h ago"
        else:
            return f"{minutes // 1440}d ago"
    except (ValueError, TypeError):
        return "unknown"


def get_human_verify_tasks() -> list:
    """Find active tasks with unchecked ### Human ACs (T-193).

    T-1577: Use canonical `_parse_acceptance_criteria` (web/blueprints/tasks.py)
    instead of a local regex. The local regex matched checkboxes inside HTML
    template comments, over-counting against /approvals' canonical parser
    (L-298 cross-surface count divergence). One parser, one source of truth.
    """
    from web.blueprints.tasks import _parse_acceptance_criteria

    active_dir = PROJECT_ROOT / ".tasks" / "active"
    results = []
    if not active_dir.is_dir():
        return results

    for fn in sorted(active_dir.iterdir()):
        if not fn.name.endswith(".md"):
            continue
        text = fn.read_text(errors="replace")

        # Parse frontmatter
        fm = {}
        if text.startswith("---"):
            try:
                end = text.index("---", 3)
                fm = yaml.safe_load(text[3:end]) or {}
            except Exception as e:
                logger.warning("Failed to parse frontmatter in %s: %s", fn, e)

        # Body = text minus frontmatter (canonical parser expects body only)
        body = text
        if text.startswith("---"):
            try:
                end = text.index("---", 3)
                body = text[end + 3:]
            except ValueError:
                pass

        all_acs = _parse_acceptance_criteria(body)
        human_acs = [ac for ac in all_acs if ac.get("section") == "human"]
        if not human_acs:
            continue

        total = len(human_acs)
        checked = sum(1 for ac in human_acs if ac["checked"])
        if total > 0 and checked < total:
            unchecked = [ac["text"] for ac in human_acs if not ac["checked"]]
            # T-1533: surface agent recommendation verdict for landing-page widget
            # T-1577: also surface state to distinguish NO-REC from unparseable `?`
            verdict = extract_recommendation_verdict(text)
            state = extract_recommendation_state(text)
            results.append({
                "task_id": fm.get("id", fn.stem),
                "name": fm.get("name", ""),
                "status": fm.get("status", "?"),
                "total": total,
                "checked": checked,
                "unchecked_items": unchecked,
                "verdict": verdict,
                "state": state,
            })
    return results


def get_action_summary() -> dict:
    """Build unified action summary: Tier 0 + GO decisions + Human ACs (T-645).

    Returns dict with counts and top tasks for the landing page summary card.
    """
    human_verify = get_human_verify_tasks()
    human_ac_count = sum(t["total"] - t["checked"] for t in human_verify)

    # Count pending Tier 0 approvals
    tier0_count = 0
    approvals_dir = PROJECT_ROOT / ".context" / "approvals"
    if approvals_dir.exists():
        tier0_count = len(list(approvals_dir.glob("pending-*.yaml")))

    # Count pending GO decisions (inception tasks without decision)
    go_count = 0
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    if active_dir.is_dir():
        for fn in active_dir.iterdir():
            if not fn.name.endswith(".md"):
                continue
            text = fn.read_text(errors="replace")
            if "workflow_type: inception" not in text:
                continue
            has_decision = False
            for line in text.split("\n"):
                stripped = line.strip()
                if stripped.startswith("**Decision**:") or stripped.startswith("**Decision:**"):
                    val = stripped.split(":", 1)[1].strip().strip("*").strip()
                    if val and val != "<!--" and val.lower() != "pending":
                        has_decision = True
                        break
            if not has_decision:
                go_count += 1

    top_tasks = sorted(human_verify, key=lambda t: t["total"] - t["checked"], reverse=True)[:3]

    # T-1533: aggregate verdict counts for the landing-page Action Required widget
    go_ac_count = sum(1 for t in human_verify if t.get("verdict") == "GO")
    defer_ac_count = sum(1 for t in human_verify if t.get("verdict") == "DEFER")
    nogo_ac_count = sum(1 for t in human_verify if t.get("verdict") == "NO-GO")
    # T-1577: split NO-REC (no Recommendation block) from `?` (block exists, verdict unparseable).
    # State is authoritative; verdict alone collapses both into `?` (compat shim).
    no_rec_ac_count = sum(1 for t in human_verify if t.get("state") == "NO-REC")
    unknown_ac_count = sum(1 for t in human_verify if t.get("state") == "?")

    return {
        "tier0_count": tier0_count,
        "go_count": go_count,
        "human_ac_count": human_ac_count,
        "human_ac_task_count": len(human_verify),
        "total": tier0_count + go_count + len(human_verify),
        "top_tasks": top_tasks,
        "go_ac_count": go_ac_count,
        "defer_ac_count": defer_ac_count,
        "nogo_ac_count": nogo_ac_count,
        "no_rec_ac_count": no_rec_ac_count,
        "unknown_ac_count": unknown_ac_count,
    }


def _get_test_counts() -> dict:
    """Count test files per suite (T-1010)."""
    from web.shared import FRAMEWORK_ROOT
    counts = {}
    for name, subdir, pattern in [
        ("playwright", "tests/playwright", "test_*.py"),
        ("unit", "tests/unit", "*.bats"),
        ("integration", "tests/integration", "*.bats"),
    ]:
        d = FRAMEWORK_ROOT / subdir
        if d.exists():
            counts[name] = len(list(d.glob(pattern)))
    return counts


def get_cockpit_context(scan_data: dict) -> dict:
    """Build template context from scan data."""
    return {
        "scan": scan_data,
        "scan_age": get_scan_age(scan_data),
        "needs_decision": scan_data.get("needs_decision", [])[:3],
        "needs_decision_total": len(scan_data.get("needs_decision", [])),
        "framework_recommends": scan_data.get("framework_recommends", [])[:3],
        "framework_recommends_total": len(scan_data.get("framework_recommends", [])),
        "opportunities": scan_data.get("opportunities", [])[:3],
        "opportunities_total": len(scan_data.get("opportunities", [])),
        "work_queue": scan_data.get("work_queue", []),
        "risks": scan_data.get("risks", []),
        "health": scan_data.get("project_health", {}),
        "antifragility": scan_data.get("antifragility", {}),
        "summary": scan_data.get("summary", ""),
        "warnings": scan_data.get("warnings", []),
        "recent_failures": scan_data.get("recent_failures", []),
        "scan_status": scan_data.get("scan_status", "unknown"),
        "human_verify": get_human_verify_tasks(),
        "action_summary": get_action_summary(),
        "test_counts": _get_test_counts(),
    }


# ---------------------------------------------------------------------------
# Control action endpoints
# ---------------------------------------------------------------------------

def _escape(text):
    """Escape HTML."""
    return (text.replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace('"', "&quot;"))


@bp.route("/api/scan/refresh", methods=["POST"])
def scan_refresh():
    """Trigger a fresh scan and return updated cockpit content."""
    stdout, stderr, ok = run_fw_command(["scan", "--quiet"])
    if ok:
        scan_data = load_scan()
        if scan_data:
            ctx = get_cockpit_context(scan_data)
            return render_template("cockpit.html", **ctx)
        return '<p style="color:var(--pico-del-color)">Scan succeeded but output not found.</p>', 500
    return f'<p style="color:var(--pico-del-color)">Scan failed: {_escape(stderr[:300])}</p>', 500


@bp.route("/api/scan/approve/<rec_id>", methods=["POST"])
def scan_approve(rec_id):
    """Approve a needs_decision recommendation."""
    scan_data = load_scan()
    if not scan_data:
        return '<p style="color:var(--pico-del-color)">No scan data.</p>', 400

    rec = None
    for item in scan_data.get("needs_decision", []):
        if item.get("id") == rec_id:
            rec = item
            break
    if not rec:
        return f'<p style="color:var(--pico-del-color)">Recommendation {_escape(rec_id)} not found.</p>', 404

    action = rec.get("suggested_action", {})
    if isinstance(action, dict) and "command" in action:
        cmd_parts = action["command"].split() + (action.get("args", "").split() if action.get("args") else [])
        stdout, stderr, ok = run_fw_command(cmd_parts)
        if ok:
            rec_type = rec.get("type", "unknown")
            run_fw_command(["context", "add-decision",
                 f"Approved: {rec.get('summary', rec_id)}",
                 "--rationale", "Scan recommendation approved",
                 "--source", "scan",
                 "--recommendation-type", rec_type])
            return f'<p style="color:var(--pico-ins-color)">Approved: {_escape(rec.get("summary", rec_id)[:100])}</p>'
        return f'<p style="color:var(--pico-del-color)">Action failed: {_escape(stderr[:200])}</p>', 500

    return f'<p style="color:var(--pico-del-color)">No executable action for {_escape(rec_id)}.</p>', 400


@bp.route("/api/scan/defer/<rec_id>", methods=["POST"])
def scan_defer(rec_id):
    """Defer a needs_decision recommendation with reason."""
    reason = request.form.get("reason", "Deferred by user").strip()

    scan_data = load_scan()
    if not scan_data:
        return '<p style="color:var(--pico-del-color)">No scan data.</p>', 400

    rec = None
    for item in scan_data.get("needs_decision", []):
        if item.get("id") == rec_id:
            rec = item
            break
    if not rec:
        return f'<p style="color:var(--pico-del-color)">Not found: {_escape(rec_id)}.</p>', 404

    rec_type = rec.get("type", "unknown")
    run_fw_command(["context", "add-decision",
         f"Deferred: {rec.get('summary', rec_id)}",
         "--rationale", reason,
         "--source", "scan",
         "--recommendation-type", rec_type])

    return f'<p style="color:var(--pico-muted-color)">Deferred: {_escape(rec.get("summary", rec_id)[:100])}</p>'


@bp.route("/api/scan/apply/<rec_id>", methods=["POST"])
def scan_apply(rec_id):
    """Apply a framework_recommends recommendation."""
    scan_data = load_scan()
    if not scan_data:
        return '<p style="color:var(--pico-del-color)">No scan data.</p>', 400

    rec = None
    for item in scan_data.get("framework_recommends", []):
        if item.get("id") == rec_id:
            rec = item
            break
    if not rec:
        return f'<p style="color:var(--pico-del-color)">Not found: {_escape(rec_id)}.</p>', 404

    action = rec.get("recommended_action", {})
    if isinstance(action, dict) and "command" in action:
        cmd_parts = action["command"].split() + (action.get("args", "").split() if action.get("args") else [])
        stdout, stderr, ok = run_fw_command(cmd_parts)
        if ok:
            return f'<p style="color:var(--pico-ins-color)">Applied: {_escape(rec.get("summary", rec_id)[:100])}</p>'
        return f'<p style="color:var(--pico-del-color)">Failed: {_escape(stderr[:200])}</p>', 500

    return f'<p style="color:var(--pico-del-color)">No action for {_escape(rec_id)}.</p>', 400


@bp.route("/api/scan/focus/<task_id>", methods=["POST"])
def scan_focus(task_id):
    """Set focus to a task from the work queue."""
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        return '<p style="color:var(--pico-del-color)">Invalid task ID.</p>', 400
    stdout, stderr, ok = run_fw_command(["context", "focus", task_id])
    if ok:
        return f'<p style="color:var(--pico-ins-color)">Focus set to {_escape(task_id)}</p>'
    return f'<p style="color:var(--pico-del-color)">Failed: {_escape(stderr[:200])}</p>', 500
