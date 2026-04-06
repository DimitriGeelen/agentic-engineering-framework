"""Terminal blueprint — interactive web terminal for Watchtower (T-964)."""

from flask import Blueprint

from web.shared import render_page

bp = Blueprint("terminal", __name__)


@bp.route("/terminal")
def terminal_page():
    """Render the interactive terminal page."""
    return render_page(
        "terminal.html",
        page_title="Terminal",
    )
