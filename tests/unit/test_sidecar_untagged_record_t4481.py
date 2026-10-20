"""T-4481 — a session record naming a discover-visible TermLink session is injected into
even when that session lacks the fw-project tag (hand-registered `termlink register --shell`);
the injector WARNs instead of falling back to tmux / "terminal not injectable"."""
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, inject  # noqa: E402


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "t4481"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t4481\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("TERMLINK_SESSION_ID", raising=False)
    return root


def _runner(sessions, typed):
    def run(argv, **_):
        if argv[:2] == ["termlink", "discover"]:
            return subprocess.CompletedProcess(argv, 0, json.dumps({"sessions": sessions}), "")
        typed.append(argv)
        return subprocess.CompletedProcess(argv, 0, "", "")
    return run


def _rec(monkeypatch, tl="tl-5otlbnoj", **kw):
    rec = {"session_id": "sess-1", "termlink_session": tl, "claude_pid": 4242,
           "headless": False, "ready": True, "alive": True,
           "updated_at": datetime.now(timezone.utc).isoformat(), **kw}
    monkeypatch.setattr(adapter, "session_records", lambda: [rec])


def test_untagged_session_named_by_record_is_targeted_with_warning(proj, monkeypatch, capsys):
    _rec(monkeypatch)
    typed: list = []
    sessions = [{"id": "tl-5otlbnoj", "tags": [], "metadata": {}}]
    target, why = inject.choose_target(False, _runner(sessions, typed))
    assert target is not None, why
    assert target.get("route") != "tmux" and target["termlink_session"] == "tl-5otlbnoj"
    assert "record names tl-5otlbnoj but tl-5otlbnoj lacks the project tag" in why
    assert "lacks the project tag" in capsys.readouterr().err


def test_record_naming_session_discover_cannot_see_is_not_targeted(proj, monkeypatch):
    _rec(monkeypatch, tl="tl-gone")
    monkeypatch.setattr(inject, "_choose_tmux", lambda *a, **k: (None, ""))
    target, why = inject.choose_target(False, _runner([{"id": "tl-other", "tags": []}], []))
    assert target is None and "tl-gone" not in why


def test_session_tagged_for_another_project_is_not_taken(proj, monkeypatch):
    _rec(monkeypatch)
    monkeypatch.setattr(inject, "_choose_tmux", lambda *a, **k: (None, ""))
    sessions = [{"id": "tl-5otlbnoj", "tags": ["fw-project=0000"]}]
    target, _ = inject.choose_target(False, _runner(sessions, []))
    assert target is None


def test_headless_record_does_not_pull_in_untagged_session(proj, monkeypatch):
    _rec(monkeypatch, headless=True)
    monkeypatch.setattr(inject, "_choose_tmux", lambda *a, **k: (None, ""))
    target, _ = inject.choose_target(True, _runner([{"id": "tl-5otlbnoj", "tags": []}], []))
    assert target is None
