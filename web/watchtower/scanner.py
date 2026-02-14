# web/watchtower/scanner.py
"""Watchtower scan engine — reads project state, writes structured YAML.

This module is Framework AUTHORITY: it reads all project state (Tier 3:
pre-approved diagnostic) and writes structured YAML to .context/scans/.
It NEVER directly mutates tasks, patterns, or context.
"""

import os
import re
import subprocess
from datetime import datetime, timedelta, timezone
from pathlib import Path

import yaml


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def scan(project_root=None, framework_root=None):
    """Run a full project scan. Returns structured scan result dict."""
    project_root = Path(project_root or os.environ.get("PROJECT_ROOT", "."))
    framework_root = Path(
        framework_root or os.environ.get("FRAMEWORK_ROOT", str(project_root))
    )

    errors = []
    inputs = gather_inputs(project_root, framework_root, errors)

    # These imports will fail until Tasks 2-3 are complete
    try:
        from .rules import run_all_rules
        from .prioritizer import prioritize_work_queue
        from .feedback import compute_feedback

        needs_decision, framework_recommends, opportunities, risks = run_all_rules(inputs)
        work_queue = prioritize_work_queue(inputs)
        antifragility = compute_feedback(inputs)
    except ImportError:
        needs_decision = []
        framework_recommends = []
        opportunities = []
        risks = []
        work_queue = []
        antifragility = {}

    scan_id = f"SC-{datetime.now(timezone.utc).strftime('%Y-%m%d-%H%M%S')}"
    scan_status = "complete" if not errors else "partial"

    output = {
        "schema_version": 1,
        "scan_id": scan_id,
        "scan_status": scan_status,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "errors": errors,
        "summary": generate_summary(inputs, needs_decision, framework_recommends, risks, work_queue),
        "project_health": compute_health(inputs),
        "antifragility": antifragility,
        "needs_decision": needs_decision,
        "framework_recommends": framework_recommends,
        "opportunities": opportunities,
        "work_queue": work_queue,
        "risks": risks,
        "changes_since_last_scan": compute_delta(inputs, needs_decision, framework_recommends),
        "recent_failures": extract_failures(inputs),
        "warnings": extract_warnings(inputs),
    }

    write_scan(project_root, scan_id, output)
    return output


def gather_inputs(project_root, framework_root, errors=None):
    """Read all project state into a single dict.

    This is a pure read operation — no mutations. Gracefully handles
    missing directories and malformed files.
    """
    if errors is None:
        errors = []

    project_root = Path(project_root)
    framework_root = Path(framework_root)

    # Active tasks
    active_tasks = []
    active_dir = project_root / ".tasks" / "active"
    if active_dir.exists():
        for f in sorted(active_dir.glob("T-*.md")):
            task = parse_task(f)
            if task:
                active_tasks.append(task)

    # Completed tasks
    completed_tasks = []
    completed_dir = project_root / ".tasks" / "completed"
    if completed_dir.exists():
        for f in sorted(completed_dir.glob("T-*.md")):
            task = parse_task(f)
            if task:
                completed_tasks.append(task)

    # Project memory files
    project_dir = project_root / ".context" / "project"
    patterns = load_yaml(project_dir / "patterns.yaml")
    learnings = load_yaml(project_dir / "learnings.yaml")
    practices = load_yaml(project_dir / "practices.yaml")
    decisions = load_yaml(project_dir / "decisions.yaml")
    gaps = load_yaml(project_dir / "gaps.yaml")

    # Audits — load all audit files
    audits = []
    audits_dir = project_root / ".context" / "audits"
    if audits_dir.exists():
        for f in sorted(audits_dir.glob("*.yaml"), reverse=True):
            data = load_yaml(f)
            if data:
                audits.append(data)

    # Handover — read latest as raw text
    handover = None
    handover_path = project_root / ".context" / "handovers" / "LATEST.md"
    if handover_path.exists():
        try:
            handover = handover_path.read_text(errors="replace")
        except Exception:
            pass

    # Previous scan (for delta computation)
    previous_scan = None
    latest_scan = project_root / ".context" / "scans" / "LATEST.yaml"
    if latest_scan.exists():
        previous_scan = load_yaml(latest_scan)

    # Git log (last 20 commits)
    git_log = []
    try:
        result = subprocess.run(
            ["git", "-C", str(project_root), "log", "--oneline", "-20"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode == 0 and result.stdout.strip():
            git_log = result.stdout.strip().split("\n")
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    return {
        "active_tasks": active_tasks,
        "completed_tasks": completed_tasks,
        "patterns": patterns,
        "learnings": learnings,
        "practices": practices,
        "decisions": decisions,
        "gaps": gaps,
        "audits": audits,
        "handover": handover,
        "previous_scan": previous_scan,
        "project_root": str(project_root),
        "framework_root": str(framework_root),
        "git_log": git_log,
    }


def write_scan(project_root, scan_id, output):
    """Write scan output as YAML and update LATEST.yaml symlink."""
    project_root = Path(project_root)
    scans_dir = project_root / ".context" / "scans"
    scans_dir.mkdir(parents=True, exist_ok=True)

    scan_file = scans_dir / f"{scan_id}.yaml"
    with open(scan_file, "w") as f:
        yaml.dump(output, f, default_flow_style=False, sort_keys=False)

    # Update LATEST.yaml symlink
    latest = scans_dir / "LATEST.yaml"
    if latest.exists() or latest.is_symlink():
        latest.unlink()
    latest.symlink_to(scan_file.name)


# ---------------------------------------------------------------------------
# Task parsing
# ---------------------------------------------------------------------------

def parse_task(path):
    """Parse a task markdown file with YAML frontmatter.

    Returns the frontmatter dict or None on failure.
    """
    try:
        text = Path(path).read_text(errors="replace")
    except Exception:
        return None

    # Extract YAML frontmatter between --- markers
    match = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if not match:
        return None

    try:
        data = yaml.safe_load(match.group(1))
        if isinstance(data, dict):
            return data
    except Exception:
        pass

    return None


def load_yaml(path):
    """Safely load a YAML file. Returns empty dict on missing/invalid."""
    path = Path(path)
    if not path.exists():
        return {}
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


# ---------------------------------------------------------------------------
# Summary & health helpers
# ---------------------------------------------------------------------------

def generate_summary(inputs, needs_decision, framework_recommends, risks, work_queue):
    """Generate a human-readable summary dict."""
    active = inputs["active_tasks"]
    completed = inputs["completed_tasks"]
    issues_tasks = [t for t in active if t.get("status") == "issues"]

    return {
        "active_tasks": len(active),
        "completed_tasks": len(completed),
        "tasks_with_issues": len(issues_tasks),
        "needs_decision_count": len(needs_decision),
        "framework_recommends_count": len(framework_recommends),
        "risk_count": len(risks),
        "work_queue_size": len(work_queue),
        "audit_status": _get_audit_status(inputs),
        "velocity": _compute_velocity(completed),
    }


def compute_health(inputs):
    """Compute project health indicators."""
    active = inputs["active_tasks"]
    completed = inputs["completed_tasks"]
    now = datetime.now(timezone.utc)

    # Stale tasks: no update in 14+ days
    stale_tasks = []
    for t in active:
        last_update = t.get("last_update")
        if last_update:
            try:
                if isinstance(last_update, str):
                    lu = datetime.fromisoformat(last_update.replace("Z", "+00:00"))
                elif isinstance(last_update, datetime):
                    lu = last_update if last_update.tzinfo else last_update.replace(tzinfo=timezone.utc)
                else:
                    continue
                if (now - lu).days >= 14:
                    stale_tasks.append(t.get("id", "unknown"))
            except (ValueError, TypeError):
                pass

    # Tasks with issues
    issue_tasks = [t.get("id", "unknown") for t in active if t.get("status") == "issues"]

    # Traceability
    traceability = _get_traceability(inputs)

    return {
        "stale_tasks": stale_tasks,
        "tasks_with_issues": issue_tasks,
        "audit_status": _get_audit_status(inputs),
        "traceability": traceability,
        "velocity": _compute_velocity(completed),
    }


def compute_delta(inputs, needs_decision, framework_recommends):
    """Compute changes since the last scan."""
    prev = inputs.get("previous_scan")
    if not prev:
        return {"first_scan": True}

    prev_summary = prev.get("summary", {})
    curr_active = len(inputs["active_tasks"])
    curr_completed = len(inputs["completed_tasks"])

    return {
        "first_scan": False,
        "active_tasks_delta": curr_active - prev_summary.get("active_tasks", 0),
        "completed_tasks_delta": curr_completed - prev_summary.get("completed_tasks", 0),
        "new_decisions_needed": len(needs_decision) - len(prev.get("needs_decision", [])),
        "new_recommendations": len(framework_recommends) - len(prev.get("framework_recommends", [])),
    }


def extract_failures(inputs):
    """Extract recent failure patterns for display."""
    patterns = inputs.get("patterns", {})
    failures = patterns.get("failure_patterns", [])
    # Return the 5 most recent
    return failures[:5] if failures else []


def extract_warnings(inputs):
    """Extract current warnings from audits and task state."""
    warnings = []

    # Audit warnings
    audits = inputs.get("audits", [])
    if audits:
        latest = audits[0]
        findings = latest.get("findings", [])
        for f in findings:
            if f.get("level") == "WARN":
                warnings.append({
                    "source": "audit",
                    "message": f.get("check", "Unknown warning"),
                })

    # Stale task warnings
    now = datetime.now(timezone.utc)
    for t in inputs.get("active_tasks", []):
        last_update = t.get("last_update")
        if last_update:
            try:
                if isinstance(last_update, str):
                    lu = datetime.fromisoformat(last_update.replace("Z", "+00:00"))
                elif isinstance(last_update, datetime):
                    lu = last_update if last_update.tzinfo else last_update.replace(tzinfo=timezone.utc)
                else:
                    continue
                days = (now - lu).days
                if days >= 14:
                    warnings.append({
                        "source": "task",
                        "message": f"{t.get('id', '?')} has not been updated in {days} days",
                    })
            except (ValueError, TypeError):
                pass

    return warnings


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _get_audit_status(inputs):
    """Get the latest audit status string."""
    audits = inputs.get("audits", [])
    if not audits:
        return "unknown"
    latest = audits[0]
    summary = latest.get("summary", {})
    if summary.get("fail", 0) > 0:
        return "FAIL"
    elif summary.get("warn", 0) > 0:
        return "WARN"
    return "PASS"


def _get_traceability(inputs):
    """Check if tasks have proper git traceability."""
    # Simple heuristic: count tasks vs completed tasks
    active = len(inputs.get("active_tasks", []))
    completed = len(inputs.get("completed_tasks", []))
    total = active + completed
    if total == 0:
        return {"score": 1.0, "total_tasks": 0}
    return {
        "score": completed / total if total > 0 else 0,
        "total_tasks": total,
        "completed": completed,
        "active": active,
    }


def _compute_velocity(completed_tasks):
    """Compute task completion velocity (tasks per week, last 30 days)."""
    if not completed_tasks:
        return {"tasks_per_week": 0, "window_days": 30}

    now = datetime.now(timezone.utc)
    window = timedelta(days=30)
    recent = []

    for t in completed_tasks:
        finished = t.get("date_finished")
        if finished and finished != "null":
            try:
                if isinstance(finished, str):
                    dt = datetime.fromisoformat(finished.replace("Z", "+00:00"))
                elif isinstance(finished, datetime):
                    dt = finished if finished.tzinfo else finished.replace(tzinfo=timezone.utc)
                else:
                    continue
                if (now - dt) <= window:
                    recent.append(dt)
            except (ValueError, TypeError):
                pass

    weeks = 30 / 7
    return {
        "tasks_per_week": round(len(recent) / weeks, 1) if weeks > 0 else 0,
        "window_days": 30,
        "completed_in_window": len(recent),
    }
