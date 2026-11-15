"""T-5148 (010 T-3798): a project declares inbox aliases; every inbox reader follows.

54 consults sat in inbox:<hub>/termlink, sent `--to termlink`, while 010-termlink read only
inbox:<hub>/010-termlink. SIDECAR_INBOX_ALIASES adds read-only topics through read_topics(),
the one definition every reader uses (T-3462).
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.sidecar import circuit, identity, inbox  # noqa: E402


@pytest.fixture()
def project(monkeypatch):
    monkeypatch.setattr(circuit, "hub_id", lambda: "h0")
    monkeypatch.setattr(circuit, "project_id", lambda: "010-termlink")
    real = circuit.circuit_id

    def cid(level="agent", **kw):
        return "h0/010-termlink" if level in ("agent", "project") else real(level, **kw)
    monkeypatch.setattr(circuit, "circuit_id", cid)
    return monkeypatch


def _aliases(monkeypatch, value):
    monkeypatch.setattr(identity, "_config", lambda key, default="", environ=None:
                        value if key == "SIDECAR_INBOX_ALIASES" else default)


def test_aliases_are_read(project):
    _aliases(project, "termlink, tl")
    topics = inbox.read_topics()
    assert "inbox:h0/termlink" in topics and "inbox:h0/tl" in topics
    assert topics[0] == inbox.inbox_topic()            # own topic still first


def test_no_alias_no_change(project):
    _aliases(project, "")
    assert inbox.alias_topics() == []


def test_invalid_names_and_own_id_are_ignored(project):
    _aliases(project, "a/b,  010-termlink ,,termlink")
    assert inbox.alias_topics() == ["inbox:h0/termlink"]


def test_another_agents_read_is_not_widened(project):
    _aliases(project, "termlink")
    assert inbox.alias_topics("some-other-agent") == []


def test_a_sub_agent_session_is_not_widened(project, monkeypatch):
    _aliases(project, "termlink")
    monkeypatch.setattr(circuit, "circuit_id",
                        lambda level="agent", **kw: "h0/010-termlink/s1/worker" if level == "agent"
                        else "h0/010-termlink")
    assert inbox.alias_topics() == []


def test_the_key_is_registered():
    root = Path(__file__).resolve().parents[2]
    assert '"SIDECAR_INBOX_ALIASES||' in (root / "lib" / "config.sh").read_text()
