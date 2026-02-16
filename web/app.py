#!/usr/bin/env python3
"""
Watchtower — Agentic Engineering Framework Web UI

Flask application serving the Watchtower command center with htmx-powered
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

from flask import abort, render_template, request, session

from web.shared import APP_DIR, NAV_ITEMS, NAV_GROUPS, build_ambient

# ---------------------------------------------------------------------------
# Flask application
# ---------------------------------------------------------------------------

from flask import Flask

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
        token = request.form.get("_csrf_token") or request.headers.get("X-CSRF-Token")
        if not token or token != session.get("_csrf_token"):
            abort(403, description="CSRF token missing or invalid")


# Make csrf_token available in all templates
app.jinja_env.globals["csrf_token"] = generate_csrf_token

# ---------------------------------------------------------------------------
# Register blueprints
# ---------------------------------------------------------------------------

from web.blueprints.core import bp as core_bp
from web.blueprints.tasks import bp as tasks_bp
from web.blueprints.timeline import bp as timeline_bp
from web.blueprints.discovery import bp as discovery_bp
from web.blueprints.quality import bp as quality_bp
from web.blueprints.session import bp as session_bp
from web.blueprints.metrics import bp as metrics_bp
from web.blueprints.cockpit import bp as cockpit_bp
from web.blueprints.inception import bp as inception_bp

app.register_blueprint(core_bp)
app.register_blueprint(tasks_bp)
app.register_blueprint(timeline_bp)
app.register_blueprint(discovery_bp)
app.register_blueprint(quality_bp)
app.register_blueprint(session_bp)
app.register_blueprint(metrics_bp)
app.register_blueprint(cockpit_bp)
app.register_blueprint(inception_bp)

# ---------------------------------------------------------------------------
# Error handlers
# ---------------------------------------------------------------------------


def _error_context():
    """Common context for error pages."""
    return {
        "nav_groups": NAV_GROUPS,
        "nav_items": NAV_ITEMS,
        "active_endpoint": None,
        "ambient": build_ambient(),
    }


@app.errorhandler(403)
def forbidden(e):
    return render_template(
        "_wrapper.html",
        _content_template="_error.html",
        page_title="Forbidden",
        error_title="403 Forbidden",
        error_message=str(e.description) if hasattr(e, "description") else str(e),
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

    def handle_sigint(sig, frame):
        print("\nShutting down Watchtower...")
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_sigint)

    print("Watchtower running at http://{}:{}".format(host, port))
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
