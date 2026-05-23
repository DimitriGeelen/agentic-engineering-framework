"""T-2011 (arc-007 S2d): nav-layout axis contract.

The nav layout is a 4th appearance axis (alongside palette/type/density/mode),
persisted per-browser in the same prefs file as `appearance:` (S1, T-1988) and
`pins:` (S2c, T-2010). The load-bearing guarantees:
  1. Whitelist — `_sanitise_appearance` accepts only the 3 known layouts; an
     arbitrary string falls back to the default (`topbar`). Same security shape
     as the other axes — nothing untrusted reaches an HTML attribute.
  2. Presets bind it — every preset carries a `nav` value, and selecting a
     preset applies that preset's layout.
  3. Coexistence — saving the nav axis (an appearance save) must NOT clobber
     `pins:`, and toggling a pin must NOT clobber the nav layout. Both share one
     file via read-modify-write (the T-2010 refactor).
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web.blueprints import settings as S

UID = "b" * 32


@pytest.fixture
def isolated_prefs(tmp_path, monkeypatch):
    """Point the prefs dir at a tmp dir so tests never touch a real user file."""
    monkeypatch.setattr(S, "PREFS_DIR", tmp_path / "user-preferences")
    return tmp_path


@pytest.fixture
def req_ctx(isolated_prefs):
    """A request context with a fixed signed-cookie UID, for the helper layer."""
    from web.app import app

    with app.test_request_context("/"):
        from flask import session

        session["wt_uid"] = UID
        yield


# ── 1. Axis definition ──────────────────────────────────────────────────────
def test_nav_layouts_are_the_three_patterns():
    assert set(S.NAV_LAYOUTS) == {"topbar", "sidebar", "rail"}


def test_default_appearance_nav_is_topbar():
    assert S.DEFAULT_APPEARANCE["nav"] == "topbar"


def test_every_preset_carries_a_valid_nav():
    for pid, preset in S.PRESETS.items():
        assert "nav" in preset, f"preset {pid} missing nav"
        assert preset["nav"] in S.NAV_LAYOUTS, f"preset {pid} has invalid nav {preset['nav']}"


def test_console_is_sidebar_midnight_is_rail():
    # the two non-default bindings called out in the design chat
    assert S.PRESETS["console"]["nav"] == "sidebar"
    assert S.PRESETS["midnight"]["nav"] == "rail"


# ── 2. Sanitise / whitelist ─────────────────────────────────────────────────
def test_sanitise_rejects_unknown_nav():
    assert S._sanitise_appearance({"nav": "bogus"})["nav"] == "topbar"
    assert S._sanitise_appearance({})["nav"] == "topbar"


def test_sanitise_keeps_valid_nav():
    assert S._sanitise_appearance({"nav": "sidebar"})["nav"] == "sidebar"
    assert S._sanitise_appearance({"nav": "rail"})["nav"] == "rail"


def test_sanitise_preset_sets_its_nav():
    # selecting Console (no explicit nav) should adopt the preset's sidebar layout
    assert S._sanitise_appearance({"preset": "console"})["nav"] == "sidebar"
    assert S._sanitise_appearance({"preset": "midnight"})["nav"] == "rail"
    assert S._sanitise_appearance({"preset": "calm"})["nav"] == "topbar"


def test_explicit_nav_overrides_preset_to_custom():
    # picking a layout that differs from the preset → axis wins (custom combo)
    out = S._sanitise_appearance({"preset": "calm", "nav": "rail"})
    assert out["nav"] == "rail"


# ── 3. Round-trip persistence ───────────────────────────────────────────────
def test_save_load_nav_roundtrip(req_ctx):
    S._save_appearance({"preset": "custom", "nav": "sidebar"})
    assert S._load_appearance()["nav"] == "sidebar"


# ── 4. Coexistence with pins (the shared-file regression) ────────────────────
def test_saving_nav_does_not_wipe_pins(req_ctx):
    S._toggle_pin("tasks.tasks")
    S._save_appearance({"preset": "custom", "nav": "rail"})
    assert S._load_pins() == ["tasks.tasks"]          # pins survived the nav save
    assert S._load_appearance()["nav"] == "rail"


def test_toggling_pin_does_not_wipe_nav(req_ctx):
    S._save_appearance({"preset": "custom", "nav": "sidebar"})
    S._toggle_pin("arcs.arcs_index")
    assert S._load_appearance()["nav"] == "sidebar"   # nav survived the pin toggle
    assert S._load_pins() == ["arcs.arcs_index"]


# ── 5. Save route carries the nav field ──────────────────────────────────────
def test_appearance_save_route_persists_nav(isolated_prefs):
    from web.app import app

    c = app.test_client()
    with c.session_transaction() as sess:
        sess["_csrf_token"] = "tok"
        sess["wt_uid"] = UID
    r = c.post(
        "/settings/appearance/save",
        data={"preset": "custom", "palette": "stone", "type": "inter",
              "density": "compact", "mode": "light", "nav": "sidebar", "_csrf_token": "tok"},
    )
    assert r.status_code == 200
    assert r.get_json()["appearance"]["nav"] == "sidebar"
