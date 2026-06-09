"""T-2278 (T-2277 Leg A): port-scoped SESSION_COOKIE_NAME.

Pins the contract that each Watchtower instance writes to its own browser
cookie slot — `fw_session_<port>` — so visits across instances on the same
host cannot overwrite each other's session cookie. This eliminates the
cross-instance CSRF-403 class documented in T-2277.

Background:
  - Flask defaults SESSION_COOKIE_NAME="session".
  - RFC 6265 (HTTP State Management) §4.1.2.3 ignores port when scoping
    cookies — so two Watchtower instances on different ports of the same
    host share one browser cookie slot under the default name.
  - Each Watchtower instance has a unique secret_key (T-1306, persisted
    per-project to .context/working/.fw-secret-key). When the browser's
    `session` cookie has been overwritten by another instance, this
    instance's itsdangerous signature verification fails → empty session
    → CSRF token mismatch → 403 "CSRF token missing or invalid".

The structural fix is a 2-line config change in web/app.py. These tests
pin that the change is in place, that the cookie name follows the
expected format, and that two apps with different ports produce
distinct cookie names.
"""

from __future__ import annotations

import importlib
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


def _create_app_with_port(port: int):
    """Reload `web.config` + `web.app` with FW_PORT set to `port`.

    `Config.PORT` is read at module import time (web/config.py:55), so we
    have to re-import to pick up an env-var change.
    """
    os.environ["FW_PORT"] = str(port)
    import web.config
    importlib.reload(web.config)
    import web.app
    importlib.reload(web.app)
    return web.app.create_app()


def test_cookie_name_format_matches_fw_session_port():
    """The cookie name follows the `fw_session_<port>` format."""
    app = _create_app_with_port(3000)
    assert app.config["SESSION_COOKIE_NAME"] == "fw_session_3000"


def test_two_apps_with_different_ports_produce_distinct_names():
    """Two Watchtower instances on different ports write to distinct cookie slots."""
    app_a = _create_app_with_port(3000)
    name_a = app_a.config["SESSION_COOKIE_NAME"]

    app_b = _create_app_with_port(3101)
    name_b = app_b.config["SESSION_COOKIE_NAME"]

    assert name_a != name_b, (
        "Two apps with different FW_PORT must produce distinct "
        f"SESSION_COOKIE_NAME values (got {name_a!r} and {name_b!r})"
    )
    assert name_a == "fw_session_3000"
    assert name_b == "fw_session_3101"


def test_cookie_name_is_idempotent_for_same_port():
    """Re-creating the app on the same port reuses the same cookie name (no random suffix)."""
    app1 = _create_app_with_port(3000)
    app2 = _create_app_with_port(3000)
    assert app1.config["SESSION_COOKIE_NAME"] == app2.config["SESSION_COOKIE_NAME"]


def test_cookie_name_is_not_flask_default_session():
    """The cookie name MUST NOT be the Flask default 'session' — that's the bug T-2278 fixes."""
    app = _create_app_with_port(3000)
    assert app.config["SESSION_COOKIE_NAME"] != "session"


@pytest.fixture(autouse=True)
def _restore_default_port():
    """Restore FW_PORT and reimport modules after each test so other tests aren't poisoned."""
    yield
    os.environ.pop("FW_PORT", None)
    import web.config
    importlib.reload(web.config)
    import web.app
    importlib.reload(web.app)
