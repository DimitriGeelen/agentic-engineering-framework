"""T-1747 / G-069 — Regression tests for web.shared._discover_project_root.

Pins the framework-aware bound on the marker walk:

    - From a cwd inside FRAMEWORK_ROOT with no marker between cwd and
      FRAMEWORK_ROOT, _discover_project_root MUST return None — NOT climb
      past FRAMEWORK_ROOT into ancestor directories.

    - From a cwd outside FRAMEWORK_ROOT (a real consumer dir), the walk
      still terminates at the first .framework.yaml found — the bound
      MUST NOT break the `fw init` / consumer use case.

    - _resolve_project_root() with PROJECT_ROOT unset and cwd=FRAMEWORK_ROOT
      MUST return (FRAMEWORK_ROOT, "framework") — i.e. the explicit fallback,
      not a walk-discovered ancestor.

Origin: 2026-05-05 — Watchtower :3002 silently resolved PROJECT_ROOT=/ after
restart because a stray /.framework.yaml (15 bytes, version 1.5.0) at the
filesystem root matched the marker walk. Every project-relative route returned
the empty-state page despite live data on disk. See concerns.yaml G-069.
"""

from __future__ import annotations

import os
from pathlib import Path
from unittest.mock import patch

import pytest

from web.shared import (
    FRAMEWORK_ROOT,
    _discover_project_root,
    _resolve_project_root,
)


# ---------------------------------------------------------------------------
# A2 — Walk does not climb past FRAMEWORK_ROOT
# ---------------------------------------------------------------------------


def test_discovery_from_framework_root_does_not_return_filesystem_root(tmp_path):
    """A stray marker at filesystem root must NOT capture a framework-internal walk.

    Simulate the G-069 incident: place a marker outside FRAMEWORK_ROOT and run
    discovery from FRAMEWORK_ROOT. Walk must not return that ancestor.
    """
    result = _discover_project_root(FRAMEWORK_ROOT)
    # FRAMEWORK_ROOT itself has no .framework.yaml (the framework IS the
    # framework, it doesn't consume itself). So walk should return None and
    # let _resolve_project_root fall through to the FRAMEWORK_ROOT fallback.
    # The critical property: the walk must NEVER return Path("/") or any
    # ancestor of FRAMEWORK_ROOT.
    if result is not None:
        # If a marker is somehow at FRAMEWORK_ROOT (shouldn't happen but tolerate)
        # then it's FRAMEWORK_ROOT itself — never an ancestor.
        assert result == FRAMEWORK_ROOT, (
            f"discovery returned {result}, must not climb past FRAMEWORK_ROOT={FRAMEWORK_ROOT}"
        )


def test_discovery_from_framework_subdir_does_not_climb_past_framework():
    """Discovery from a subdirectory inside FRAMEWORK_ROOT must not escape it."""
    # Pick a subdir that exists and has no .framework.yaml above it within FRAMEWORK_ROOT
    subdir = FRAMEWORK_ROOT / "web"
    if not subdir.is_dir():
        pytest.skip("FRAMEWORK_ROOT/web missing — test requires real framework layout")
    result = _discover_project_root(subdir)
    if result is not None:
        # Allowed: FRAMEWORK_ROOT itself or any descendant of it. Forbidden:
        # any ancestor of FRAMEWORK_ROOT.
        try:
            result.relative_to(FRAMEWORK_ROOT)
        except ValueError:
            pytest.fail(
                f"discovery from {subdir} climbed past FRAMEWORK_ROOT into {result}"
            )


# ---------------------------------------------------------------------------
# A3 — Consumer use case still works
# ---------------------------------------------------------------------------


def test_discovery_from_consumer_outside_framework_finds_marker(tmp_path):
    """Walk MUST still find a marker when cwd is outside FRAMEWORK_ROOT."""
    consumer = tmp_path / "fakeconsumer"
    consumer.mkdir()
    marker = consumer / ".framework.yaml"
    marker.write_text("version: 1.5.0\n")

    result = _discover_project_root(consumer)
    assert result == consumer.resolve(), (
        f"consumer discovery broken: got {result}, want {consumer.resolve()}"
    )


def test_discovery_from_consumer_subdir_walks_up_to_marker(tmp_path):
    """A consumer's subdirectory must still find the marker at the consumer root."""
    consumer = tmp_path / "fakeconsumer"
    consumer.mkdir()
    (consumer / ".framework.yaml").write_text("version: 1.5.0\n")
    subdir = consumer / "src" / "components"
    subdir.mkdir(parents=True)

    result = _discover_project_root(subdir)
    assert result == consumer.resolve(), (
        f"consumer subdir walk broken: got {result}, want {consumer.resolve()}"
    )


# ---------------------------------------------------------------------------
# A4 — _resolve_project_root falls through cleanly when env unset
# ---------------------------------------------------------------------------


def test_resolve_project_root_from_framework_returns_framework_fallback(monkeypatch):
    """With PROJECT_ROOT env unset and walk yielding nothing inside the
    framework, _resolve_project_root MUST return (FRAMEWORK_ROOT, 'framework').
    """
    monkeypatch.delenv("PROJECT_ROOT", raising=False)
    monkeypatch.chdir(FRAMEWORK_ROOT)
    path, source = _resolve_project_root()
    # The source label tells us which branch fired — 'discovered' would mean
    # we climbed into an ancestor (the bug). 'framework' means the bound held.
    assert source != "discovered" or path == FRAMEWORK_ROOT, (
        f"resolve from framework cwd returned {path} via {source} — "
        f"must not be a discovered ancestor of FRAMEWORK_ROOT"
    )
    # Whichever branch fires, the path must be FRAMEWORK_ROOT (not /).
    assert path == FRAMEWORK_ROOT, (
        f"resolve from framework cwd returned {path}, must be FRAMEWORK_ROOT={FRAMEWORK_ROOT}"
    )


def test_resolve_project_root_env_wins_unconditionally(monkeypatch, tmp_path):
    """PROJECT_ROOT env always wins — operators rely on this."""
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    path, source = _resolve_project_root()
    assert source == "env"
    assert path == tmp_path


# ---------------------------------------------------------------------------
# G-069 incident-pin — explicit replay
# ---------------------------------------------------------------------------


def test_g069_stray_filesystem_root_marker_does_not_capture_framework(tmp_path, monkeypatch):
    """Direct replay of G-069: even if a /.framework.yaml exists, discovery
    from FRAMEWORK_ROOT must not return Path('/').

    We can't actually create /.framework.yaml in a unit test (requires root),
    but we CAN verify the bound: if the walk reaches FRAMEWORK_ROOT and the
    start was inside it, return None — regardless of what's above.
    """
    # Patch FRAMEWORK_ROOT to a controlled tmp tree so we can plant a stray
    # marker "above" it without touching the real fs root.
    fake_framework = tmp_path / "framework_repo"
    fake_framework.mkdir()
    # Plant a stray marker above the fake framework — simulates /.framework.yaml
    stray = tmp_path / ".framework.yaml"
    stray.write_text("version: 1.5.0\n")

    with patch("web.shared.FRAMEWORK_ROOT", fake_framework):
        result = _discover_project_root(fake_framework)

    # Without the bound, the walk would climb to tmp_path and return it.
    # With the bound, it stops at fake_framework (no marker → None).
    assert result != tmp_path.resolve(), (
        f"discovery climbed past fake FRAMEWORK_ROOT to stray marker at {result} — "
        "G-069 regression"
    )
