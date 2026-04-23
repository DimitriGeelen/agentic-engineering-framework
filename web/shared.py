"""Shared helpers for the web UI blueprints."""
from __future__ import annotations

import logging
import os
import re as re_mod
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import yaml
from flask import render_template, request

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

APP_DIR = Path(__file__).resolve().parent
FRAMEWORK_ROOT = APP_DIR.parent


def _discover_project_root(start: Path) -> Path | None:
    """Walk up from `start` looking for `.framework.yaml` (consumer marker).

    Returns the first ancestor containing `.framework.yaml`, or None if
    filesystem root is reached. Matches bash `paths.sh` behaviour (T-1310).
    """
    try:
        cur = Path(start).resolve()
    except OSError:
        return None
    while True:
        if (cur / ".framework.yaml").is_file():
            return cur
        if cur.parent == cur:
            return None
        cur = cur.parent


def _resolve_project_root() -> tuple[Path, str]:
    """Resolve PROJECT_ROOT from (in order): env var, discovered, FRAMEWORK_ROOT.

    Returns (path, source_label) where source ∈ {'env', 'discovered', 'framework'}.
    Env wins unconditionally — operators and `bin/fw` rely on it.
    """
    env_val = os.environ.get("PROJECT_ROOT")
    if env_val:
        return Path(env_val), "env"
    discovered = _discover_project_root(Path.cwd())
    if discovered is not None:
        return discovered, "discovered"
    return FRAMEWORK_ROOT, "framework"


PROJECT_ROOT, _PROJECT_ROOT_SOURCE = _resolve_project_root()
if _PROJECT_ROOT_SOURCE != "env":
    logger.debug("PROJECT_ROOT resolved via %s: %s", _PROJECT_ROOT_SOURCE, PROJECT_ROOT)


def task_id_sort_key(value):
    """Extract numeric portion of task ID for natural sorting.

    Works with task ID strings ('T-1000'), Path objects, or dicts with 'id' key.
    """
    s = value.get("id", "") if isinstance(value, dict) else str(value)
    m = re_mod.search(r"T-(\d+)", s)
    return int(m.group(1)) if m else 0

# ---------------------------------------------------------------------------
# Navigation — grouped for Watchtower command center
# ---------------------------------------------------------------------------

NAV_GROUPS = [
    ("Work", [
        ("Tasks",       "tasks.tasks",              None),
        ("Inception",   "inception.inception_list",  None),
        ("Assumptions", "inception.assumptions_list", None),
        ("Timeline",    "timeline.timeline",         None),
        ("Prompts",     "prompts.prompts_list",      None),
    ]),
    ("Knowledge", [
        ("Learnings",   "discovery.learnings",   None),
        ("Graduation",  "discovery.graduation",  None),
        ("Patterns",    "discovery.patterns",     None),
        ("Decisions",   "discovery.decisions",    None),
    ]),
    ("Architecture", [
        ("Fabric",      "fabric.fabric_overview",   None),
        ("Explorer",    "fabric.fabric_graph",      None),
        ("Terminal",    "terminal.terminal_page",    None),
        ("Sessions",    "sessions_page.sessions_page", None),
    ]),
    ("Govern", [
        ("Approvals",     "approvals.approvals",                   None),
        ("Directives",    "core.directives",                       None),
        ("Enforcement",   "enforcement.enforcement_dashboard",     None),
        ("Discoveries",   "discoveries_bp.discoveries_dashboard",  None),
        ("Risks",         "risks.risk_register",                   None),
        ("Gaps",          "discovery.gaps",                        None),
        ("Quality",       "quality.quality_gate",                  None),
        ("Metrics",       "metrics.project_metrics",               None),
        ("Costs",         "costs.costs_dashboard",                 None),
        ("Config",        "config.config_page",                    None),
        ("Cron",          "cron.cron_registry",                    None),
        ("Pending",       "pending.pending_page",                  None),
    ]),
]

# Flat list for backward compat (used in error handlers, etc.)
NAV_ITEMS = []
for _group_name, _items in NAV_GROUPS:
    NAV_ITEMS.extend(_items)


# ---------------------------------------------------------------------------
# Ambient status strip — data gathered once per request
# ---------------------------------------------------------------------------

def build_ambient():
    """Build ambient status data for the status strip."""
    ambient = {
        "focus_task": None,
        "session_age": None,
        "audit_status": None,
        "attention_count": 0,
    }

    # Focus task — prefer .context/working/focus.yaml (T-1308), fall back to
    # first active task alphabetically when focus is null/missing/malformed.
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    focus_file = PROJECT_ROOT / ".context" / "working" / "focus.yaml"
    focus_data = load_yaml(focus_file, label="focus.yaml") if focus_file.exists() else {}
    current = (focus_data or {}).get("current_task")
    if current and re_mod.match(r"^T-\d{3,}$", str(current)):
        ambient["focus_task"] = str(current)
    if active_dir.exists():
        active_tasks = sorted(active_dir.glob("T-*.md"), key=task_id_sort_key)
        if active_tasks:
            if not ambient["focus_task"]:
                # Fallback: first active task alphabetically.
                stem = active_tasks[0].stem
                match = re_mod.match(r"(T-\d{3,})", stem)
                if match:
                    ambient["focus_task"] = match.group(1)
            ambient["attention_count"] = len(active_tasks)

    # Session age — from latest handover
    handovers_dir = PROJECT_ROOT / ".context" / "handovers"
    if handovers_dir.exists():
        sessions = sorted(handovers_dir.glob("S-*.md"), reverse=True)
        if sessions:
            content = sessions[0].read_text(errors="replace")
            ts_match = re_mod.search(r"timestamp:\s*(\S+)", content)
            if ts_match:
                try:
                    ts = datetime.fromisoformat(ts_match.group(1).replace("Z", "+00:00"))
                    delta = datetime.now(timezone.utc) - ts
                    hours = int(delta.total_seconds() // 3600)
                    if hours < 1:
                        ambient["session_age"] = f"{int(delta.total_seconds() // 60)}m ago"
                    elif hours < 24:
                        ambient["session_age"] = f"{hours}h ago"
                    else:
                        ambient["session_age"] = f"{hours // 24}d ago"
                except (ValueError, TypeError):
                    pass

    # Audit status — via shared helper
    _, summary, _ = load_latest_audit()
    if summary:
        if summary.get("fail", 0) > 0:
            ambient["audit_status"] = "FAIL"
        elif summary.get("warn", 0) > 0:
            ambient["audit_status"] = "WARN"
        else:
            ambient["audit_status"] = "PASS"

    return ambient


# ---------------------------------------------------------------------------
# YAML loading with visible errors (T-403: R-018, R-024)
# ---------------------------------------------------------------------------

# Collects parse errors per-request so templates can surface them.
_yaml_errors: list[str] = []


def load_yaml(path, *, label: str = ""):
    """Load a YAML file. Log and collect errors instead of silently returning {}."""
    path = Path(path)
    if not path.exists():
        return {}
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
        return data if isinstance(data, (dict, list)) else {}
    except yaml.YAMLError as exc:
        desc = label or path.name
        msg = f"YAML parse error in {desc} ({path}): {exc}"
        logger.warning(msg)
        _yaml_errors.append(f"{desc}: {exc}")
        return {}
    except Exception as exc:
        desc = label or path.name
        msg = f"Error reading {desc} ({path}): {exc}"
        logger.warning(msg)
        _yaml_errors.append(f"{desc}: {exc}")
        return {}


def get_yaml_errors() -> list[str]:
    """Return and clear collected YAML errors for the current request."""
    errors = list(_yaml_errors)
    _yaml_errors.clear()
    return errors


def load_scan() -> dict | None:
    """Load the latest scan from .context/scans/LATEST.yaml."""
    latest = PROJECT_ROOT / ".context" / "scans" / "LATEST.yaml"
    if not latest.exists():
        return None
    try:
        with open(latest) as f:
            data = yaml.safe_load(f)
        if isinstance(data, dict) and data.get("schema_version"):
            return data
    except Exception:
        pass
    return None


def parse_frontmatter(content):
    """Parse YAML frontmatter from a markdown file.

    Returns (frontmatter_dict, body_text). Returns ({}, content) if no
    frontmatter found or parsing fails.
    """
    fm_match = re_mod.match(r"^---\s*\n(.*?)\n---\n?(.*)", content, re_mod.DOTALL)
    if not fm_match:
        return {}, content
    try:
        fm = yaml.safe_load(fm_match.group(1))
    except yaml.YAMLError:
        return {}, content
    if not isinstance(fm, dict):
        return {}, content
    return fm, fm_match.group(2)


# ---------------------------------------------------------------------------
# Task metadata cache (T-1233: avoid re-reading 1200+ files on every request)
# ---------------------------------------------------------------------------

import time as _time

_task_cache = {"data": None, "names": None, "tags": None, "ts": 0}
_TASK_CACHE_TTL = 30  # seconds


def get_all_task_metadata():
    """Return list of frontmatter dicts for all tasks (active + completed).

    Cached for _TASK_CACHE_TTL seconds. Each dict has '_location' key.
    """
    now = _time.monotonic()
    if _task_cache["data"] is not None and (now - _task_cache["ts"]) < _TASK_CACHE_TTL:
        return _task_cache["data"]

    all_tasks = []
    names = {}
    for location in ("active", "completed"):
        task_dir = PROJECT_ROOT / ".tasks" / location
        if not task_dir.exists():
            continue
        for f in sorted(task_dir.glob("T-*.md"), key=task_id_sort_key):
            fm, _ = parse_frontmatter(f.read_text())
            if fm:
                fm["_location"] = location
                all_tasks.append(fm)
                tid = fm.get("id", "")
                name = fm.get("name", "")
                if tid and name:
                    names[tid] = name

    _task_cache["data"] = all_tasks
    _task_cache["names"] = names
    _task_cache["ts"] = now
    return all_tasks


def get_task_names():
    """Return {task_id: name} dict. Uses task cache."""
    now = _time.monotonic()
    if _task_cache["names"] is not None and (now - _task_cache["ts"]) < _TASK_CACHE_TTL:
        return _task_cache["names"]
    get_all_task_metadata()  # populate cache
    return _task_cache["names"] or {}


def get_episodic_tags():
    """Return {task_id: [tags]} from episodic files. Cached."""
    now = _time.monotonic()
    if _task_cache["tags"] is not None and (now - _task_cache["ts"]) < _TASK_CACHE_TTL:
        return _task_cache["tags"]

    tags = {}
    episodic_dir = PROJECT_ROOT / ".context" / "episodic"
    if episodic_dir.exists():
        for f in episodic_dir.glob("T-*.yaml"):
            try:
                with open(f) as fh:
                    edata = yaml.safe_load(fh)
                if isinstance(edata, dict):
                    tags[edata.get("task_id", f.stem)] = edata.get("tags", [])
            except yaml.YAMLError:
                continue

    _task_cache["tags"] = tags
    return tags


def sse_event(event_type, **kwargs):
    """Format a Server-Sent Event string.

    Returns 'data: {"type": "<event_type>", ...}\\n\\n'
    """
    import json
    payload = {"type": event_type, **kwargs}
    return f"data: {json.dumps(payload)}\n\n"


def load_latest_audit():
    """Load the most recent audit YAML file.

    Returns (timestamp, summary_dict, findings_list).
    Returns (None, {}, []) if no audit data found.
    Used by core.py (dashboard status) and quality.py (full audit view).
    """
    audit_dir = PROJECT_ROOT / ".context" / "audits"
    if not audit_dir.exists():
        return None, {}, []
    # T-1307: filter to date-named audits only so stray non-date YAML
    # (e.g. upgrades.yaml) can't win the reverse-sort.
    audit_files = sorted(audit_dir.glob("[0-9][0-9][0-9][0-9]-*.yaml"), reverse=True)
    if not audit_files:
        return None, {}, []
    data = load_yaml(audit_files[0], label="audit report")
    if not data:
        return None, {}, []
    timestamp = data.get("timestamp", "Unknown")
    summary = data.get("summary", {})
    findings = data.get("findings", [])
    return timestamp, summary, findings


def linkify_tasks(text):
    """Convert T-XXX references to clickable Watchtower links (T-851)."""
    if not text:
        return text
    return re_mod.sub(
        r'\b(T-\d{3,})\b',
        r'<a href="/tasks/\1">\1</a>',
        str(text),
    )


def render_page(template_name, **context):
    """Render a full page or an htmx content fragment.

    Each page template is a pure HTML fragment (no <html>, no extends).
    For full page loads, we render it inside _wrapper.html which extends
    base.html. For htmx requests (HX-Request header present), we return
    just the fragment.
    """
    context.setdefault("nav_groups", NAV_GROUPS)
    context.setdefault("nav_items", NAV_ITEMS)
    context.setdefault("active_endpoint", request.endpoint)
    context.setdefault("project_root", str(PROJECT_ROOT))
    context.setdefault("ambient", build_ambient())
    context.setdefault("yaml_errors", get_yaml_errors())

    if request.headers.get("HX-Request"):
        return render_template(template_name, **context)
    else:
        context["_content_template"] = template_name
        return render_template("_wrapper.html", **context)
