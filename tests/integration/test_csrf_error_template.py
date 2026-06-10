"""T-2309: CSRF 403 distinguished from generic 403 in Watchtower error handler.

Cross-project bug P-003 (filed by /opt/100-Video-riper-and-translation-app on
2026-06-09): a stale CSRF token on /inception/<T>/decide hits
csrf_protect() at web/app.py:120 which aborts with description
"CSRF token missing or invalid". The generic @app.errorhandler(403) rendered
_error.html with that message verbatim — no Reload guidance, indistinguishable
from a real permission denial. Sovereignty-critical UX (inception decide is the
final gate on the human's go/no-go) silently failed.

T-2309 Slice 1 fix: forbidden() branches on description.startswith("CSRF token")
→ renders _error_csrf.html (Session expired + Reload button).

These tests pin:
  - CSRF 403 → friendly Session-expired template + Reload action
  - Generic 403 → original Forbidden template (regression check)
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


def _client():
    from web.app import app
    return app.test_client()


def test_csrf_403_renders_session_expired_template():
    """A POST without the session's CSRF token must surface the friendly template."""
    client = _client()
    # Issue any state-change request without the _csrf_token; csrf_protect() fires.
    resp = client.post("/inception/T-2303/decide", data={"decision": "defer", "rationale": "x"})
    assert resp.status_code == 403, f"expected 403, got {resp.status_code}"
    body = resp.get_data(as_text=True)
    # Friendly headline
    assert "Session expired" in body, "missing 'Session expired' headline"
    # Reload action present
    assert "location.reload()" in body, "missing Reload button onclick"
    assert "Reload page" in body, "missing 'Reload page' button text"
    # The bare technical jargon must NOT be the prominent text (h1 / page title).
    # It may appear in the small technical-detail line — that's allowed.
    assert "<h1>403 Forbidden</h1>" not in body, \
        "CSRF response leaked into generic 403 template — h1 should say 'Session expired'"


def test_generic_403_unchanged_for_non_csrf_path():
    """Non-CSRF 403 paths must still render the original _error.html template.

    Invokes the error handler directly with a Forbidden exception whose
    description does NOT start with 'CSRF token'. Avoids registering routes
    on the live app (which Flask rejects after first request).
    """
    from werkzeug.exceptions import Forbidden

    from web.app import app

    with app.test_request_context("/__nonexistent__"):
        # forbidden() reads e.description. Pass a non-CSRF description.
        exc = Forbidden(description="You do not have permission to access this resource.")
        # Look up the registered 403 handler and invoke it.
        handler = app.error_handler_spec[None][403][type(exc)]
        result = handler(exc)
        # Flask handlers may return (body, status) tuple
        body = result[0] if isinstance(result, tuple) else result
        # Render to string if it's a Flask Response
        body_str = body.get_data(as_text=True) if hasattr(body, "get_data") else str(body)
        assert "403 Forbidden" in body_str, "generic 403 lost its headline"
        assert "Session expired" not in body_str, \
            "non-CSRF 403 incorrectly routed to _error_csrf.html"
        assert "location.reload()" not in body_str, \
            "non-CSRF 403 incorrectly got Reload button"


def test_csrf_template_includes_technical_detail_for_diagnosis():
    """Technical detail (CSRF/token) MAY appear in a small secondary line for operator diagnosis."""
    client = _client()
    resp = client.post("/inception/T-2303/decide", data={"decision": "defer", "rationale": "x"})
    body = resp.get_data(as_text=True)
    # The friendly template shows the original description in a <small> for operator awareness.
    # It must contain the literal CSRF jargon, just NOT as the prominent h1.
    assert "CSRF token" in body, "technical detail missing from _error_csrf.html"
