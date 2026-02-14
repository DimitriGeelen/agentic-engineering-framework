"""Metrics blueprint — project health dashboard."""

import re as re_mod
import subprocess
from datetime import datetime, timezone

import yaml
from flask import Blueprint

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("metrics", __name__)


def _load_yaml(path):
    """Safely load a YAML file, return empty dict on failure."""
    if not path.exists():
        return {}
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _task_counts():
    """Count active and completed tasks."""
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    completed_dir = PROJECT_ROOT / ".tasks" / "completed"
    active = len(list(active_dir.glob("T-*.md"))) if active_dir.exists() else 0
    completed = len(list(completed_dir.glob("T-*.md"))) if completed_dir.exists() else 0
    return active, completed


def _traceability():
    """Percentage of recent commits referencing T-XXX."""
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", "-200", "--format=%s"],
            capture_output=True, text=True, timeout=10,
            cwd=str(PROJECT_ROOT),
        )
        if result.returncode != 0 or not result.stdout.strip():
            return 0
        lines = [l for l in result.stdout.strip().split("\n") if l.strip()]
        if not lines:
            return 0
        total = len(lines)
        traced = sum(1 for l in lines if re_mod.search(r"T-\d+", l))
        return int(round(traced / total * 100))
    except Exception:
        return 0


def _quality_scores():
    """Compute description quality % and acceptance criteria coverage %."""
    desc_ok = 0
    ac_ok = 0
    total = 0

    for d in [PROJECT_ROOT / ".tasks" / "active", PROJECT_ROOT / ".tasks" / "completed"]:
        if not d.exists():
            continue
        for f in d.glob("T-*.md"):
            total += 1
            content = f.read_text(errors="replace")
            fm_match = re_mod.match(r"^---\n(.*?)\n---", content, re_mod.DOTALL)
            if fm_match:
                try:
                    fm = yaml.safe_load(fm_match.group(1))
                except yaml.YAMLError:
                    continue
                if isinstance(fm, dict):
                    desc = fm.get("description", "")
                    if isinstance(desc, str) and len(desc.strip()) >= 50:
                        desc_ok += 1
            if re_mod.search(r"(?i)(acceptance.criteria|## AC|## Acceptance)", content):
                ac_ok += 1

    if total == 0:
        return 0, 0
    return int(round(desc_ok / total * 100)), int(round(ac_ok / total * 100))


def _knowledge_counts():
    """Count learnings, patterns, decisions, practices."""
    project_dir = PROJECT_ROOT / ".context" / "project"

    lf = _load_yaml(project_dir / "learnings.yaml")
    learnings = len(lf.get("learnings", []))

    pf = _load_yaml(project_dir / "patterns.yaml")
    patterns = (
        len(pf.get("failure_patterns", []))
        + len(pf.get("success_patterns", []))
        + len(pf.get("antifragile_patterns", []))
        + len(pf.get("workflow_patterns", []))
    )

    df = _load_yaml(project_dir / "decisions.yaml")
    decisions = len(df.get("decisions", []))

    pr = _load_yaml(project_dir / "practices.yaml")
    practices = len(pr.get("practices", []))

    return {"learnings": learnings, "patterns": patterns, "decisions": decisions, "practices": practices}


def _recent_commits():
    """Get last 10 commits as (hash, message, has_task_ref) tuples."""
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", "-10"],
            capture_output=True, text=True, timeout=10,
            cwd=str(PROJECT_ROOT),
        )
        if result.returncode != 0 or not result.stdout.strip():
            return []
        commits = []
        for line in result.stdout.strip().split("\n"):
            if not line.strip():
                continue
            parts = line.split(" ", 1)
            h = parts[0]
            msg = parts[1] if len(parts) > 1 else ""
            has_ref = bool(re_mod.search(r"T-\d+", msg))
            commits.append({"hash": h, "message": msg, "traced": has_ref})
        return commits
    except Exception:
        return []


def _stale_tasks():
    """Find active tasks with issues or no update in >7 days."""
    stale = []
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    if not active_dir.exists():
        return stale

    now = datetime.now(timezone.utc)
    for f in active_dir.glob("T-*.md"):
        content = f.read_text(errors="replace")
        fm_match = re_mod.match(r"^---\n(.*?)\n---", content, re_mod.DOTALL)
        if not fm_match:
            continue
        try:
            fm = yaml.safe_load(fm_match.group(1))
        except yaml.YAMLError:
            continue
        if not isinstance(fm, dict):
            continue

        tid = fm.get("id", f.stem[:5])
        name = fm.get("name", "")[:40]
        status = fm.get("status", "")

        if status == "issues":
            stale.append({"id": tid, "name": name, "reason": "has issues"})
            continue

        last_update = fm.get("last_update")
        if last_update:
            try:
                ts = last_update if isinstance(last_update, datetime) else datetime.fromisoformat(str(last_update).replace("Z", "+00:00"))
                if hasattr(ts, "tzinfo") and ts.tzinfo is None:
                    ts = ts.replace(tzinfo=timezone.utc)
                days = (now - ts).days
                if days > 7:
                    stale.append({"id": tid, "name": name, "reason": f"no update in {days}d"})
            except (ValueError, TypeError):
                pass

    return stale


@bp.route("/metrics")
def project_metrics():
    """Project health dashboard."""
    active, completed = _task_counts()
    traceability = _traceability()
    desc_quality, ac_coverage = _quality_scores()
    knowledge = _knowledge_counts()
    commits = _recent_commits()
    stale = _stale_tasks()

    return render_page(
        "metrics.html",
        page_title="Project Metrics",
        active_count=active,
        completed_count=completed,
        traceability=traceability,
        desc_quality=desc_quality,
        ac_coverage=ac_coverage,
        knowledge=knowledge,
        commits=commits,
        stale_tasks=stale,
    )
