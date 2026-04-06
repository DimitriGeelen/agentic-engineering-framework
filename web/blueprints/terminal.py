"""Terminal blueprint — interactive web terminal for Watchtower (T-964, T-966)."""

import json
import subprocess

from flask import Blueprint, jsonify

from web.shared import render_page

bp = Blueprint("terminal", __name__)


@bp.route("/terminal")
def terminal_page():
    """Render the interactive terminal page."""
    return render_page(
        "terminal.html",
        page_title="Terminal",
    )


@bp.route("/api/termlink/sessions")
def termlink_sessions():
    """List active TermLink sessions for attachment (T-966)."""
    try:
        result = subprocess.run(
            ["termlink", "list", "--json"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0 and result.stdout.strip():
            data = json.loads(result.stdout)
            sessions = data.get("sessions", []) if isinstance(data, dict) else data
            return jsonify([{
                "id": s.get("id", ""),
                "name": s.get("display_name", s.get("name", "")),
                "state": s.get("state", "unknown"),
                "tags": s.get("tags", []),
                "pid": s.get("pid"),
            } for s in sessions if isinstance(s, dict)])
    except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError):
        pass
    return jsonify([])
