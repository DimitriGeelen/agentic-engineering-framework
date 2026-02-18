"""Tasks blueprint — task list, detail, status API."""

import os
import re as re_mod
import subprocess
from datetime import datetime, timezone

import yaml
from flask import Blueprint, abort, request

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT, render_page

bp = Blueprint("tasks", __name__)


# ---------------------------------------------------------------------------
# Helpers — file finding and frontmatter editing (T-181 spike)
# ---------------------------------------------------------------------------

def _find_task_file(task_id):
    """Find the task markdown file by ID. Returns Path or None."""
    for location in ["active", "completed"]:
        task_dir = PROJECT_ROOT / ".tasks" / location
        if task_dir.exists():
            for f in task_dir.glob(f"{task_id}-*.md"):
                return f
    return None


def _update_frontmatter_field(file_path, field, value):
    """Update a single-line YAML frontmatter field using regex.

    Uses line-level replacement to avoid yaml.dump() formatting changes.
    Only works for simple scalar fields (name, description single-line, etc.).
    Returns (success, error_message).
    """
    content = file_path.read_text()
    fm_match = re_mod.match(r"^(---\n)(.*?)(\n---)", content, re_mod.DOTALL)
    if not fm_match:
        return False, "Cannot parse frontmatter"

    frontmatter = fm_match.group(2)

    # Escape value for YAML — wrap in quotes if it contains special chars
    if any(c in str(value) for c in ':{}[]&*?|->!%@`,"\'#'):
        safe_value = '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'
    else:
        safe_value = str(value)

    # Replace the field line (handles both quoted and unquoted values)
    pattern = re_mod.compile(rf'^({re_mod.escape(field)}:\s*).*$', re_mod.MULTILINE)
    if not pattern.search(frontmatter):
        return False, f"Field '{field}' not found in frontmatter"

    new_frontmatter = pattern.sub(rf'\g<1>{safe_value}', frontmatter, count=1)

    # Also update last_update timestamp
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    ts_pattern = re_mod.compile(r'^(last_update:\s*).*$', re_mod.MULTILINE)
    new_frontmatter = ts_pattern.sub(rf'\g<1>{ts}', new_frontmatter)

    new_content = fm_match.group(1) + new_frontmatter + fm_match.group(3) + content[fm_match.end():]
    file_path.write_text(new_content)
    return True, None


def _parse_acceptance_criteria(body_text):
    """Parse AC checkboxes from task body. Returns list of (line_idx, checked, text)."""
    criteria = []
    for i, line in enumerate(body_text.split('\n')):
        m = re_mod.match(r'^- \[([ xX])\] (.+)$', line)
        if m:
            criteria.append((i, m.group(1).lower() == 'x', m.group(2)))
    return criteria


def _toggle_ac_line(file_path, line_idx):
    """Toggle an AC checkbox at a specific line index in the body.

    Returns (success, new_state, error_message).
    """
    content = file_path.read_text()
    fm_match = re_mod.match(r"^---\n.*?\n---\n", content, re_mod.DOTALL)
    if not fm_match:
        return False, False, "Cannot parse file"

    body_start = fm_match.end()
    body = content[body_start:]
    lines = body.split('\n')

    if line_idx < 0 or line_idx >= len(lines):
        return False, False, "Line index out of range"

    line = lines[line_idx]
    m = re_mod.match(r'^(- \[)([ xX])(\] .+)$', line)
    if not m:
        return False, False, "Not an AC checkbox line"

    new_state = m.group(2).strip() == ''  # toggle: unchecked → checked
    lines[line_idx] = m.group(1) + ('x' if new_state else ' ') + m.group(3)

    new_content = content[:body_start] + '\n'.join(lines)
    file_path.write_text(new_content)
    return True, new_state, None


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
        # Merge frontmatter tags with episodic tags (deduplicated)
        fm_tags = t.get("tags", []) or []
        ep_tags = task_tags.get(t.get("id", ""), [])
        combined = list(dict.fromkeys(
            [str(tg) for tg in fm_tags] + [str(tg) for tg in ep_tags]
        ))
        t["_tags"] = combined

    # Apply filters
    status_filter = request.args.get("status", "")
    type_filter = request.args.get("type", "")
    component_filter = request.args.get("component", "")
    tag_filter = request.args.get("tag", "")
    sort_by = request.args.get("sort", "id")

    if status_filter:
        all_tasks = [t for t in all_tasks if t.get("status") == status_filter]
    if type_filter:
        all_tasks = [t for t in all_tasks if t.get("workflow_type") == type_filter]
    if component_filter:
        all_tasks = [t for t in all_tasks if component_filter in t.get("_tags", [])]
    if tag_filter:
        all_tasks = [t for t in all_tasks if tag_filter.lower() in [str(tg).lower() for tg in t.get("_tags", [])]]

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
        tag_filter=tag_filter,
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
        try:
            with open(episodic_file) as f:
                episodic = yaml.safe_load(f)
        except yaml.YAMLError:
            episodic = None

    status_options = ["captured", "started-work", "issues", "work-completed"]

    # Parse AC checkboxes for interactive rendering
    ac_items = _parse_acceptance_criteria(task_content)

    return render_page(
        "task_detail.html",
        page_title=f"Task {task_id}",
        task=task_data,
        task_content=task_content,
        episodic=episodic,
        task_id=task_id,
        status_options=status_options,
        ac_items=ac_items,
    )


@bp.route("/api/task/create", methods=["POST"])
def create_task():
    name = request.form.get("name", "").strip()
    workflow_type = request.form.get("type", "build").strip()
    owner = request.form.get("owner", "human").strip()
    description = request.form.get("description", "").strip()
    tags = request.form.get("tags", "").strip()

    if not name:
        return '<p style="color: var(--pico-del-color);">Task name is required</p>', 400

    allowed_types = ["build", "test", "refactor", "specification", "design", "decommission", "inception"]
    if workflow_type not in allowed_types:
        return '<p style="color: var(--pico-del-color);">Invalid workflow type</p>', 400

    allowed_owners = ["human", "claude-code"]
    if owner not in allowed_owners:
        return '<p style="color: var(--pico-del-color);">Invalid owner</p>', 400

    horizon = request.form.get("horizon", "now").strip()
    if horizon not in ("now", "next", "later"):
        return '<p style="color: var(--pico-del-color);">Invalid horizon</p>', 400

    try:
        cmd = [
            str(FRAMEWORK_ROOT / "bin" / "fw"), "task", "create",
            "--name", name,
            "--type", workflow_type,
            "--owner", owner,
            "--horizon", horizon,
        ]
        if description:
            cmd.extend(["--description", description])
        if tags:
            cmd.extend(["--tags", tags])

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


@bp.route("/api/task/<task_id>/horizon", methods=["POST"])
def update_task_horizon(task_id):
    if not re_mod.match(r"^T-\d{3}$", task_id):
        abort(404)

    horizon = request.form.get("horizon", "")
    if horizon not in ("now", "next", "later"):
        return '<p style="color: var(--pico-del-color);">Invalid horizon</p>', 400

    try:
        result = subprocess.run(
            [str(FRAMEWORK_ROOT / "bin" / "fw"), "task", "update", task_id, "--horizon", horizon],
            capture_output=True,
            text=True,
            timeout=30,
            env={**os.environ, "PROJECT_ROOT": str(PROJECT_ROOT)},
        )
        if result.returncode == 0:
            return f'<p style="color: var(--pico-ins-color);">Horizon set to {horizon}</p>'
        else:
            return (
                f'<p style="color: var(--pico-del-color);">Error: {result.stderr[:200]}</p>',
                500,
            )
    except Exception as e:
        return f'<p style="color: var(--pico-del-color);">Error: {str(e)[:200]}</p>', 500


@bp.route("/api/task/<task_id>/owner", methods=["POST"])
def update_task_owner(task_id):
    if not re_mod.match(r"^T-\d{3}$", task_id):
        abort(404)

    owner = request.form.get("owner", "")
    if owner not in ("human", "claude-code"):
        return '<p style="color: var(--pico-del-color);">Invalid owner</p>', 400

    try:
        result = subprocess.run(
            [str(FRAMEWORK_ROOT / "bin" / "fw"), "task", "update", task_id, "--owner", owner],
            capture_output=True,
            text=True,
            timeout=30,
            env={**os.environ, "PROJECT_ROOT": str(PROJECT_ROOT)},
        )
        if result.returncode == 0:
            return f'<p style="color: var(--pico-ins-color);">Owner set to {owner}</p>'
        else:
            return (
                f'<p style="color: var(--pico-del-color);">Error: {result.stderr[:200]}</p>',
                500,
            )
    except Exception as e:
        return f'<p style="color: var(--pico-del-color);">Error: {str(e)[:200]}</p>', 500


@bp.route("/api/task/<task_id>/type", methods=["POST"])
def update_task_type(task_id):
    if not re_mod.match(r"^T-\d{3}$", task_id):
        abort(404)

    wtype = request.form.get("type", "")
    allowed = ["build", "test", "refactor", "specification", "design", "decommission", "inception"]
    if wtype not in allowed:
        return '<p style="color: var(--pico-del-color);">Invalid workflow type</p>', 400

    try:
        result = subprocess.run(
            [str(FRAMEWORK_ROOT / "bin" / "fw"), "task", "update", task_id, "--type", wtype],
            capture_output=True,
            text=True,
            timeout=30,
            env={**os.environ, "PROJECT_ROOT": str(PROJECT_ROOT)},
        )
        if result.returncode == 0:
            return f'<p style="color: var(--pico-ins-color);">Type set to {wtype}</p>'
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


# ---------------------------------------------------------------------------
# Inline editing API endpoints (T-181 spike)
# ---------------------------------------------------------------------------

@bp.route("/api/task/<task_id>/name", methods=["POST"])
def update_task_name(task_id):
    """Update task name via regex frontmatter editing."""
    if not re_mod.match(r"^T-\d{3}$", task_id):
        abort(404)

    name = request.form.get("name", "").strip()
    if not name:
        return '<p style="color: var(--pico-del-color);">Name cannot be empty</p>', 400
    if len(name) > 200:
        return '<p style="color: var(--pico-del-color);">Name too long (max 200)</p>', 400

    task_file = _find_task_file(task_id)
    if not task_file:
        abort(404)

    ok, err = _update_frontmatter_field(task_file, "name", name)
    if ok:
        return f'<span class="kanban-card-name" title="{name}">{name}</span>'
    return f'<p style="color: var(--pico-del-color);">Error: {err}</p>', 500


@bp.route("/api/task/<task_id>/toggle-ac", methods=["POST"])
def toggle_ac(task_id):
    """Toggle an acceptance criteria checkbox."""
    if not re_mod.match(r"^T-\d{3}$", task_id):
        abort(404)

    try:
        line_idx = int(request.form.get("line", "-1"))
    except (TypeError, ValueError):
        return '<p style="color: var(--pico-del-color);">Invalid line index</p>', 400

    task_file = _find_task_file(task_id)
    if not task_file:
        abort(404)

    ok, new_state, err = _toggle_ac_line(task_file, line_idx)
    if ok:
        checked_attr = "checked" if new_state else ""
        return f'<input type="checkbox" {checked_attr} disabled style="margin:0;">'
    return f'<p style="color: var(--pico-del-color);">Error: {err}</p>', 500


@bp.route("/api/task/<task_id>/description", methods=["POST"])
def update_task_description(task_id):
    """Update task description (single-line only for now)."""
    if not re_mod.match(r"^T-\d{3}$", task_id):
        abort(404)

    desc = request.form.get("description", "").strip()
    if not desc:
        return '<p style="color: var(--pico-del-color);">Description cannot be empty</p>', 400

    task_file = _find_task_file(task_id)
    if not task_file:
        abort(404)

    # For multi-line descriptions (using > or |), we need to replace the whole block.
    # For now, only handle the simple single-line case as a spike.
    content = task_file.read_text()
    fm_match = re_mod.match(r"^(---\n)(.*?)(\n---)", content, re_mod.DOTALL)
    if not fm_match:
        return '<p style="color: var(--pico-del-color);">Cannot parse frontmatter</p>', 500

    frontmatter = fm_match.group(2)

    # Replace description block — handles both single-line and multi-line (> folded)
    # Pattern: description: > \n  indented lines... (until next non-indented key)
    # Or: description: "single line"
    desc_pattern = re_mod.compile(
        r'^description:.*?(?=\n[a-z_]+:|\Z)', re_mod.MULTILINE | re_mod.DOTALL
    )
    if not desc_pattern.search(frontmatter):
        return '<p style="color: var(--pico-del-color);">Description field not found</p>', 500

    # Use folded scalar for multi-line, plain for single-line
    if '\n' in desc or len(desc) > 80:
        # Folded scalar style
        indented = '\n'.join('  ' + line for line in desc.split('\n'))
        new_desc = f'description: >\n{indented}'
    else:
        safe = '"' + desc.replace('\\', '\\\\').replace('"', '\\"') + '"'
        new_desc = f'description: {safe}'

    new_frontmatter = desc_pattern.sub(new_desc, frontmatter, count=1)

    # Update last_update
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    ts_pattern = re_mod.compile(r'^(last_update:\s*).*$', re_mod.MULTILINE)
    new_frontmatter = ts_pattern.sub(rf'\g<1>{ts}', new_frontmatter)

    new_content = fm_match.group(1) + new_frontmatter + fm_match.group(3) + content[fm_match.end():]
    task_file.write_text(new_content)
    return f'<p style="color: var(--pico-ins-color);">Description updated</p>'
