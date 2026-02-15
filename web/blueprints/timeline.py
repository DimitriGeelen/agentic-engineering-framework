"""Timeline blueprint — session timeline with progressive disclosure."""

import re as re_mod

import yaml
from flask import Blueprint, abort, render_template

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("timeline", __name__)


def _load_task_names():
    """Build {task_id: name} dict from active and completed task files."""
    names = {}
    for subdir in ("active", "completed"):
        d = PROJECT_ROOT / ".tasks" / subdir
        if not d.exists():
            continue
        for f in d.glob("T-*.md"):
            content = f.read_text()
            fm_match = re_mod.match(r"^---\n(.*?)\n---", content, re_mod.DOTALL)
            if not fm_match:
                continue
            try:
                fm = yaml.safe_load(fm_match.group(1))
            except yaml.YAMLError:
                continue
            if not isinstance(fm, dict):
                continue
            tid = fm.get("id", "")
            name = fm.get("name", "")
            if tid and name:
                names[tid] = name
    return names


def _truncate(text, max_len=100):
    """Truncate text at a word boundary, adding ellipsis if needed."""
    if not text or len(text) <= max_len:
        return text or ""
    truncated = text[:max_len].rsplit(" ", 1)[0]
    return truncated + "..."


@bp.route("/timeline")
def timeline():
    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    sessions = []
    task_names = _load_task_names()

    if handovers_dir.exists():
        for f in sorted(handovers_dir.glob("S-*.md"), reverse=True):
            content = f.read_text()
            fm_match = re_mod.match(r"^---\n(.*?)\n---", content, re_mod.DOTALL)
            if not fm_match:
                continue
            fm = yaml.safe_load(fm_match.group(1))

            where_match = re_mod.search(
                r"## Where We Are\n\n(.*?)(?=\n## |\Z)", content, re_mod.DOTALL
            )
            narrative = fm.get("session_narrative", "")
            if not narrative and where_match:
                narrative = where_match.group(1).strip()

            tasks_touched = fm.get("tasks_touched", []) or []
            tasks_completed = fm.get("tasks_completed", []) or []

            # Enrich task IDs with names
            touched_rich = [
                {"id": t, "name": task_names.get(t, "")} for t in tasks_touched
            ]
            completed_rich = [
                {"id": t, "name": task_names.get(t, "")} for t in tasks_completed
            ]

            sessions.append(
                {
                    "id": fm.get("session_id", f.stem),
                    "timestamp": str(fm.get("timestamp", "")),
                    "tasks_touched": touched_rich,
                    "tasks_completed": completed_rich,
                    "touched_count": len(tasks_touched),
                    "completed_count": len(tasks_completed),
                    "narrative": narrative,
                    "narrative_short": _truncate(narrative),
                    "predecessor": fm.get("predecessor", ""),
                }
            )

    return render_page("timeline.html", page_title="Timeline", sessions=sessions)


@bp.route("/api/timeline/task/<task_id>")
def timeline_task_detail(task_id):
    if not re_mod.match(r"^T-\d{3}$", task_id):
        abort(404)

    episodic_file = PROJECT_ROOT / ".context" / "episodic" / f"{task_id}.yaml"
    if not episodic_file.exists():
        return f"<p><em>No episodic data for {task_id}</em></p>"

    with open(episodic_file) as ef:
        data = yaml.safe_load(ef)

    return render_template("_timeline_task.html", task=data, task_id=task_id)
