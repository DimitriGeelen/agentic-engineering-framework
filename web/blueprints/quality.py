"""Quality Gate blueprint — audit results, traceability, episodic completeness, tests."""

import os
import re as re_mod
import subprocess

from flask import Blueprint, render_template, request

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT, render_page, load_yaml

bp = Blueprint("quality", __name__)


def _load_latest_audit():
    """Find and parse the latest audit YAML file.

    Returns (timestamp, summary, findings) or (None, {}, []).
    """
    audit_dir = PROJECT_ROOT / ".context" / "audits"
    if not audit_dir.exists():
        return None, {}, []

    audit_files = sorted(audit_dir.glob("*.yaml"), reverse=True)
    if not audit_files:
        return None, {}, []

    data = load_yaml(audit_files[0], label="audit report")

    if not data:
        return None, {}, []

    timestamp = data.get("timestamp", "Unknown")
    summary = data.get("summary", {})
    findings = data.get("findings", [])
    return timestamp, summary, findings


def _compute_audit_status(summary):
    """Derive overall gate status from summary counts."""
    if summary.get("fail", 0) > 0:
        return "FAIL"
    if summary.get("warn", 0) > 0:
        return "WARN"
    return "PASS"


def _compute_traceability():
    """Calculate percentage of commits referencing a T-XXX task.

    Scans the last 200 commits (subject line) for the T-\\d+ pattern.
    Returns an int 0..100.
    """
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", "-200", "--format=%s"],
            capture_output=True,
            text=True,
            timeout=10,
            cwd=str(PROJECT_ROOT),
        )
        if result.returncode != 0 or not result.stdout.strip():
            return 0

        lines = [line for line in result.stdout.strip().split("\n") if line.strip()]
        if not lines:
            return 0

        total = len(lines)
        traced = sum(1 for line in lines if re_mod.search(r"T-\d+", line))
        return int(round(traced / total * 100))
    except Exception:
        return 0


def _compute_episodic():
    """Count episodic files vs completed tasks.

    Returns (episodic_count, completed_count).
    """
    episodic_dir = PROJECT_ROOT / ".context" / "episodic"
    completed_dir = PROJECT_ROOT / ".tasks" / "completed"

    episodic_count = len(list(episodic_dir.glob("T-*.yaml"))) if episodic_dir.exists() else 0
    completed_count = (
        len(list(completed_dir.glob("T-*.md"))) if completed_dir.exists() else 0
    )
    return episodic_count, completed_count


def _render_audit_fragment(findings, summary, audit_status, audit_timestamp):
    """Render the audit results section as an HTML fragment."""
    return render_template(
        "_quality_audit_fragment.html",
        findings=findings,
        audit_summary=summary,
        audit_status=audit_status,
        audit_timestamp=audit_timestamp,
    )


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@bp.route("/quality")
def quality_gate():
    """Main quality gate page."""
    audit_timestamp, summary, findings = _load_latest_audit()
    audit_status = _compute_audit_status(summary)
    traceability = _compute_traceability()
    episodic_complete, episodic_total = _compute_episodic()

    return render_page(
        "quality.html",
        page_title="Quality Gate",
        audit_status=audit_status,
        audit_summary=summary,
        findings=findings,
        traceability=traceability,
        episodic_complete=episodic_complete,
        episodic_total=episodic_total,
        test_results=None,
        audit_timestamp=audit_timestamp,
    )


@bp.route("/api/audit/run", methods=["POST"])
def run_audit():
    """Execute fw audit and return updated audit section as htmx fragment."""
    try:
        result = subprocess.run(
            [str(FRAMEWORK_ROOT / "bin" / "fw"), "audit"],
            capture_output=True,
            text=True,
            timeout=180,
            env={**os.environ, "PROJECT_ROOT": str(PROJECT_ROOT)},
        )
    except subprocess.TimeoutExpired:
        return '<article style="border-left: 4px solid var(--pico-del-color);"><p><strong>Audit timed out</strong> after 180 seconds.</p></article>'
    except Exception as exc:
        return '<article style="border-left: 4px solid var(--pico-del-color);"><p><strong>Audit error:</strong> {}</p></article>'.format(
            str(exc)
        )

    # Reload the latest audit results (fw audit writes a new YAML file)
    audit_timestamp, summary, findings = _load_latest_audit()
    audit_status = _compute_audit_status(summary)

    return _render_audit_fragment(findings, summary, audit_status, audit_timestamp)


@bp.route("/api/tests/run", methods=["POST"])
def run_tests():
    """Execute fw test and return results as htmx fragment."""
    try:
        result = subprocess.run(
            [str(FRAMEWORK_ROOT / "bin" / "fw"), "test"],
            capture_output=True,
            text=True,
            timeout=300,
            env={**os.environ, "PROJECT_ROOT": str(PROJECT_ROOT)},
        )
    except subprocess.TimeoutExpired:
        return '<article style="border-left: 4px solid var(--pico-del-color);"><p><strong>Tests timed out</strong> after 300 seconds.</p></article>'
    except Exception as exc:
        return '<article style="border-left: 4px solid var(--pico-del-color);"><p><strong>Test error:</strong> {}</p></article>'.format(
            str(exc)
        )

    output = result.stdout or ""
    stderr = result.stderr or ""
    passed = result.returncode == 0

    # Try to extract pass/fail counts from pytest output
    pass_count = 0
    fail_count = 0
    summary_line = ""
    for line in (output + stderr).split("\n"):
        if " passed" in line or " failed" in line or " error" in line:
            summary_line = line.strip()
            # Parse "X passed, Y failed" patterns
            m_pass = re_mod.search(r"(\d+) passed", line)
            m_fail = re_mod.search(r"(\d+) failed", line)
            if m_pass:
                pass_count = int(m_pass.group(1))
            if m_fail:
                fail_count = int(m_fail.group(1))

    status_color = "var(--pico-ins-color)" if passed else "var(--pico-del-color)"
    status_label = "PASSED" if passed else "FAILED"

    html = '<article style="border-left: 4px solid {};">'.format(status_color)
    html += "<header><strong>Test Results: {}</strong></header>".format(status_label)

    if pass_count or fail_count:
        html += "<p>{} passed, {} failed</p>".format(pass_count, fail_count)

    if summary_line:
        html += "<p><small>{}</small></p>".format(summary_line)

    if not passed and (output or stderr):
        # Show failure details in a pre block
        detail = stderr if stderr else output
        # Truncate long output
        if len(detail) > 3000:
            detail = detail[:3000] + "\n... (truncated)"
        html += "<details open><summary>Failure Details</summary>"
        html += "<pre><code>{}</code></pre></details>".format(
            detail.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        )

    html += "</article>"
    return html
