"""T-5157 (010 msg aece8b4f): `fw sidecar inbox --mark-read TOPIC`.

A topic first read through a new SIDECAR_INBOX_ALIASES name (T-5148) starts at cursor 0, so
a backlog already handled elsewhere would surface again. mark_read moves this project's
cursor past the topic's latest offset without draining, printing or receipting anything.
"""
import json
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.sidecar import addressing, circuit, inbox  # noqa: E402


@pytest.fixture()
def project(tmp_path, monkeypatch):
    root = tmp_path / "010-termlink"
    root.mkdir()
    monkeypatch.setenv("PROJECT_ROOT", str(root))
    monkeypatch.setenv("FRAMEWORK_ROOT", str(root))
    from lib.sidecar import outbox
    monkeypatch.setattr(outbox, "_root", lambda: root)
    monkeypatch.setattr(circuit, "hub_id", lambda: "h0")
    return root


def _hub(monkeypatch, rows):
    calls = []

    def fake(hub_id, hub, runner=None):
        calls.append(hub_id)
        return rows
    monkeypatch.setattr(addressing, "hub_inbox_topics", fake)
    return calls


def _state(root):
    return json.loads((root / ".context" / "sidecar" / "inbox-state.json").read_text())


def test_bare_name_expands_and_cursor_moves_past_latest(project, monkeypatch):
    calls = _hub(monkeypatch, [{"name": "inbox:h0/termlink", "latest_offset": 53, "count": 54}])
    r = inbox.mark_read("termlink")
    assert calls == ["h0"]
    assert r == {"topic": "inbox:h0/termlink", "before": 0, "cursor": 54, "latest_offset": 53}
    assert _state(project)["topics"]["inbox:h0/termlink"]["cursor"] == 54


def test_full_topic_name_accepted(project, monkeypatch):
    _hub(monkeypatch, [{"name": "inbox:h0/termlink", "latest_offset": 9}])
    assert inbox.mark_read("inbox:h0/termlink")["cursor"] == 10


def test_never_moves_backwards(project, monkeypatch):
    _hub(monkeypatch, [{"name": "inbox:h0/termlink", "latest_offset": 9}])
    state = inbox.load_state()
    state["topics"]["inbox:h0/termlink"] = {"cursor": 40}
    inbox.save_state(state)
    r = inbox.mark_read("termlink")
    assert r["cursor"] == 40 and r["before"] == 40


def test_unknown_topic_changes_nothing(project, monkeypatch):
    _hub(monkeypatch, [{"name": "inbox:h0/other", "latest_offset": 3}])
    with pytest.raises(inbox.MarkReadError):
        inbox.mark_read("termlink")
    assert not (project / ".context" / "sidecar" / "inbox-state.json").exists() \
        or "inbox:h0/termlink" not in _state(project)["topics"]


def test_hub_unreachable_changes_nothing(project, monkeypatch):
    _hub(monkeypatch, None)
    with pytest.raises(inbox.MarkReadError):
        inbox.mark_read("termlink")


def test_slash_in_bare_name_refused(project, monkeypatch):
    _hub(monkeypatch, [])
    with pytest.raises(inbox.MarkReadError):
        inbox.mark_read("a/b")


def test_cli_sends_no_receipts_and_prints_no_bodies(project, monkeypatch, capsys):
    from lib import sidecar_cli
    _hub(monkeypatch, [{"name": "inbox:h0/termlink", "latest_offset": 53}])
    sent = []
    monkeypatch.setattr(sidecar_cli.receipts, "send", lambda *a, **k: sent.append(a))
    monkeypatch.setattr(inbox, "pending", lambda **k: pytest.fail("mark-read must not drain"))
    rc = sidecar_cli.cmd_inbox(SimpleNamespace(show=None, mark_read="termlink", json=False, peek=False))
    out = capsys.readouterr().out
    assert rc == 0 and sent == []
    assert "cursor 0 -> 54" in out


def test_cli_failure_exits_nonzero(project, monkeypatch, capsys):
    from lib import sidecar_cli
    _hub(monkeypatch, None)
    rc = sidecar_cli.cmd_inbox(SimpleNamespace(show=None, mark_read="termlink", json=False, peek=False))
    assert rc == 1 and "NOT CHANGED" in capsys.readouterr().err
