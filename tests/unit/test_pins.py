"""T-2010 (arc-007 S2c): pinned-pages model contract.

Pins reuse the S1 (T-1988) per-browser prefs file. The load-bearing guarantees:
  1. Whitelist — only nav-leaf endpoints (web.shared.NAV_ITEMS) are pinnable;
     an arbitrary endpoint string is rejected (the security boundary, same shape
     as _sanitise_appearance for the appearance axes).
  2. Coexistence — `pins:` and `appearance:` share one prefs file via
     read-modify-write; saving one must NOT clobber the other. This is the
     regression the T-2010 refactor exists to prevent (pre-refactor
     _save_appearance dumped only {"appearance": …}).
  3. CSRF — the toggle route honours the app's custom _csrf_token contract:
     403 without a token, 200 + an hx-swap-oob strip refresh with one.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web.app import app
from web.blueprints import settings as S

UID = "a" * 32


@pytest.fixture
def isolated_prefs(tmp_path, monkeypatch):
    """Point the prefs dir at a tmp dir so tests never touch a real user file."""
    monkeypatch.setattr(S, "PREFS_DIR", tmp_path / "user-preferences")
    return tmp_path


@pytest.fixture
def req_ctx(isolated_prefs):
    """A request context with a fixed signed-cookie UID, for the helper layer."""
    with app.test_request_context("/"):
        from flask import session

        session["wt_uid"] = UID
        yield


# ── 1. Whitelist ────────────────────────────────────────────────────────────
def test_valid_pin_endpoints_are_nav_leaves():
    valid = S._valid_pin_endpoints()
    assert "tasks.tasks" in valid          # a known nav leaf
    assert valid["tasks.tasks"] == "Tasks"
    assert "core.index" not in valid       # home is not a nav leaf → not pinnable


def test_toggle_rejects_non_nav_endpoint(req_ctx):
    with pytest.raises(ValueError):
        S._toggle_pin("core.index")        # real endpoint, but not a nav leaf
    with pytest.raises(ValueError):
        S._toggle_pin("totally.fake")      # not an endpoint at all


def test_load_pins_drops_unknown_and_dupes(req_ctx, isolated_prefs):
    S._save_prefs(UID, {"pins": ["tasks.tasks", "evil.route", "tasks.tasks", "arcs.arcs_index"]})
    assert S._load_pins() == ["tasks.tasks", "arcs.arcs_index"]


# ── 2. Toggle + persistence ─────────────────────────────────────────────────
def test_toggle_adds_then_removes(req_ctx):
    assert S._load_pins() == []
    assert S._toggle_pin("tasks.tasks") is True
    assert S._load_pins() == ["tasks.tasks"]
    assert S._toggle_pin("tasks.tasks") is False
    assert S._load_pins() == []


def test_pin_state_for_reflects_membership(req_ctx):
    assert S.pin_state_for("core.index") is None        # not pinnable → no toggle
    st = S.pin_state_for("tasks.tasks")
    assert st == {"endpoint": "tasks.tasks", "label": "Tasks", "pinned": False}
    S._toggle_pin("tasks.tasks")
    assert S.pin_state_for("tasks.tasks")["pinned"] is True


# ── 3. Coexistence (the refactor regression) ────────────────────────────────
def test_saving_appearance_does_not_wipe_pins(req_ctx):
    S._toggle_pin("tasks.tasks")
    S._save_appearance({"preset": "console"})
    assert S._load_pins() == ["tasks.tasks"]            # pins survived appearance save
    assert S._load_appearance()["preset"] == "console"


def test_toggling_pin_does_not_wipe_appearance(req_ctx):
    S._save_appearance({"preset": "console"})
    S._toggle_pin("arcs.arcs_index")
    assert S._load_appearance()["preset"] == "console"  # appearance survived pin toggle
    assert S._load_pins() == ["arcs.arcs_index"]


# ── 4. CSRF route contract ──────────────────────────────────────────────────
def test_toggle_route_requires_csrf(isolated_prefs):
    c = app.test_client()
    r = c.post("/settings/pins/toggle", data={"endpoint": "tasks.tasks"})
    assert r.status_code == 403


def test_toggle_route_with_csrf_returns_oob_strip(isolated_prefs):
    c = app.test_client()
    with c.session_transaction() as sess:
        sess["_csrf_token"] = "tok"
        sess["wt_uid"] = UID
    r = c.post("/settings/pins/toggle", data={"endpoint": "tasks.tasks", "_csrf_token": "tok"})
    assert r.status_code == 200
    body = r.get_data(as_text=True)
    assert 'hx-swap-oob="true"' in body            # strip refresh
    assert 'class="nav-pin"' in body               # the newly-pinned item rendered
    assert "★" in body                              # filled star = pinned state


def test_toggle_route_rejects_non_nav_endpoint(isolated_prefs):
    c = app.test_client()
    with c.session_transaction() as sess:
        sess["_csrf_token"] = "tok"
        sess["wt_uid"] = UID
    r = c.post("/settings/pins/toggle", data={"endpoint": "core.index", "_csrf_token": "tok"})
    assert r.status_code == 400
