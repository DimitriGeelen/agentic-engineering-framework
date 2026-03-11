"""Shared helpers for the web UI blueprints."""

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
PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", str(FRAMEWORK_ROOT)))

# ---------------------------------------------------------------------------
# Navigation — grouped for Watchtower command center
# ---------------------------------------------------------------------------

NAV_GROUPS = [
    ("Work", [
        ("Tasks",       "tasks.tasks",              None),
        ("Inception",   "inception.inception_list",  None),
        ("Assumptions", "inception.assumptions_list", None),
        ("Timeline",    "timeline.timeline",         None),
    ]),
    ("Knowledge", [
        ("Learnings",   "discovery.learnings",   None),
        ("Graduation",  "discovery.graduation",  None),
        ("Patterns",    "discovery.patterns",     None),
        ("Decisions",   "discovery.decisions",    None),
    ]),
    ("Architecture", [
        ("Fabric",      "fabric.fabric_overview",   None),
        ("Graph",       "fabric.fabric_graph",      None),
    ]),
    ("Govern", [
        ("Directives",    "core.directives",                       None),
        ("Enforcement",   "enforcement.enforcement_dashboard",     None),
        ("Discoveries",   "discoveries_bp.discoveries_dashboard",  None),
        ("Risks",         "risks.risk_register",                   None),
        ("Gaps",          "discovery.gaps",                        None),
        ("Quality",       "quality.quality_gate",                  None),
        ("Metrics",       "metrics.project_metrics",               None),
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

    # Focus task — currently active tasks
    active_dir = PROJECT_ROOT / ".tasks" / "active"
    if active_dir.exists():
        active_tasks = sorted(active_dir.glob("T-*.md"))
        if active_tasks:
            # Use the first active task as focus
            stem = active_tasks[0].stem
            match = re_mod.match(r"(T-\d{3})", stem)
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

    # Audit status — from latest audit file
    audits_dir = PROJECT_ROOT / ".context" / "audits"
    if audits_dir.exists():
        audit_files = sorted(audits_dir.glob("*.yaml"), reverse=True)
        if audit_files:
            try:
                import yaml
                with open(audit_files[0]) as f:
                    data = yaml.safe_load(f)
                if data and "summary" in data:
                    s = data["summary"]
                    if s.get("fail", 0) > 0:
                        ambient["audit_status"] = "FAIL"
                    elif s.get("warn", 0) > 0:
                        ambient["audit_status"] = "WARN"
                    else:
                        ambient["audit_status"] = "PASS"
            except Exception:
                pass

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


def sse_event(event_type, **kwargs):
    """Format a Server-Sent Event string.

    Returns 'data: {"type": "<event_type>", ...}\\n\\n'
    """
    import json
    payload = {"type": event_type, **kwargs}
    return f"data: {json.dumps(payload)}\n\n"


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
