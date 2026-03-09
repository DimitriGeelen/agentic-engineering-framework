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
            # Skip CSRF for health and API endpoints
            if request.endpoint == "health" or request.path.startswith("/api/"):
                return
            token = (
                request.form.get("_csrf_token")
                or request.headers.get("X-CSRF-Token")
            )
            if not token or token != session.get("_csrf_token"):
                abort(403, description="CSRF token missing or invalid")

    app.jinja_env.globals["csrf_token"] = generate_csrf_token

    # Jinja2 filter: convert project path to Watchtower URL (T-376)
    from web.search_utils import path_to_link
    app.jinja_env.filters["path_to_link"] = path_to_link

    # -------------------------------------------------------------------
    # Register blueprints
    # -------------------------------------------------------------------

    from web.blueprints.core import bp as core_bp
    from web.blueprints.tasks import bp as tasks_bp
    from web.blueprints.timeline import bp as timeline_bp
    from web.blueprints.discovery import bp as discovery_bp
    from web.blueprints.quality import bp as quality_bp
    from web.blueprints.session import bp as session_bp
    from web.blueprints.metrics import bp as metrics_bp
    from web.blueprints.cockpit import bp as cockpit_bp
    from web.blueprints.inception import bp as inception_bp
    from web.blueprints.enforcement import bp as enforcement_bp
    from web.blueprints.risks import bp as risks_bp
    from web.blueprints.fabric import bp as fabric_bp
    from web.blueprints.discoveries import bp as discoveries_bp
    from web.blueprints.docs import bp as docs_bp
    from web.blueprints.settings import bp as settings_bp
    from web.blueprints.api import bp as api_bp

    app.register_blueprint(core_bp)
    app.register_blueprint(tasks_bp)
    app.register_blueprint(timeline_bp)
    app.register_blueprint(discovery_bp)
    app.register_blueprint(quality_bp)
    app.register_blueprint(session_bp)
    app.register_blueprint(metrics_bp)
    app.register_blueprint(cockpit_bp)
    app.register_blueprint(inception_bp)
    app.register_blueprint(enforcement_bp)
    app.register_blueprint(risks_bp)
    app.register_blueprint(fabric_bp)
    app.register_blueprint(discoveries_bp)
    app.register_blueprint(docs_bp)
    app.register_blueprint(settings_bp)
    app.register_blueprint(api_bp)

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

        # Check Ollama connectivity
        try:
            ollama_client.list()
            result["ollama"] = "ok"
        except Exception as e:
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
