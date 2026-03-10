"""Session blueprint — session cockpit, git state, quick actions."""

import re as re_mod

import yaml
from flask import Blueprint, request, render_template

from web.shared import PROJECT_ROOT, render_page
from web.subprocess_utils import run_fw_command, run_git_command

bp = Blueprint("session", __name__)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


_git = run_git_command
_fw = run_fw_command


def _get_session_id():
    """Read the current session ID from working memory or latest handover."""
    # Try working memory first
    session_file = PROJECT_ROOT / ".context" / "working" / "session.yaml"
    if session_file.exists():
        try:
            with open(session_file) as f:
                data = yaml.safe_load(f)
            if isinstance(data, dict) and data.get("session_id"):
                return data["session_id"]
        except Exception:
            pass

    # Fall back to latest handover
    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    if handovers_dir.exists():
        sessions = sorted(handovers_dir.glob("S-*.md"), reverse=True)
        if sessions:
            return sessions[0].stem

    return None


def _get_focus_task():
    """Read the current focus task from working memory."""
    focus_file = PROJECT_ROOT / ".context" / "working" / "focus.yaml"
    if focus_file.exists():
        try:
            with open(focus_file) as f:
                data = yaml.safe_load(f)
            if isinstance(data, dict) and data.get("current_task"):
                return data["current_task"]
        except Exception:
            pass
    return None


def _escape_html(text):
    """Escape HTML special characters."""
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@bp.route("/api/session/status")
def session_status():
    """Return an htmx fragment with current session state."""
    session_id = _get_session_id()
    focus_task = _get_focus_task()

    # Git state
    branch, _ = _git(["branch", "--show-current"])
    porcelain, _ = _git(["status", "--porcelain"])
    changes_count = len([l for l in porcelain.split("\n") if l.strip()]) if porcelain else 0
    last_commit, _ = _git(["log", "-1", "--oneline"])

    return render_template(
        "_session_strip.html",
        session_id=session_id,
        branch=branch or "unknown",
        changes_count=changes_count,
        last_commit=last_commit or "(no commits)",
        focus_task=focus_task,
    )


@bp.route("/api/decision", methods=["POST"])
def record_decision():
    """Record a decision via fw context add-decision."""
    decision_text = request.form.get("decision", "").strip()
    task_id = request.form.get("task", "").strip()
    rationale = request.form.get("rationale", "").strip()

    if not decision_text:
        return '<p style="color: var(--pico-del-color);">Decision text is required.</p>', 400

    cmd = ["context", "add-decision", decision_text]
    if task_id:
        cmd.extend(["--task", task_id])
    if rationale:
        cmd.extend(["--rationale", rationale])

    stdout, stderr, ok = _fw(cmd)

    if ok:
        html = '<p style="color: var(--pico-ins-color);">Decision recorded.'
        if task_id:
            html += " ({})" .format(_escape_html(task_id))
        html += "</p>"
        return html
    else:
        error_msg = stderr or stdout or "Unknown error"
        return '<p style="color: var(--pico-del-color);">Error: {}</p>'.format(
            _escape_html(error_msg[:300])
        ), 500


@bp.route("/api/learning", methods=["POST"])
def record_learning():
    """Record a learning via fw context add-learning."""
    learning_text = request.form.get("learning", "").strip()
    task_id = request.form.get("task", "").strip()
    source = request.form.get("source", "").strip()

    if not learning_text:
        return '<p style="color: var(--pico-del-color);">Learning text is required.</p>', 400

    cmd = ["context", "add-learning", learning_text]
    if task_id:
        cmd.extend(["--task", task_id])
    if source:
        cmd.extend(["--source", source])

    stdout, stderr, ok = _fw(cmd)

    if ok:
        html = '<p style="color: var(--pico-ins-color);">Learning recorded.'
        if task_id:
            html += " ({})".format(_escape_html(task_id))
        html += "</p>"
        return html
    else:
        error_msg = stderr or stdout or "Unknown error"
        return '<p style="color: var(--pico-del-color);">Error: {}</p>'.format(
            _escape_html(error_msg[:300])
        ), 500


@bp.route("/api/session/init", methods=["POST"])
def session_init():
    """Initialize a session via fw context init."""
    stdout, stderr, ok = _fw(["context", "init"])

    if ok:
        html = '<article style="border-left: 4px solid var(--pico-ins-color);">'
        html += "<p><strong>Session initialized.</strong></p>"
        if stdout:
            html += "<p><small>{}</small></p>".format(_escape_html(stdout[:500]))
        html += "</article>"
        return html
    else:
        error_msg = stderr or stdout or "Unknown error"
        html = '<article style="border-left: 4px solid var(--pico-del-color);">'
        html += "<p><strong>Failed to initialize session.</strong></p>"
        html += "<p><small>{}</small></p>".format(_escape_html(error_msg[:500]))
        html += "</article>"
        return html, 500


@bp.route("/api/healing/<task_id>", methods=["POST"])
def healing_diagnose(task_id):
    """Run healing diagnosis via fw healing diagnose."""
    if not re_mod.match(r"^T-\d{3}$", task_id):
        return '<p style="color: var(--pico-del-color);">Invalid task ID format.</p>', 400

    stdout, stderr, ok = _fw(["healing", "diagnose", task_id], timeout=60)

    output = stdout or stderr or "No output"
    status_color = "var(--pico-ins-color)" if ok else "var(--pico-del-color)"
    status_label = "Diagnosis Complete" if ok else "Diagnosis Failed"

    html = '<article style="border-left: 4px solid {};">'.format(status_color)
    html += "<header><strong>{}: {}</strong></header>".format(
        _escape_html(task_id), status_label
    )
    html += "<pre><code>{}</code></pre>".format(_escape_html(output[:3000]))
    html += "</article>"
    return html
