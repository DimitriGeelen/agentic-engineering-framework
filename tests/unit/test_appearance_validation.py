"""T-1988 (arc-007 S1): pin the appearance security contract.

Two attack surfaces are closed here:
  1. Whitelist validation — every appearance value is constrained to a known
     axis set before it is persisted or rendered into an HTML attribute. An
     out-of-set value (path fragment, script payload) must NOT survive.
  2. UID path safety — the per-user prefs file is keyed by a signed-cookie UID
     constrained to ^[0-9a-f]{32}$. A forged/legacy value outside that charset
     must not escape the user-preferences/ directory.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web.blueprints import settings as S


# ── 1. Whitelist validation ─────────────────────────────────────────────────
def test_sanitise_rejects_unknown_palette():
    out = S._sanitise_appearance({"palette": "../../etc/passwd"})
    assert out["palette"] == S.DEFAULT_APPEARANCE["palette"]
    assert "/" not in out["palette"]


def test_sanitise_rejects_attribute_injection_payload():
    out = S._sanitise_appearance({"type": '"><script>alert(1)</script>'})
    assert out["type"] in S.TYPES
    assert "<" not in out["type"]


def test_sanitise_accepts_known_values():
    out = S._sanitise_appearance(
        {"preset": "custom", "palette": "console", "type": "plex", "density": "cozy", "mode": "dark"}
    )
    assert (out["palette"], out["type"], out["density"], out["mode"]) == (
        "console", "plex", "cozy", "dark",
    )


def test_sanitise_preset_expands_to_combo():
    out = S._sanitise_appearance({"preset": "console"})
    expected = S.PRESETS["console"]
    assert out["preset"] == "console"
    assert out["palette"] == expected["palette"]
    assert out["type"] == expected["type"]
    assert out["mode"] == expected["mode"]


def test_sanitise_unknown_preset_marks_custom():
    out = S._sanitise_appearance({"preset": "haxor", "palette": "slate"})
    assert out["preset"] == "custom"
    assert out["palette"] == "slate"  # the valid axis still applies


def test_every_preset_axis_value_is_in_its_whitelist():
    """No preset may reference an axis value foundations.css doesn't define."""
    for pid, p in S.PRESETS.items():
        assert p["palette"] in S.PALETTES, pid
        assert p["type"] in S.TYPES, pid
        assert p["density"] in S.DENSITIES, pid
        assert p["mode"] in S.MODES, pid


# ── 2. UID path safety ──────────────────────────────────────────────────────
def test_prefs_path_rejects_traversal_uid():
    with pytest.raises(ValueError):
        S._prefs_path("../../etc/passwd")


def test_prefs_path_rejects_non_hex_uid():
    for bad in ("abc", "ZZZZ" * 8, "deadbeef" * 4 + "x", "../" + "a" * 32):
        with pytest.raises(ValueError):
            S._prefs_path(bad)


def test_prefs_path_accepts_valid_uid_and_stays_in_dir():
    uid = "a" * 32
    path = S._prefs_path(uid)
    assert path.name == f"{uid}.yaml"
    assert path.parent == S.PREFS_DIR
    # resolved path must not escape PREFS_DIR
    assert str(path.resolve()).startswith(str(S.PREFS_DIR.resolve()))
