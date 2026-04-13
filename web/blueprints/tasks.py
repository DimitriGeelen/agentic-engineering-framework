"""Tasks blueprint — task list, detail, status API."""

import re as re_mod
from datetime import datetime, timezone

import yaml
from flask import Blueprint, abort, request

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT, render_page, parse_frontmatter
from web.subprocess_utils import run_fw_command

bp = Blueprint("tasks", __name__)


# ---------------------------------------------------------------------------
# Enum loading from status-transitions.yaml (T-1179, G-038)
# ---------------------------------------------------------------------------

_ENUM_CACHE = {}

def _load_enums():
    """Load workflow_types and horizons from status-transitions.yaml.

    Cached after first load. Falls back to hardcoded defaults if YAML is missing.
    """
    if _ENUM_CACHE:
        return _ENUM_CACHE
    yaml_path = FRAMEWORK_ROOT / "status-transitions.yaml"
    try:
        with open(yaml_path) as f:
            data = yaml.safe_load(f) or {}
        _ENUM_CACHE["workflow_types"] = data.get("workflow_types", [])
        _ENUM_CACHE["horizons"] = data.get("horizons", [])
        _ENUM_CACHE["statuses"] = data.get("statuses", {}).get("active", [])
        _ENUM_CACHE["owners"] = data.get("owners", [])
    except Exception:
        _ENUM_CACHE["workflow_types"] = ["build", "test", "refactor", "specification", "design", "decommission", "inception"]
        _ENUM_CACHE["horizons"] = ["now", "next", "later"]
        _ENUM_CACHE["statuses"] = ["captured", "started-work", "issues", "work-completed"]
        _ENUM_CACHE["owners"] = ["human", "claude-code"]
    return _ENUM_CACHE


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


def _parse_ac_body(body):
    """Parse Steps/Expected/If-not from AC body text."""
    steps = []
    expected = ''
    if_not = ''
    if not body:
        return steps, expected, if_not

    lines = body.split('\n')
    current_field = None
    current_content = []

    for line in lines:
        stripped = line.strip()
        if stripped.startswith('**Steps:**'):
            current_field = 'steps'
            current_content = []
            continue
        elif stripped.startswith('**Expected:**'):
            if current_field == 'steps':
                steps = [s for s in current_content if s.strip()]
            current_field = 'expected'
            rest = stripped[len('**Expected:**'):].strip()
            current_content = [rest] if rest else []
            continue
        elif stripped.startswith('**If not:**'):
            if current_field == 'steps':
                steps = [s for s in current_content if s.strip()]
            elif current_field == 'expected':
                expected = '\n'.join(current_content).strip()
            current_field = 'if_not'
            rest = stripped[len('**If not:**'):].strip()
            current_content = [rest] if rest else []
            continue
        if current_field:
            current_content.append(stripped)

    if current_field == 'steps':
        steps = [s for s in current_content if s.strip()]
    elif current_field == 'expected':
        expected = '\n'.join(current_content).strip()
    elif current_field == 'if_not':
        if_not = '\n'.join(current_content).strip()

    # Strip numbered prefixes from steps (e.g., "1. Do thing" → "Do thing")
    steps = [re_mod.sub(r'^\d+\.\s*', '', s) for s in steps]

    return steps, expected, if_not


def _parse_acceptance_criteria(body_text):
    """Parse AC checkboxes with section, confidence, and body details.

    Returns list of dicts with keys:
      line_idx, checked, text, section, confidence, body, steps, expected, if_not
    """
    criteria = []
    lines = body_text.split('\n')
    in_ac_section = False
    current_section = 'general'
    in_comment = False

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Track HTML comments (skip them)
        if '<!--' in stripped:
            in_comment = True
        if in_comment:
            if '-->' in stripped:
                in_comment = False
            i += 1
            continue

        # Track AC section boundaries
        if stripped.startswith('## Acceptance Criteria'):
            in_ac_section = True
            current_section = 'general'
            i += 1
            continue
        if in_ac_section and stripped.startswith('## ') and 'Acceptance Criteria' not in stripped:
            in_ac_section = False
            i += 1
            continue

        if not in_ac_section:
            i += 1
            continue

        # Detect subsection headers
        if stripped == '### Agent' or stripped.startswith('### Agent'):
            current_section = 'agent'
            i += 1
            continue
        if stripped == '### Human' or stripped.startswith('### Human'):
            current_section = 'human'
            i += 1
            continue

        # Parse AC checkbox
        m = re_mod.match(r'^- \[([ xX])\] (.+)$', line)
        if m:
            text = m.group(2)
            checked = m.group(1).lower() == 'x'

            # Parse confidence marker
            confidence = None
            cm = re_mod.match(r'^\[RUBBER-STAMP\]\s*(.+)$', text)
            if cm:
                confidence = 'rubber-stamp'
                text = cm.group(1)
            else:
                cm = re_mod.match(r'^\[REVIEW\]\s*(.+)$', text)
                if cm:
                    confidence = 'review'
                    text = cm.group(1)

            # Collect body lines (indented content following this AC)
            body_lines = []
            j = i + 1
            while j < len(lines):
                next_line = lines[j]
                if re_mod.match(r'^- \[[ xX]\]', next_line):
                    break
                if next_line.startswith('## ') or next_line.startswith('### '):
                    break
                body_lines.append(next_line)
                j += 1

            while body_lines and not body_lines[-1].strip():
                body_lines.pop()

            body = '\n'.join(body_lines) if body_lines else ''
            steps, expected, if_not = _parse_ac_body(body)

            criteria.append({
                'line_idx': i,
                'checked': checked,
                'text': text,
                'section': current_section,
                'confidence': confidence,
                'body': body,
                'steps': steps,
                'expected': expected,
                'if_not': if_not,
            })

        i += 1

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
            fm, _ = parse_frontmatter(f.read_text())
            if fm:
                fm["_location"] = "active"
                all_tasks.append(fm)

    completed_dir = PROJECT_ROOT / ".tasks" / "completed"
    if completed_dir.exists():
        for f in sorted(completed_dir.glob("T-*.md")):
            fm, _ = parse_frontmatter(f.read_text())
            if fm:
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
    owner_filter = request.args.get("owner", "")
    horizon_filter = request.args.get("horizon", "")
    search_query = request.args.get("q", "").strip()
    sort_by = request.args.get("sort", "id")

    if status_filter:
        all_tasks = [t for t in all_tasks if t.get("status") == status_filter]
    if type_filter:
        all_tasks = [t for t in all_tasks if t.get("workflow_type") == type_filter]
    if component_filter:
        all_tasks = [t for t in all_tasks if component_filter in t.get("_tags", [])]
    if tag_filter:
        all_tasks = [t for t in all_tasks if tag_filter.lower() in [str(tg).lower() for tg in t.get("_tags", [])]]
    if owner_filter:
        all_tasks = [t for t in all_tasks if t.get("owner") == owner_filter]
    if horizon_filter:
        all_tasks = [t for t in all_tasks if t.get("horizon") == horizon_filter]
    if search_query:
        q_lower = search_query.lower()
        all_tasks = [t for t in all_tasks if q_lower in t.get("id", "").lower()
                     or q_lower in t.get("name", "").lower()
                     or q_lower in t.get("description", "").lower()
                     or q_lower in " ".join(str(tg) for tg in t.get("_tags", [])).lower()]

    # Collect unique values for filter dropdowns (before sorting)
    owners = sorted(set(t.get("owner", "") for t in all_tasks if t.get("owner")))
    all_tags = sorted(set(
        tg for t in all_tasks for tg in t.get("_tags", []) if tg
    ))

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

    enums = _load_enums()
    return render_page(
        "tasks.html",
        page_title="Tasks",
        tasks=all_tasks,
        statuses=statuses,
        types=types,
        components=components,
        owners=owners,
        all_tags=all_tags,
        status_filter=status_filter,
        type_filter=type_filter,
        component_filter=component_filter,
        tag_filter=tag_filter,
        owner_filter=owner_filter,
        horizon_filter=horizon_filter,
        search_query=search_query,
        sort_by=sort_by,
        view=view,
        enum_types=enums["workflow_types"],
        enum_horizons=enums["horizons"],
        enum_owners=enums["owners"],
        enum_statuses=enums["statuses"],
    )


@bp.route("/tasks/<task_id>")
def task_detail(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    task_data = None
    task_content = ""
    for location in ["active", "completed"]:
        task_dir = PROJECT_ROOT / ".tasks" / location
        if task_dir.exists():
            for f in task_dir.glob(f"{task_id}-*.md"):
                task_data, task_content = parse_frontmatter(f.read_text())
                if not task_data:
                    task_data = None
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

    status_options = _load_enums()["statuses"]

    # Parse AC checkboxes for interactive rendering
    ac_items = _parse_acceptance_criteria(task_content)

    # Find research artifacts (docs/reports/T-XXX-* and fw-agent-tXXX-*)
    artifacts = []
    reports_dir = PROJECT_ROOT / "docs" / "reports"
    if reports_dir.exists():
        tid_lower = task_id.lower().replace("-", "")
        for f in sorted(reports_dir.glob("*.md")):
            fname = f.name.lower().replace("-", "")
            if tid_lower in fname:
                artifacts.append({"name": f.name, "path": f"docs/reports/{f.name}"})

    # Compute whether "Complete Task" button should show (T-640)
    can_complete = False
    if ac_items and task_data.get("status") != "work-completed":
        all_checked = all(ac["checked"] for ac in ac_items)
        can_complete = all_checked

    return render_page(
        "task_detail.html",
        page_title=f"Task {task_id}",
        task=task_data,
        task_content=task_content,
        episodic=episodic,
        task_id=task_id,
        status_options=status_options,
        ac_items=ac_items,
        artifacts=artifacts,
        can_complete=can_complete,
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

    enums = _load_enums()
    if workflow_type not in enums["workflow_types"]:
        return '<p style="color: var(--pico-del-color);">Invalid workflow type</p>', 400

    if owner not in enums["owners"]:
        return '<p style="color: var(--pico-del-color);">Invalid owner</p>', 400

    horizon = request.form.get("horizon", "now").strip()
    if horizon not in enums["horizons"]:
        return '<p style="color: var(--pico-del-color);">Invalid horizon</p>', 400

    cmd = [
        "task", "create",
        "--name", name,
        "--type", workflow_type,
        "--owner", owner,
        "--horizon", horizon,
    ]
    if description:
        cmd.extend(["--description", description])
    if tags:
        cmd.extend(["--tags", tags])

    stdout, stderr, ok = run_fw_command(cmd)
    if ok:
        id_match = re_mod.search(r"(T-\d{3,})", stdout)
        task_id = id_match.group(1) if id_match else "new task"
        return f'<p style="color: var(--pico-ins-color);">Created {task_id}: {name}</p>'
    else:
        return (
            f'<p style="color: var(--pico-del-color);">Error: {(stderr or stdout)[:200]}</p>',
            500,
        )


@bp.route("/api/task/<task_id>/horizon", methods=["POST"])
def update_task_horizon(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    horizon = request.form.get("horizon", "")
    enums = _load_enums()
    if horizon not in enums["horizons"]:
        return '<p style="color: var(--pico-del-color);">Invalid horizon</p>', 400

    stdout, stderr, ok = run_fw_command(["task", "update", task_id, "--horizon", horizon])
    if ok:
        return f'<p style="color: var(--pico-ins-color);">Horizon set to {horizon}</p>'
    return f'<p style="color: var(--pico-del-color);">Error: {(stderr or stdout)[:200]}</p>', 500


@bp.route("/api/task/<task_id>/owner", methods=["POST"])
def update_task_owner(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    owner = request.form.get("owner", "")
    enums = _load_enums()
    if owner not in enums["owners"]:
        return '<p style="color: var(--pico-del-color);">Invalid owner</p>', 400

    stdout, stderr, ok = run_fw_command(["task", "update", task_id, "--owner", owner])
    if ok:
        return f'<p style="color: var(--pico-ins-color);">Owner set to {owner}</p>'
    return f'<p style="color: var(--pico-del-color);">Error: {(stderr or stdout)[:200]}</p>', 500


@bp.route("/api/task/<task_id>/type", methods=["POST"])
def update_task_type(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    wtype = request.form.get("type", "")
    enums = _load_enums()
    if wtype not in enums["workflow_types"]:
        return '<p style="color: var(--pico-del-color);">Invalid workflow type</p>', 400

    stdout, stderr, ok = run_fw_command(["task", "update", task_id, "--type", wtype])
    if ok:
        return f'<p style="color: var(--pico-ins-color);">Type set to {wtype}</p>'
    return f'<p style="color: var(--pico-del-color);">Error: {(stderr or stdout)[:200]}</p>', 500


@bp.route("/api/task/<task_id>/complete", methods=["POST"])
def complete_task(task_id):
    """Complete a task from the browser — passes --force since human clicked it (T-640)."""
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    stdout, stderr, ok = run_fw_command([
        "task", "update", task_id, "--status", "work-completed",
        "--force", "--reason", "Completed via Watchtower UI (human action)",
    ])
    if ok:
        return (
            '<p style="color: var(--pico-ins-color);">Task completed.</p>'
            f'<div id="complete-button" hx-swap-oob="innerHTML"></div>'
        )
    return f'<p style="color: var(--pico-del-color);">Error: {(stderr or stdout)[:200]}</p>', 500


@bp.route("/api/task/<task_id>/status", methods=["POST"])
def update_task_status(task_id):
    if not re_mod.match(r"^T-\d{3,}$", task_id):
        abort(404)

    status = request.form.get("status", "")
    allowed = _load_enums()["statuses"]
    if status not in allowed:
        return '<p style="color: var(--pico-del-color);">Invalid status value</p>', 400

    stdout, stderr, ok = run_fw_command(["task", "update", task_id, "--status", status])
    if ok:
        return f'<p style="color: var(--pico-ins-color);">Status updated to {status}</p>'
    return f'<p style="color: var(--pico-del-color);">Error: {(stderr or stdout)[:200]}</p>', 500


# ---------------------------------------------------------------------------
# Inline editing API endpoints (T-181 spike)
# ---------------------------------------------------------------------------

@bp.route("/api/task/<task_id>/name", methods=["POST"])
def update_task_name(task_id):
    """Update task name via regex frontmatter editing."""
    if not re_mod.match(r"^T-\d{3,}$", task_id):
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
    if not re_mod.match(r"^T-\d{3,}$", task_id):
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
        return f'<input type="checkbox" {checked_attr} onchange="this.form.requestSubmit()" style="margin:0;">'
    return f'<p style="color: var(--pico-del-color);">Error: {err}</p>', 500


@bp.route("/api/task/<task_id>/description", methods=["POST"])
def update_task_description(task_id):
    """Update task description (single-line only for now)."""
    if not re_mod.match(r"^T-\d{3,}$", task_id):
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
