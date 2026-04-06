"""Sessions blueprint — terminal session management page (T-983)."""

from flask import Blueprint

from web.shared import render_page
from web.terminal.registry import SessionRegistry

bp = Blueprint("sessions_page", __name__)

_registry = None


def _get_registry():
    global _registry
    if _registry is None:
        _registry = SessionRegistry()
    return _registry


@bp.route("/sessions")
def sessions_page():
    """Render the sessions management page."""
    registry = _get_registry()
    sessions = registry.list_all()
    active_count = len([s for s in sessions if s.status in ("active", "idle", "paused")])
    return render_page(
        "sessions.html",
        page_title="Sessions",
        sessions=sessions,
        active_count=active_count,
        total_count=len(sessions),
    )
