"""Timeline blueprint — session timeline with progressive disclosure."""

import re as re_mod

import yaml
from flask import Blueprint, abort, render_template

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("timeline", __name__)


@bp.route("/timeline")
def timeline():
    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    sessions = []

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

            tasks_touched = fm.get("tasks_touched", [])
            tasks_completed = fm.get("tasks_completed", [])

            sessions.append(
                {
                    "id": fm.get("session_id", f.stem),
                    "timestamp": str(fm.get("timestamp", "")),
                    "tasks_touched": tasks_touched,
                    "tasks_completed": tasks_completed,
                    "touched_count": len(tasks_touched) if tasks_touched else 0,
                    "completed_count": len(tasks_completed) if tasks_completed else 0,
                    "narrative": narrative,
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
