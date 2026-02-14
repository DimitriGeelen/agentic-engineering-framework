"""Tasks blueprint — task list, detail, status API."""

import os
import re as re_mod
import subprocess

import yaml
from flask import Blueprint, abort, request

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT, render_page

bp = Blueprint("tasks", __name__)


@bp.route("/tasks")
def tasks():
    all_tasks = []

    active_dir = PROJECT_ROOT / ".tasks" / "active"
    if active_dir.exists():
        for f in sorted(active_dir.glob("T-*.md")):
            file_text = f.read_text()
            fm_match = re_mod.match(r"^---\n(.*?)\n---", file_text, re_mod.DOTALL)
            if fm_match:
                try:
                    fm = yaml.safe_load(fm_match.group(1))
                except yaml.YAMLError:
                    continue
                if not isinstance(fm, dict):
                    continue
                fm["_location"] = "active"
                all_tasks.append(fm)

    completed_dir = PROJECT_ROOT / ".tasks" / "completed"
    if completed_dir.exists():
        for f in sorted(completed_dir.glob("T-*.md")):
            file_text = f.read_text()
            fm_match = re_mod.match(r"^---\n(.*?)\n---", file_text, re_mod.DOTALL)
            if fm_match:
                try:
                    fm = yaml.safe_load(fm_match.group(1))
                except yaml.YAMLError:
                    continue
                if not isinstance(fm, dict):
                    continue
                fm["_location"] = "completed"
                all_tasks.append(fm)

    # Load episodic tags for component filtering
    episodic_dir = PROJECT_ROOT / ".context" / "episodic"
    task_tags = {}
    if episodic_dir.exists():
        for f in episodic_dir.glob("T-*.yaml"):
            try:
                with open(f) as fh:
                    edata = yaml.safe_load(fh)
                if isinstance(edata, dict):
                    task_tags[edata.get("task_id", f.stem)] = edata.get("tags", [])
            except yaml.YAMLError:
                continue

    for t in all_tasks:
        t["_tags"] = task_tags.get(t.get("id", ""), [])

    # Apply filters
    status_filter = request.args.get("status", "")
    type_filter = request.args.get("type", "")
    component_filter = request.args.get("component", "")
    sort_by = request.args.get("sort", "id")

    if status_filter:
        all_tasks = [t for t in all_tasks if t.get("status") == status_filter]
    if type_filter:
        all_tasks = [t for t in all_tasks if t.get("workflow_type") == type_filter]
    if component_filter:
        all_tasks = [t for t in all_tasks if component_filter in t.get("_tags", [])]

    if sort_by == "name":
        all_tasks.sort(key=lambda t: t.get("name", ""))
    else:
        all_tasks.sort(key=lambda t: t.get("id", ""))

    statuses = sorted(set(t.get("status", "") for t in all_tasks if t.get("status")))
    types = sorted(set(t.get("workflow_type", "") for t in all_tasks if t.get("workflow_type")))
    components = [
        "context-fabric", "audit", "git-agent", "healing-loop", "cli",
        "observation", "handover", "resume", "metrics", "task-system",
        "specification", "design",
    ]

    view = request.args.get("view", "board")
    if view not in ("board", "list"):
        view = "board"

    return render_page(
        "tasks.html",
        page_title="Tasks",
        tasks=all_tasks,
        statuses=statuses,
        types=types,
        components=components,
        status_filter=status_filter,
        type_filter=type_filter,
        component_filter=component_filter,
        sort_by=sort_by,
        view=view,
    )


@bp.route("/tasks/<task_id>")
def task_detail(task_id):
    if not re_mod.match(r"^T-\d{3}$", task_id):
        abort(404)

    task_data = None
    task_content = ""
    for location in ["active", "completed"]:
        task_dir = PROJECT_ROOT / ".tasks" / location
        if task_dir.exists():
            for f in task_dir.glob(f"{task_id}-*.md"):
                file_content = f.read_text()
                fm_match = re_mod.match(r"^---\n(.*?)\n---\n(.*)", file_content, re_mod.DOTALL)
                if fm_match:
                    try:
                        task_data = yaml.safe_load(fm_match.group(1))
                    except yaml.YAMLError:
                        task_data = None
                    if isinstance(task_data, dict):
                        task_content = fm_match.group(2)
                break

    if not task_data:
        abort(404)

    episodic = None
    episodic_file = PROJECT_ROOT / ".context" / "episodic" / f"{task_id}.yaml"
    if episodic_file.exists():
        with open(episodic_file) as f:
            episodic = yaml.safe_load(f)

    status_options = ["captured", "started-work", "issues", "work-completed"]

    return render_page(
        "task_detail.html",
        page_title=f"Task {task_id}",
        task=task_data,
        task_content=task_content,
        episodic=episodic,
        task_id=task_id,
        status_options=status_options,
    )


@bp.route("/api/task/create", methods=["POST"])
def create_task():
    name = request.form.get("name", "").strip()
    workflow_type = request.form.get("type", "build").strip()
    owner = request.form.get("owner", "human").strip()
    description = request.form.get("description", "").strip()

    if not name:
        return '<p style="color: var(--pico-del-color);">Task name is required</p>', 400

    allowed_types = ["build", "test", "refactor", "specification", "design", "decommission"]
    if workflow_type not in allowed_types:
        return '<p style="color: var(--pico-del-color);">Invalid workflow type</p>', 400

    allowed_owners = ["human", "claude-code"]
    if owner not in allowed_owners:
        return '<p style="color: var(--pico-del-color);">Invalid owner</p>', 400

    try:
        cmd = [
            str(FRAMEWORK_ROOT / "bin" / "fw"), "task", "create",
            "--name", name,
            "--type", workflow_type,
            "--owner", owner,
        ]
        if description:
            cmd.extend(["--description", description])

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            env={**os.environ, "PROJECT_ROOT": str(PROJECT_ROOT)},
        )
        if result.returncode == 0:
            # Extract task ID from output if possible
            id_match = re_mod.search(r"(T-\d{3})", result.stdout)
            task_id = id_match.group(1) if id_match else "new task"
            return f'<p style="color: var(--pico-ins-color);">Created {task_id}: {name}</p>'
        else:
            return (
                f'<p style="color: var(--pico-del-color);">Error: {result.stderr[:200]}</p>',
                500,
            )
    except Exception as e:
        return f'<p style="color: var(--pico-del-color);">Error: {str(e)[:200]}</p>', 500


@bp.route("/api/task/<task_id>/status", methods=["POST"])
def update_task_status(task_id):
    if not re_mod.match(r"^T-\d{3}$", task_id):
        abort(404)

    status = request.form.get("status", "")
    allowed = ["captured", "started-work", "issues", "work-completed"]
    if status not in allowed:
        return '<p style="color: var(--pico-del-color);">Invalid status value</p>', 400

    try:
        result = subprocess.run(
            [str(FRAMEWORK_ROOT / "bin" / "fw"), "task", "update", task_id, "--status", status],
            capture_output=True,
            text=True,
            timeout=30,
            env={**os.environ, "PROJECT_ROOT": str(PROJECT_ROOT)},
        )
        if result.returncode == 0:
            return f'<p style="color: var(--pico-ins-color);">Status updated to {status}</p>'
        else:
            return (
                f'<p style="color: var(--pico-del-color);">Error: {result.stderr[:200]}</p>',
                500,
            )
    except Exception as e:
        return f'<p style="color: var(--pico-del-color);">Error: {str(e)[:200]}</p>', 500
