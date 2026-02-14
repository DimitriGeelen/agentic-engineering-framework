"""Shared helpers for the web UI blueprints."""

import os
from pathlib import Path

from flask import render_template, request

# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------

APP_DIR = Path(__file__).resolve().parent
FRAMEWORK_ROOT = APP_DIR.parent
PROJECT_ROOT = Path(os.environ.get("PROJECT_ROOT", str(FRAMEWORK_ROOT)))

# ---------------------------------------------------------------------------
# Navigation items available to all templates
# ---------------------------------------------------------------------------

NAV_ITEMS = [
    ("Dashboard",  "core.index",         None),
    ("Project",    "core.project",       None),
    ("Directives", "core.directives",    None),
    ("Timeline",   "timeline.timeline",  None),
    ("Tasks",      "tasks.tasks",        None),
    ("Decisions",  "discovery.decisions", None),
    ("Learnings",  "discovery.learnings", None),
    ("Gaps",       "discovery.gaps",      None),
    ("Search",     "discovery.search",    None),
]


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
        return render_template(template_name, **context)
    else:
        context["_content_template"] = template_name
        return render_template("_wrapper.html", **context)
