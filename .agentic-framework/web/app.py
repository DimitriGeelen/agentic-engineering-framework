#!/usr/bin/env python3
"""
Watchtower — Agentic Engineering Framework Web UI

Flask application serving the Watchtower command center with htmx-powered
SPA-like navigation and Pico CSS styling.

Usage:
    python3 web/app.py [--port PORT]
    fw serve [--port PORT]
    gunicorn -w 2 -b 0.0.0.0:5050 web.wsgi:application

Environment:
    PROJECT_ROOT  — Project directory (default: auto-detect from app.py location)
    FW_PORT       — Port number (default: 3000)
    FW_SECRET_KEY — Required in production (gunicorn). Auto-generated in dev.
"""

import argparse
import logging
import os
import secrets
import signal
import sys

from flask import Flask, abort, jsonify, render_template, request, session

from web.config import Config
from web.shared import APP_DIR, NAV_ITEMS, NAV_GROUPS, PROJECT_ROOT, build_ambient

log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Application factory
# ---------------------------------------------------------------------------

def create_app() -> Flask:
    """Create and configure the Watchtower Flask application."""
    app = Flask(
        __name__,
        template_folder=str(APP_DIR / "templates"),
        static_folder=str(APP_DIR / "static"),
    )

    # Secret key: require FW_SECRET_KEY in production, auto-generate in dev
    if Config.SECRET_KEY:
        app.secret_key = Config.SECRET_KEY
    else:
        app.secret_key = secrets.token_hex(32)
        log.warning(
            "FW_SECRET_KEY not set — using auto-generated key. "
            "Set FW_SECRET_KEY for production deployment."
        )

    # -------------------------------------------------------------------
    # CSRF protection
    # -------------------------------------------------------------------

    def generate_csrf_token():
        """Return the current CSRF token, creating one if needed."""
        if "_csrf_token" not in session:
            session["_csrf_token"] = secrets.token_hex(32)
        return session["_csrf_token"]

    @app.before_request
    def csrf_protect():
        """Validate CSRF token on state-changing requests."""
        if request.method in ("POST", "PATCH", "PUT", "DELETE"):
            # Skip CSRF for health, API, and search JSON endpoints
            if request.endpoint == "health" or request.path.startswith("/api/"):
                return
            # T-409: Search endpoints use JSON + fetch (same-origin only)
            if request.path.startswith("/search/") and request.is_json:
                return
            token = (
                request.form.get("_csrf_token")
                or request.headers.get("X-CSRF-Token")
            )
            if not token or token != session.get("_csrf_token"):
                abort(403, description="CSRF token missing or invalid")

    app.jinja_env.globals["csrf_token"] = generate_csrf_token

    # Dynamic version from git tags (T-386)
    import subprocess as _sp
    try:
        _ver = _sp.check_output(
            ["git", "describe", "--tags", "--always"],
            cwd=str(PROJECT_ROOT), stderr=_sp.DEVNULL, text=True,
        ).strip()
    except Exception:
        _ver = "dev"
    app.jinja_env.globals["fw_version"] = _ver

    # Project name from directory basename (T-854, T-865: strip leading number prefix)
    import re as _re
    _raw_name = os.path.basename(
        os.path.normpath(str(PROJECT_ROOT))
    ).replace("-", " ").replace("_", " ")
    app.jinja_env.globals["project_name"] = _re.sub(r'^\d+\s*', '', _raw_name).strip()

    # Jinja2 filter: convert project path to Watchtower URL (T-376)
    from web.search_utils import path_to_link
    app.jinja_env.filters["path_to_link"] = path_to_link

    # Jinja2 filter: auto-link T-XXX task references (T-851)
    from web.shared import linkify_tasks
    from markupsafe import Markup
    app.jinja_env.filters["linkify_tasks"] = lambda text: Markup(linkify_tasks(text))

    # -------------------------------------------------------------------
    # Register blueprints (centralized in __init__.py — T-431/A2)
    # -------------------------------------------------------------------

    from web.blueprints import register_blueprints
    register_blueprints(app)

    # -------------------------------------------------------------------
    # Flask-SocketIO for web terminal (T-964)
    # -------------------------------------------------------------------

    from flask_socketio import SocketIO, emit, join_room
    from web import terminal as term_mgr

    socketio = SocketIO(app, cors_allowed_origins="*", async_mode="threading")
    app.extensions["socketio"] = socketio

    # Map SocketIO sid → set of session_ids (multi-session per connection)
    _client_sessions = {}

    @socketio.on("connect")
    def handle_connect():
        """Track the WebSocket connection."""
        from flask import request as req
        _client_sessions[req.sid] = set()

    @socketio.on("disconnect")
    def handle_disconnect():
        """Kill all PTYs owned by this WebSocket connection."""
        from flask import request as req
        for session_id in list(_client_sessions.get(req.sid, [])):
            term_mgr.kill_pty(session_id)
        _client_sessions.pop(req.sid, None)

    @socketio.on("create_session")
    def handle_create_session(data):
        """Spawn a new PTY for a named terminal session."""
        from flask import request as req
        session_id = data.get("session_id", req.sid)
        join_room(session_id)
        term_mgr.spawn_pty(session_id)
        _client_sessions.setdefault(req.sid, set()).add(session_id)

    @socketio.on("close_session")
    def handle_close_session(data):
        """Kill a specific terminal session."""
        from flask import request as req
        session_id = data.get("session_id")
        if session_id:
            if term_mgr.is_termlink_session(session_id):
                term_mgr.detach_termlink(session_id)
            else:
                term_mgr.kill_pty(session_id)
            _client_sessions.get(req.sid, set()).discard(session_id)

    @socketio.on("attach_termlink")
    def handle_attach_termlink(data):
        """Attach to an existing TermLink session for observation (T-966)."""
        from flask import request as req
        session_id = data.get("session_id")
        tl_name = data.get("tl_name")
        if session_id and tl_name:
            join_room(session_id)
            term_mgr.attach_termlink(session_id, tl_name)
            _client_sessions.setdefault(req.sid, set()).add(session_id)

    @socketio.on("pty_input")
    def handle_pty_input(data):
        """Forward browser keystrokes to the PTY."""
        session_id = data.get("session_id")
        if session_id:
            if term_mgr.is_termlink_session(session_id):
                term_mgr.write_termlink(session_id, data.get("input", ""))
            else:
                term_mgr.write_pty(session_id, data.get("input", ""))

    @socketio.on("resize")
    def handle_resize(data):
        """Resize the PTY to match the browser terminal dimensions."""
        session_id = data.get("session_id")
        rows = data.get("rows", 24)
        cols = data.get("cols", 80)
        if session_id:
            term_mgr.resize_pty(session_id, rows, cols)

    def _pty_output_loop():
        """Background thread: poll all PTYs and emit output to clients."""
        import time
        tl_poll_counter = 0
        while True:
            # Poll local PTYs (10ms)
            for session_id in list(term_mgr._sessions.keys()):
                output = term_mgr.read_pty(session_id)
                if output:
                    socketio.emit("pty_output", {
                        "session_id": session_id,
                        "output": output.decode("utf-8", errors="replace"),
                    }, to=session_id)
            # Poll TermLink sessions less frequently (every 200ms = every 20th loop)
            tl_poll_counter += 1
            if tl_poll_counter >= 20:
                tl_poll_counter = 0
                for session_id in list(term_mgr._termlink_sessions.keys()):
                    output = term_mgr.read_termlink(session_id)
                    if output:
                        socketio.emit("pty_output", {
                            "session_id": session_id,
                            "output": output,
                        }, to=session_id)
            time.sleep(0.01)  # 10ms poll interval

    import threading
    _output_thread = threading.Thread(target=_pty_output_loop, daemon=True)
    _output_thread.start()

    # -------------------------------------------------------------------
    # Health endpoint
    # -------------------------------------------------------------------

    @app.route("/health")
    def health():
        """Health check for load balancers and deployment verification.

        Returns JSON with component status. HTTP 200 if app is healthy,
        503 if critical dependencies (Ollama) are unreachable.
        """
        import ollama as ollama_client

        result = {"app": "ok"}
        healthy = True

        # Check Ollama connectivity (3s timeout prevents /health from hanging)
        import concurrent.futures
        try:
            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(ollama_client.list)
                future.result(timeout=3)
            result["ollama"] = "ok"
        except (concurrent.futures.TimeoutError, Exception):
            result["ollama"] = "unreachable"
            healthy = False

        # Check embedding index (lightweight — never trigger rebuild)
        try:
            from web.embeddings import DB_PATH, _db, _db_built_at
            if _db is not None:
                num = _db.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
                result["embeddings"] = {"status": "ok", "chunks": num}
            elif DB_PATH.exists():
                result["embeddings"] = {"status": "stale"}
            else:
                result["embeddings"] = {"status": "no_index"}
        except Exception:
            result["embeddings"] = {"status": "unavailable"}

        # Test infrastructure counts (T-1008)
        try:
            from web.shared import FRAMEWORK_ROOT
            tests = {}
            pw_dir = FRAMEWORK_ROOT / "tests" / "playwright"
            if pw_dir.exists():
                tests["playwright"] = len(list(pw_dir.glob("test_*.py")))
            unit_dir = FRAMEWORK_ROOT / "tests" / "unit"
            if unit_dir.exists():
                tests["unit"] = len(list(unit_dir.glob("*.bats")))
            int_dir = FRAMEWORK_ROOT / "tests" / "integration"
            if int_dir.exists():
                tests["integration"] = len(list(int_dir.glob("*.bats")))
            web_test = FRAMEWORK_ROOT / "web" / "test_app.py"
            if web_test.exists():
                tests["web"] = 1
            result["tests"] = tests
        except Exception:
            result["tests"] = {"status": "unavailable"}

        code = 200 if healthy else 503
        return jsonify(result), code

    # -------------------------------------------------------------------
    # Error handlers
    # -------------------------------------------------------------------

    def _error_context():
        """Common context for error pages."""
        return {
            "nav_groups": NAV_GROUPS,
            "nav_items": NAV_ITEMS,
            "active_endpoint": None,
            "ambient": build_ambient(),
            "project_root": str(PROJECT_ROOT),
        }

    @app.errorhandler(403)
    def forbidden(e):
        return render_template(
            "_wrapper.html",
            _content_template="_error.html",
            page_title="Forbidden",
            error_title="403 Forbidden",
            error_message=(
                str(e.description) if hasattr(e, "description") else str(e)
            ),
            **_error_context(),
        ), 403

    @app.errorhandler(404)
    def not_found(e):
        return render_template(
            "_wrapper.html",
            _content_template="_error.html",
            page_title="Not Found",
            error_title="404 Not Found",
            error_message="The requested page does not exist.",
            **_error_context(),
        ), 404

    @app.errorhandler(500)
    def internal_error(e):
        return render_template(
            "_wrapper.html",
            _content_template="_error.html",
            page_title="Server Error",
            error_title="500 Internal Server Error",
            error_message="An unexpected error occurred. Check the server logs.",
            **_error_context(),
        ), 500

    return app


# Module-level app for backward compat (python3 web/app.py, existing imports)
app = create_app()

# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def main():
    from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT

    parser = argparse.ArgumentParser(
        description="Watchtower — Agentic Engineering Framework Web UI",
    )
    parser.add_argument(
        "--port", "-p",
        type=int,
        default=Config.PORT,
        help="Port to listen on (default: 3000, env: FW_PORT)",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        default=False,
        help="Enable Flask debug mode",
    )
    args = parser.parse_args()

    host = Config.HOST
    port = args.port

    def handle_sigint(sig, frame):
        print("\nShutting down Watchtower...")
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_sigint)

    print("Watchtower running at http://{}:{}".format(host, port))
    print("  Project root: {}".format(PROJECT_ROOT))
    print("  Framework:    {}".format(FRAMEWORK_ROOT))
    print()

    try:
        socketio = app.extensions.get("socketio")
        if socketio:
            socketio.run(app, host=host, port=port, debug=args.debug, allow_unsafe_werkzeug=True)
        else:
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
