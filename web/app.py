#!/usr/bin/env python3
"""
Agentic Engineering Framework — Web UI

Flask application serving the framework dashboard with htmx-powered
SPA-like navigation and Pico CSS styling.

Usage:
    python3 web/app.py [--port PORT]
    fw serve [--port PORT]

Environment:
    PROJECT_ROOT  — Project directory (default: auto-detect from app.py location)
    FW_PORT       — Port number (default: 3000)
"""

import argparse
import os
import secrets
import signal
import sys
from pathlib import Path
import subprocess

from flask import (
    Flask,
    abort,
    render_template,
    request,
    session,
    url_for,
)

import re as re_mod
import yaml
import markdown2

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

APP_DIR = Path(__file__).resolve().parent            # web/
FRAMEWORK_ROOT = APP_DIR.parent                       # 999-Agentic-Engineering-Framework/
PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", str(FRAMEWORK_ROOT)))

# ---------------------------------------------------------------------------
# Flask application
# ---------------------------------------------------------------------------

app = Flask(
    __name__,
    template_folder=str(APP_DIR / "templates"),
    static_folder=str(APP_DIR / "static"),
)

app.secret_key = os.environ.get("FW_SECRET_KEY", secrets.token_hex(32))

# ---------------------------------------------------------------------------
# CSRF protection
# ---------------------------------------------------------------------------


def generate_csrf_token():
    """Return the current CSRF token, creating one if needed."""
    if "_csrf_token" not in session:
        session["_csrf_token"] = secrets.token_hex(32)
    return session["_csrf_token"]


@app.before_request
def csrf_protect():
    """Validate CSRF token on state-changing requests."""
    if request.method in ("POST", "PATCH", "PUT", "DELETE"):
        token = (
            request.form.get("_csrf_token")
            or request.headers.get("X-CSRF-Token")
        )
        if not token or token != session.get("_csrf_token"):
            abort(403, description="CSRF token missing or invalid")


# Make csrf_token available in all templates
app.jinja_env.globals["csrf_token"] = generate_csrf_token

# ---------------------------------------------------------------------------
# Navigation items available to all templates
# ---------------------------------------------------------------------------

NAV_ITEMS = [
    ("Dashboard",  "index",      None),
    ("Project",    "project",    None),
    ("Directives", "directives", None),
    ("Timeline",   "timeline",   None),
    ("Tasks",      "tasks",      None),
    ("Decisions",  "decisions",  None),
    ("Learnings",  "learnings",  None),
    ("Gaps",       "gaps",       None),
    ("Search",     "search",     None),
]

# ---------------------------------------------------------------------------
# htmx-aware rendering helper
# ---------------------------------------------------------------------------


def render_page(template_name, **context):
    """Render a full page or an htmx content fragment.

    Each page template is a pure HTML fragment (no <html>, no extends).
    For full page loads, we render it inside _wrapper.html which extends
    base.html. For htmx requests (HX-Request header present), we return
    just the fragment.
    """
    context.setdefault("nav_items", NAV_ITEMS)
    context.setdefault("active_endpoint", request.endpoint)
    context.setdefault("project_root", str(PROJECT_ROOT))

    if request.headers.get("HX-Request"):
        # htmx request: return just the content fragment
        return render_template(template_name, **context)
    else:
        # Full page load: wrap the fragment in base.html via _wrapper.html
        context["_content_template"] = template_name
        return render_template("_wrapper.html", **context)

# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------


@app.route("/")
def index():
    # Count tasks
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    completed_dir = PROJECT_ROOT / ".tasks" / "completed"
    active_count = len(list(active_dir.glob("T-*.md"))) if active_dir.exists() else 0
    completed_count = len(list(completed_dir.glob("T-*.md"))) if completed_dir.exists() else 0

    # Count gaps
    gaps_file = PROJECT_ROOT / ".context" / "project" / "gaps.yaml"
    gap_count = 0
    if gaps_file.exists():
        with open(gaps_file) as f:
            data = yaml.safe_load(f)
        if data:
            gap_count = len([g for g in data.get('gaps', []) if g.get('status') == 'watching'])

    # Last session
    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    last_session = "Unknown"
    if handovers_dir.exists():
        sessions = sorted(handovers_dir.glob("S-*.md"), reverse=True)
        if sessions:
            last_session = sessions[0].stem

    return render_page("index.html", page_title="Dashboard",
        active_count=active_count, completed_count=completed_count,
        gap_count=gap_count, last_session=last_session)


@app.route("/project")
def project():
    docs = []
    for f in sorted(PROJECT_ROOT.glob("0*.md")):
        docs.append({"name": f.stem, "filename": f.name})
    fw_md = PROJECT_ROOT / "FRAMEWORK.md"
    if fw_md.exists():
        docs.append({"name": "FRAMEWORK", "filename": "FRAMEWORK.md"})
    return render_page("project.html", page_title="Project Documentation", docs=docs)


@app.route("/project/<doc>")
def project_doc(doc):
    # Validate doc name (only alphanumeric, hyphens, underscores — no path traversal)
    if not re_mod.match(r'^[A-Za-z0-9_-]+$', doc):
        abort(404)

    # Find the file
    candidates = [PROJECT_ROOT / f"{doc}.md", PROJECT_ROOT / f"{doc}"]
    doc_path = None
    for c in candidates:
        if c.exists() and c.suffix == '.md':
            doc_path = c
            break
    if not doc_path:
        abort(404)

    content_md = doc_path.read_text()
    html_content = markdown2.markdown(content_md,
        extras=["tables", "fenced-code-blocks", "code-friendly"])

    return render_page("project_doc.html", page_title=doc,
        doc_name=doc_path.stem, html_content=html_content)


@app.route("/directives")
def directives():
    # Load directives
    directives_file = PROJECT_ROOT / ".context" / "project" / "directives.yaml"
    directives_data = []
    if directives_file.exists():
        with open(directives_file) as f:
            data = yaml.safe_load(f)
        if data:
            directives_data = data.get('directives', [])

    # Load practices (link by derived_from)
    practices_file = PROJECT_ROOT / ".context" / "project" / "practices.yaml"
    practices = []
    if practices_file.exists():
        with open(practices_file) as f:
            data = yaml.safe_load(f)
        if data:
            practices = data.get('practices', [])

    # Load decisions (link by directives_served)
    decisions_file = PROJECT_ROOT / ".context" / "project" / "decisions.yaml"
    decisions_list = []
    if decisions_file.exists():
        with open(decisions_file) as f:
            data = yaml.safe_load(f)
        if data:
            decisions_list = data.get('decisions', [])

    # Load gaps
    gaps_file = PROJECT_ROOT / ".context" / "project" / "gaps.yaml"
    gaps_list = []
    if gaps_file.exists():
        with open(gaps_file) as f:
            data = yaml.safe_load(f)
        if data:
            gaps_list = data.get('gaps', [])

    # Group by directive
    for d in directives_data:
        did = d['id']
        d['practices'] = [p for p in practices
            if did in (p.get('derived_from', [])
                if isinstance(p.get('derived_from'), list)
                else [p.get('derived_from', '')])]
        d['decisions'] = [dec for dec in decisions_list
            if did in dec.get('directives_served', [])]
        d['gaps'] = [g for g in gaps_list
            if did in g.get('related_directives', [])]

    return render_page("directives.html", page_title="Constitutional Directives",
        directives=directives_data)


@app.route("/timeline")
def timeline():
    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    sessions = []

    if handovers_dir.exists():
        for f in sorted(handovers_dir.glob("S-*.md"), reverse=True):
            content = f.read_text()
            # Parse YAML frontmatter
            fm_match = re_mod.match(r'^---\n(.*?)\n---', content, re_mod.DOTALL)
            if not fm_match:
                continue
            fm = yaml.safe_load(fm_match.group(1))

            # Extract "Where We Are" section as fallback narrative
            where_match = re_mod.search(r'## Where We Are\n\n(.*?)(?=\n## |\Z)', content, re_mod.DOTALL)
            narrative = fm.get('session_narrative', '')
            if not narrative and where_match:
                narrative = where_match.group(1).strip()

            # Extract tasks touched/completed
            tasks_touched = fm.get('tasks_touched', [])
            tasks_completed = fm.get('tasks_completed', [])

            sessions.append({
                'id': fm.get('session_id', f.stem),
                'timestamp': str(fm.get('timestamp', '')),
                'tasks_touched': tasks_touched,
                'tasks_completed': tasks_completed,
                'touched_count': len(tasks_touched) if tasks_touched else 0,
                'completed_count': len(tasks_completed) if tasks_completed else 0,
                'narrative': narrative,
                'predecessor': fm.get('predecessor', ''),
            })

    return render_page("timeline.html", page_title="Timeline", sessions=sessions)


@app.route("/api/timeline/task/<task_id>")
def timeline_task_detail(task_id):
    # Validate task_id
    if not re_mod.match(r'^T-\d{3}$', task_id):
        abort(404)

    episodic_file = PROJECT_ROOT / ".context" / "episodic" / f"{task_id}.yaml"
    if not episodic_file.exists():
        return f"<p><em>No episodic data for {task_id}</em></p>"

    with open(episodic_file) as ef:
        data = yaml.safe_load(ef)

    return render_template("_timeline_task.html", task=data, task_id=task_id)


@app.route("/tasks")
def tasks():
    all_tasks = []

    # Load active tasks
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    if active_dir.exists():
        for f in sorted(active_dir.glob("T-*.md")):
            file_text = f.read_text()
            fm_match = re_mod.match(r'^---\n(.*?)\n---', file_text, re_mod.DOTALL)
            if fm_match:
                try:
                    fm = yaml.safe_load(fm_match.group(1))
                except yaml.YAMLError:
                    continue
                if not isinstance(fm, dict):
                    continue
                fm['_location'] = 'active'
                all_tasks.append(fm)

    # Load completed tasks
    completed_dir = PROJECT_ROOT / ".tasks" / "completed"
    if completed_dir.exists():
        for f in sorted(completed_dir.glob("T-*.md")):
            file_text = f.read_text()
            fm_match = re_mod.match(r'^---\n(.*?)\n---', file_text, re_mod.DOTALL)
            if fm_match:
                try:
                    fm = yaml.safe_load(fm_match.group(1))
                except yaml.YAMLError:
                    continue
                if not isinstance(fm, dict):
                    continue
                fm['_location'] = 'completed'
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
                    task_tags[edata.get('task_id', f.stem)] = edata.get('tags', [])
            except yaml.YAMLError:
                continue

    # Add tags to tasks
    for t in all_tasks:
        t['_tags'] = task_tags.get(t.get('id', ''), [])

    # Apply filters from query params
    status_filter = request.args.get('status', '')
    type_filter = request.args.get('type', '')
    component_filter = request.args.get('component', '')
    sort_by = request.args.get('sort', 'id')

    if status_filter:
        all_tasks = [t for t in all_tasks if t.get('status') == status_filter]
    if type_filter:
        all_tasks = [t for t in all_tasks if t.get('workflow_type') == type_filter]
    if component_filter:
        all_tasks = [t for t in all_tasks if component_filter in t.get('_tags', [])]

    # Sort
    if sort_by == 'name':
        all_tasks.sort(key=lambda t: t.get('name', ''))
    else:
        all_tasks.sort(key=lambda t: t.get('id', ''))

    # Collect unique filter values
    statuses = sorted(set(t.get('status', '') for t in all_tasks if t.get('status')))
    types = sorted(set(t.get('workflow_type', '') for t in all_tasks if t.get('workflow_type')))
    components = ['context-fabric', 'audit', 'git-agent', 'healing-loop', 'cli', 'observation', 'handover', 'resume', 'metrics', 'task-system', 'specification', 'design']

    return render_page("tasks.html", page_title="Tasks",
        tasks=all_tasks, statuses=statuses, types=types, components=components,
        status_filter=status_filter, type_filter=type_filter,
        component_filter=component_filter, sort_by=sort_by)


@app.route("/tasks/<task_id>")
def task_detail(task_id):
    # Validate task_id
    if not re_mod.match(r'^T-\d{3}$', task_id):
        abort(404)

    # Find task file
    task_data = None
    task_content = ""
    for location in ['active', 'completed']:
        task_dir = PROJECT_ROOT / ".tasks" / location
        if task_dir.exists():
            for f in task_dir.glob(f"{task_id}-*.md"):
                file_content = f.read_text()
                fm_match = re_mod.match(r'^---\n(.*?)\n---\n(.*)', file_content, re_mod.DOTALL)
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

    # Load episodic data
    episodic = None
    episodic_file = PROJECT_ROOT / ".context" / "episodic" / f"{task_id}.yaml"
    if episodic_file.exists():
        with open(episodic_file) as f:
            episodic = yaml.safe_load(f)

    # Status allowlist for write-back
    status_options = ['captured', 'refined', 'started-work', 'issues', 'blocked', 'work-completed']

    return render_page("task_detail.html", page_title=f"Task {task_id}",
        task=task_data, task_content=task_content, episodic=episodic,
        task_id=task_id, status_options=status_options)


@app.route("/decisions")
def decisions():
    all_decisions = []

    # Architectural decisions from 005-DesignDirectives.md
    design_file = PROJECT_ROOT / "005-DesignDirectives.md"
    if design_file.exists():
        content = design_file.read_text()
        for line in content.split('\n'):
            if line.startswith('|') and line.strip().startswith('| AD-'):
                cols = [c.strip() for c in line.split('|')[1:-1]]
                if len(cols) >= 4:
                    all_decisions.append({
                        'id': cols[0],
                        'type': 'architectural',
                        'date': cols[1],
                        'decision': cols[2][:120],
                        'directives_served': cols[3],
                        'rationale': cols[4] if len(cols) > 4 else '',
                        'task': '',
                        'alternatives': [],
                    })

    # Operational decisions from decisions.yaml
    dec_file = PROJECT_ROOT / ".context" / "project" / "decisions.yaml"
    if dec_file.exists():
        with open(dec_file) as f:
            data = yaml.safe_load(f)
        if data:
            for d in data.get('decisions', []):
                all_decisions.append({
                    'id': d.get('id', ''),
                    'type': 'operational',
                    'date': str(d.get('date', '')),
                    'decision': d.get('decision', '')[:120],
                    'directives_served': ', '.join(d.get('directives_served', [])),
                    'rationale': d.get('rationale', ''),
                    'task': d.get('task', ''),
                    'alternatives': d.get('alternatives_rejected', []),
                })

    has_rationale = any(d.get('rationale') for d in all_decisions)
    return render_page("decisions.html", page_title="Decisions",
        decisions=all_decisions, rationale_map=has_rationale)


@app.route("/learnings")
def learnings():
    # Learnings
    learnings_list = []
    lf = PROJECT_ROOT / ".context" / "project" / "learnings.yaml"
    if lf.exists():
        with open(lf) as f:
            data = yaml.safe_load(f)
        if data:
            learnings_list = data.get('learnings', [])

    # Patterns (grouped by type)
    patterns_grouped = {'failure': [], 'success': [], 'workflow': []}
    pf = PROJECT_ROOT / ".context" / "project" / "patterns.yaml"
    if pf.exists():
        with open(pf) as f:
            data = yaml.safe_load(f)
        if data:
            patterns_grouped['failure'] = data.get('failure_patterns', [])
            patterns_grouped['success'] = data.get('success_patterns', [])
            patterns_grouped['workflow'] = data.get('workflow_patterns', [])

    # Practices
    practices_list = []
    prf = PROJECT_ROOT / ".context" / "project" / "practices.yaml"
    if prf.exists():
        with open(prf) as f:
            data = yaml.safe_load(f)
        if data:
            practices_list = data.get('practices', [])

    return render_page("learnings.html", page_title="Learnings",
        learnings=learnings_list, patterns=patterns_grouped,
        practices=practices_list)


@app.route("/gaps")
def gaps():
    gaps_list = []
    gf = PROJECT_ROOT / ".context" / "project" / "gaps.yaml"
    if gf.exists():
        with open(gf) as f:
            data = yaml.safe_load(f)
        if data:
            gaps_list = data.get('gaps', [])

    return render_page("gaps.html", page_title="Gaps", gaps=gaps_list)


@app.route("/search")
def search():
    query = request.args.get('q', '').strip()
    results = {}

    if query and len(query) >= 2:
        # Sanitize: only allow alphanumeric, spaces, hyphens, underscores
        safe_query = re_mod.sub(r'[^\w\s\-]', '', query)
        if safe_query:
            try:
                search_paths = [
                    str(PROJECT_ROOT / ".tasks"),
                    str(PROJECT_ROOT / ".context"),
                ]
                # Add spec docs if they exist
                for spec in PROJECT_ROOT.glob("0*.md"):
                    search_paths.append(str(spec))

                result = subprocess.run(
                    ['grep', '-rn', '--include=*.yaml', '--include=*.md',
                     '-i', '-l', safe_query] + search_paths,
                    capture_output=True, text=True, timeout=10
                )
                files = result.stdout.strip().split('\n') if result.stdout.strip() else []

                # Group by type
                for fpath in files[:50]:
                    if '.tasks/' in fpath:
                        category = 'Tasks'
                    elif '.context/episodic/' in fpath:
                        category = 'Episodic Memory'
                    elif '.context/project/' in fpath:
                        category = 'Project Memory'
                    elif '.context/handovers/' in fpath:
                        category = 'Handovers'
                    else:
                        category = 'Specifications'

                    if category not in results:
                        results[category] = []

                    # Get matching lines (max 3)
                    matches = []
                    try:
                        line_result = subprocess.run(
                            ['grep', '-n', '-i', '-m', '3', safe_query, fpath],
                            capture_output=True, text=True, timeout=5
                        )
                        if line_result.stdout.strip():
                            matches = line_result.stdout.strip().split('\n')[:3]
                    except Exception:
                        pass

                    results[category].append({
                        'path': fpath.replace(str(PROJECT_ROOT) + '/', ''),
                        'matches': matches,
                    })
            except Exception:
                pass

    return render_page("search.html", page_title="Search",
        query=query, results=results)


@app.route("/api/task/<task_id>/status", methods=["POST"])
def update_task_status(task_id):
    # Validate task_id
    if not re_mod.match(r'^T-\d{3}$', task_id):
        abort(404)

    # Validate status against allowlist
    status = request.form.get('status', '')
    allowed = ['captured', 'refined', 'started-work', 'issues', 'blocked', 'work-completed']
    if status not in allowed:
        return '<p style="color: var(--pico-del-color);">Invalid status value</p>', 400

    # Route through fw task update (preserves automation triggers)
    try:
        result = subprocess.run(
            [str(FRAMEWORK_ROOT / "bin" / "fw"), "task", "update", task_id, "--status", status],
            capture_output=True, text=True, timeout=30,
            env={**os.environ, 'PROJECT_ROOT': str(PROJECT_ROOT)}
        )
        if result.returncode == 0:
            return f'<p style="color: var(--pico-ins-color);">Status updated to {status}</p>'
        else:
            return f'<p style="color: var(--pico-del-color);">Error: {result.stderr[:200]}</p>', 500
    except Exception as e:
        return f'<p style="color: var(--pico-del-color);">Error: {str(e)[:200]}</p>', 500

# ---------------------------------------------------------------------------
# Error handlers
# ---------------------------------------------------------------------------


@app.errorhandler(403)
def forbidden(e):
    return render_template(
        "_wrapper.html",
        _content_template="_error.html",
        page_title="Forbidden",
        error_title="403 Forbidden",
        error_message=str(e.description) if hasattr(e, "description") else str(e),
        nav_items=NAV_ITEMS,
        active_endpoint=None,
    ), 403


@app.errorhandler(404)
def not_found(e):
    return render_template(
        "_wrapper.html",
        _content_template="_error.html",
        page_title="Not Found",
        error_title="404 Not Found",
        error_message="The requested page does not exist.",
        nav_items=NAV_ITEMS,
        active_endpoint=None,
    ), 404

# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(
        description="Agentic Engineering Framework — Web UI",
    )
    parser.add_argument(
        "--port", "-p",
        type=int,
        default=int(os.environ.get("FW_PORT", "3000")),
        help="Port to listen on (default: 3000, env: FW_PORT)",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        default=False,
        help="Enable Flask debug mode",
    )
    args = parser.parse_args()

    host = os.environ.get("FW_HOST", "0.0.0.0")
    port = args.port

    # Graceful shutdown on Ctrl-C
    def handle_sigint(sig, frame):
        print("\nShutting down fw serve...")
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_sigint)

    print("fw serve running at http://{}:{}".format(host, port))
    print("  Project root: {}".format(PROJECT_ROOT))
    print("  Framework:    {}".format(FRAMEWORK_ROOT))
    print()

    try:
        app.run(host=host, port=port, debug=args.debug)
    except OSError as exc:
        if "Address already in use" in str(exc) or "address already in use" in str(exc):
            print(
                "\nERROR: Port {} is already in use.".format(port),
                file=sys.stderr,
            )
            print(
                "  Try: fw serve --port {}".format(port + 1),
                file=sys.stderr,
            )
            sys.exit(1)
        raise


if __name__ == "__main__":
    main()
