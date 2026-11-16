"""T-5170 (010-termlink msg 290aad95): a refused bare-name send names the closest real address,
also when the name is a typo of a peer's nickname or of a declared inbox alias."""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.sidecar import addressing as a  # noqa: E402
from lib.sidecar import circuit, inbox  # noqa: E402

PEERS = ["010-termlink", "1409-sprind", "832-Workflow-designer", "ring20-dashboard"]


@pytest.fixture()
def peers(monkeypatch):
    monkeypatch.setattr(a, "load_peers", lambda: {"peers": PEERS})
    monkeypatch.setattr(inbox, "alias_topics", lambda agent=None: [])
    monkeypatch.setattr(circuit, "project_id", lambda: "999-Agentic-Engineering-Framework")
    return monkeypatch


def test_typo_of_a_nickname_names_the_peer(peers):
    assert a._close_peers_hint("termlnk") == ". Closest peers: 010-termlink"


def test_typo_of_a_full_id_still_works(peers):
    assert "1409-sprind" in a._close_peers_hint("1409-sprnd")


def test_nothing_close_no_hint(peers):
    assert a._close_peers_hint("zzqqxx") == ""


def test_declared_alias_typo_names_this_project(peers):
    peers.setattr(inbox, "alias_topics", lambda agent=None: ["inbox:h0/fwcore"])
    assert a._close_peers_hint("fwcor") == ". Closest peers: 999-Agentic-Engineering-Framework"


def test_each_address_once_and_never_a_nickname(peers):
    # "termlink" matches both the nickname and (more weakly) nothing else: one address, the real one
    hint = a._close_peers_hint("termlink")
    assert hint.count("010-termlink") == 1
    assert "termlink," not in hint and not hint.endswith(" termlink")


def test_alias_lookup_failure_does_not_break_the_hint(peers):
    def boom(agent=None):
        raise RuntimeError("config unreadable")
    peers.setattr(inbox, "alias_topics", boom)
    assert a._close_peers_hint("termlnk") == ". Closest peers: 010-termlink"
