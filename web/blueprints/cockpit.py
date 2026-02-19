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

import os
import re as re_mod
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import yaml
from flask import Blueprint, request, render_template

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT, render_page

bp = Blueprint("cockpit", __name__)


def load_scan() -> dict | None:
    """Load the latest scan from .context/scans/LATEST.yaml."""
    latest = PROJECT_ROOT / ".context" / "scans" / "LATEST.yaml"
    if not latest.exists():
        return None
    try:
        with open(latest) as f:
            data = yaml.safe_load(f)
        if isinstance(data, dict) and data.get("schema_version"):
            return data
    except Exception:
        pass
    return None


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
    """Find active tasks with unchecked ### Human ACs (T-193)."""
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
            except Exception:
                pass

        # Find AC section
        ac_match = re_mod.search(
            r"^## Acceptance Criteria\s*\n(.*?)(?=\n## |\Z)", text,
            re_mod.MULTILINE | re_mod.DOTALL)
        if not ac_match:
            continue

        ac_section = ac_match.group(1)
        if "### Human" not in ac_section:
            continue

        human_match = re_mod.search(
            r"### Human\s*\n(.*?)(?=\n### |\Z)", ac_section, re_mod.DOTALL)
        if not human_match:
            continue

        human_block = human_match.group(1)
        total = len(re_mod.findall(r"^\s*-\s*\[[ x]\]", human_block, re_mod.MULTILINE))
        checked = len(re_mod.findall(r"^\s*-\s*\[x\]", human_block, re_mod.MULTILINE))
        if total > 0 and checked < total:
            unchecked = [m.strip() for m in re_mod.findall(
                r"^\s*-\s*\[ \]\s*(.*)", human_block, re_mod.MULTILINE)]
            results.append({
                "task_id": fm.get("id", fn.stem),
                "name": fm.get("name", ""),
                "status": fm.get("status", "?"),
                "total": total,
                "checked": checked,
                "unchecked_items": unchecked,
            })
    return results


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
    }


# ---------------------------------------------------------------------------
# Control action endpoints
# ---------------------------------------------------------------------------

def _fw(args, timeout=30):
    """Run a fw CLI command and return (stdout, stderr, ok)."""
    try:
        result = subprocess.run(
            [str(FRAMEWORK_ROOT / "bin" / "fw")] + args,
            capture_output=True, text=True, timeout=timeout,
            env={**os.environ, "PROJECT_ROOT": str(PROJECT_ROOT)},
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode == 0
    except subprocess.TimeoutExpired:
        return "", "Command timed out", False
    except Exception as exc:
        return "", str(exc), False


def _escape(text):
    """Escape HTML."""
    return (text.replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace('"', "&quot;"))


@bp.route("/api/scan/refresh", methods=["POST"])
def scan_refresh():
    """Trigger a fresh scan and return updated cockpit content."""
    stdout, stderr, ok = _fw(["scan", "--quiet"])
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
        stdout, stderr, ok = _fw(cmd_parts)
        if ok:
            rec_type = rec.get("type", "unknown")
            _fw(["context", "add-decision",
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
    _fw(["context", "add-decision",
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
        stdout, stderr, ok = _fw(cmd_parts)
        if ok:
            return f'<p style="color:var(--pico-ins-color)">Applied: {_escape(rec.get("summary", rec_id)[:100])}</p>'
        return f'<p style="color:var(--pico-del-color)">Failed: {_escape(stderr[:200])}</p>', 500

    return f'<p style="color:var(--pico-del-color)">No action for {_escape(rec_id)}.</p>', 400


@bp.route("/api/scan/focus/<task_id>", methods=["POST"])
def scan_focus(task_id):
    """Set focus to a task from the work queue."""
    if not re_mod.match(r"^T-\d{3}$", task_id):
        return '<p style="color:var(--pico-del-color)">Invalid task ID.</p>', 400
    stdout, stderr, ok = _fw(["context", "focus", task_id])
    if ok:
        return f'<p style="color:var(--pico-ins-color)">Focus set to {_escape(task_id)}</p>'
    return f'<p style="color:var(--pico-del-color)">Failed: {_escape(stderr[:200])}</p>', 500
