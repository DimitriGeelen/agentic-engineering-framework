"""T-5150 (010 T-3798): a bare `--to` that is a nickname of a known peer is refused, naming
the peer, before the hub's "inbox was fetched" evidence is consulted.

54 consults sat in inbox:<hub>/termlink, sent `--to termlink`, read by nobody: a peek by any
scanner counts as a fetch (T-5149), so the T-4529 "read project inbox" route could pass.
"""
import importlib
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

PEERS = {"010-termlink": {"circuit": "h0/010-termlink", "hub_id": "h0"},
         "ring20-dashboard": {"circuit": "h0/ring20-dashboard", "hub_id": "h0"},
         "proxmox-ring20-management": {"circuit": "h1/proxmox-ring20-management", "hub_id": "h1"}}


@pytest.fixture()
def addr(monkeypatch):
    import lib.sidecar.addressing as a
    importlib.reload(a)
    monkeypatch.setattr(a, "load_peers", lambda: {"peers": PEERS})
    monkeypatch.setattr(a, "own_hub_id", lambda: "h0")
    monkeypatch.setattr(a, "_subagent_evidence", lambda name, runner: None)
    a._inbox_calls = []   # T-5427: the weak hub-fetch route is gone; kept so asserts read the same
    return a


def test_nickname_of_a_peer_is_refused_naming_it(addr):
    with pytest.raises(addr.AddressError) as e:
        addr.resolve("termlink")
    assert "did you mean 010-termlink" in str(e.value)
    assert addr._inbox_calls == []


def test_a_part_matching_two_peers_names_both(addr):
    with pytest.raises(addr.AddressError) as e:
        addr.resolve("ring20")
    assert "proxmox-ring20-management" in str(e.value) and "ring20-dashboard" in str(e.value)


def test_a_known_peer_still_resolves(addr):
    got = addr.resolve("ring20-dashboard")
    assert got["circuit"] == "h0/ring20-dashboard"


def test_a_name_with_no_candidate_needs_level_project(addr):
    """T-5427: the T-4529 hub-fetch route is gone; an unnumbered project is a deliberate choice."""
    with pytest.raises(addr.AddressError) as e:
        addr.resolve("someproject")
    assert "--level project" in str(e.value)
    assert addr.resolve("someproject", level="project")["circuit"] == "h0/someproject"


def test_a_sibling_checkout_named_like_the_nickname_is_still_refused(addr, monkeypatch):
    """010's checkout on this host is /opt/termlink: is_project_id said yes to `termlink`."""
    monkeypatch.setattr(addr.circuit, "is_project_id", lambda name: True)
    with pytest.raises(addr.AddressError) as e:
        addr.resolve("termlink")
    assert "did you mean 010-termlink" in str(e.value)


def test_a_numbered_project_id_keeps_its_meaning(addr):
    got = addr.resolve("055-agentic-fleet-cockpit")
    assert got["circuit"] == "h0/055-agentic-fleet-cockpit"


def test_the_general_refusal_names_close_peers(addr, monkeypatch):
    with pytest.raises(addr.AddressError) as e:
        addr.resolve("ring20-dashbord", level="auto")
    assert "Closest peers: ring20-dashboard" in str(e.value)
