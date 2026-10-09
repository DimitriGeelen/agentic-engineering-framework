"""T-4003 — peer mail reaches an agent whether it was launched with `claude-fw -c` or
`claude-fw --termlink` (055's design, conversation aef-mail-delivery-both-modes).

The target is found from the agent's own claude pid → the tty it reads:
  c1  a TermLink session registered for this project (unchanged, T-3745);
  c2  else the tmux pane whose pane_tty is that tty — typed by pane id, never `fleet-<dir>`;
  c3  else nothing to type into: the reason "terminal not injectable" reaches the sender.
"""
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

FW_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FW_ROOT))

from lib.sidecar import adapter, inject, receiver, waiting  # noqa: E402

TTY = "/dev/pts/7"


@pytest.fixture
def proj(tmp_path, monkeypatch):
    root = tmp_path / "t4003"
    (root / ".context").mkdir(parents=True)
    (root / ".framework.yaml").write_text("project_name: t4003\n")
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FW_SIDECAR_REGISTRY_DIR", str(tmp_path / "registry"))
    monkeypatch.delenv("TERMLINK_SESSION_ID", raising=False)
    return root


class Runner:
    """`termlink discover` answers `sessions`; `tmux list-panes` answers `panes`; every other
    call is recorded as typing."""

    def __init__(self, sessions=(), panes=(), tmux=True, private=()):
        self.sessions, self.panes, self.tmux, self.typed = list(sessions), list(panes), tmux, []
        self.private = list(private)

    def __call__(self, argv, **_):
        if argv[:2] == ["termlink", "discover"]:
            return subprocess.CompletedProcess(argv, 0, json.dumps({"sessions": self.sessions}), "")
        if argv[0] == "tmux" and "list-panes" in argv:
            if not self.tmux:
                raise FileNotFoundError("tmux")
            panes = self.private if argv[1:3] == ["-L", "fw-agents"] else self.panes
            out = "\n".join(f"{t} {p} {s}" for t, p, s in panes)
            return subprocess.CompletedProcess(argv, 0, out, "")
        self.typed.append(argv)
        return subprocess.CompletedProcess(argv, 0, "", "")


def _record(monkeypatch, ready=True, tty=TTY):
    rec = {"session_id": "sess-1", "termlink_session": None, "claude_pid": 4242, "headless": False,
           "ready": ready, "alive": True,
           "updated_at": datetime.now(timezone.utc).isoformat()}
    monkeypatch.setattr(adapter, "session_records", lambda: [rec])
    monkeypatch.setattr(inject, "_tty_of", lambda pid: tty)
    return rec


def _free(_root):
    return True, "free"


def test_c2_types_into_the_pane_that_owns_the_agents_tty(proj, monkeypatch):
    _record(monkeypatch)
    r = Runner(panes=[("/dev/pts/3", "%1", "other"), (TTY, "%9", "work")])
    target, why = inject.choose_target(False, r, input_state=_free)
    assert target["route"] == "tmux" and target["pane"] == "%9", why


def test_c2_delivery_types_the_fixed_line_by_pane_id_then_enter(proj, monkeypatch):
    _record(monkeypatch)
    r = Runner(panes=[(TTY, "%9", "work")])
    monkeypatch.setattr(receiver, "awaiting_handover", lambda: ["m-1"])
    monkeypatch.setattr(receiver, "read_message", lambda m: {"urgent": False})
    monkeypatch.setattr(inject, "_inject_marker", lambda m: proj / f"{m}.injected")
    monkeypatch.setattr(receiver, "record_event", lambda *a, **k: None)
    rep = inject._deliver_locked("test", r)
    assert rep["injected"] == ["m-1"] and rep["route"] == "tmux", rep
    assert r.typed[0][:5] == ["tmux", "send-keys", "-t", "%9", "-l"]
    assert r.typed[0][5] == inject.injection_line(["m-1"])          # no peer content
    assert r.typed[1] == ["tmux", "send-keys", "-t", "%9", "Enter"]


def test_c2_never_types_into_a_busy_agent_unless_urgent(proj, monkeypatch):
    _record(monkeypatch, ready=False)
    r = Runner(panes=[(TTY, "%9", "work")])
    target, why = inject.choose_target(False, r, input_state=_free)
    assert target is None and why.startswith("agent not ready") and not waiting.is_no_recipient(why)
    target, why = inject.choose_target(True, r, input_state=_free)
    assert target and target["pane"] == "%9" and "URGENT" in why


def test_c2_fleet_pane_waits_when_the_cockpit_says_someone_may_be_typing(proj, monkeypatch):
    _record(monkeypatch)
    r = Runner(panes=[(TTY, "%9", "fleet-t4003")])
    target, why = inject.choose_target(False, r, input_state=lambda root: (False, "cockpit pane unlocked"))
    assert target is None and "cockpit pane unlocked" in why and not waiting.is_no_recipient(why)


def test_c3_bare_terminal_is_not_injectable_and_the_sender_is_told(proj, monkeypatch):
    _record(monkeypatch)
    r = Runner(panes=[("/dev/pts/3", "%1", "other")])
    target, why = inject.choose_target(False, r, input_state=_free)
    assert target is None and why.startswith("terminal not injectable (/dev/pts/7)")
    assert waiting.is_no_recipient(why)


def test_c3_without_tmux_installed(proj, monkeypatch):
    _record(monkeypatch)
    target, why = inject.choose_target(False, Runner(tmux=False), input_state=_free)
    assert target is None and why.startswith("terminal not injectable")


def test_c1_termlink_still_wins_and_tmux_is_not_consulted(proj, monkeypatch):
    rec = _record(monkeypatch)
    rec["termlink_session"] = "tl-abc"
    r = Runner(sessions=[{"id": "tl-abc", "tags": ["claude", inject.project_tag()], "metadata": {}}],
               panes=[(TTY, "%9", "work")])
    target, why = inject.choose_target(False, r, input_state=_free)
    assert target["termlink_session"] == "tl-abc" and target.get("route") is None, why


def test_input_state_404_or_error_is_unknown_never_free():
    def boom(url):
        raise OSError("404")
    ok, why = inject._cockpit_input_state(Path("/p"), fetch=boom)
    assert ok is False and "unknown" in why
    old = (datetime.now(timezone.utc) - timedelta(minutes=10)).strftime("%Y-%m-%dT%H:%M:%SZ")
    assert inject._cockpit_input_state(Path("/p"), fetch=lambda u: {
        "unlocked": False, "external_view": False, "cockpit_started_at": old})[0] is True
    fresh = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    assert inject._cockpit_input_state(Path("/p"), fetch=lambda u: {
        "unlocked": False, "external_view": False, "cockpit_started_at": fresh})[0] is False
    assert inject._cockpit_input_state(Path("/p"), fetch=lambda u: {
        "unlocked": False, "external_view": True, "cockpit_started_at": old})[0] is False


def test_c2_finds_and_types_into_the_private_fw_agents_server(proj, monkeypatch):
    """bin/claude-fw puts a bare-terminal session on its own tmux server (-L fw-agents)."""
    _record(monkeypatch)
    r = Runner(panes=[("/dev/pts/3", "%1", "fleet-x")], private=[(TTY, "%2", "fw-proj-123")])
    target, why = inject.choose_target(False, r, input_state=_free)
    assert target["pane"] == "%2" and target["socket"] == "fw-agents", why
    monkeypatch.setattr(receiver, "awaiting_handover", lambda: ["m-2"])
    monkeypatch.setattr(receiver, "read_message", lambda m: {"urgent": False})
    monkeypatch.setattr(inject, "_inject_marker", lambda m: proj / f"{m}.injected")
    monkeypatch.setattr(receiver, "record_event", lambda *a, **k: None)
    rep = inject._deliver_locked("test", r)
    assert rep["injected"] == ["m-2"], rep
    assert r.typed[0][:6] == ["tmux", "-L", "fw-agents", "send-keys", "-t", "%2"]
