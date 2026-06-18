"""T-2430 — pin the authority-broker evaluator + holder (arc-013, design §4e).

Covers:
  - resolve_rule: per-type override wins over global
  - evaluate: the §4e worked example (blast_radius 1 commits, 7 queues), hard
    floors (tier0/directive never delegable), delegable types, and each bound
    (blast_radius / voi / scope / tier)
  - Holder.handle: propose-within commits + writes state + audits; propose-over
    queues; commit requires sovereign principal; query reads state; audit is
    append-only
"""
import json
import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from lib import govd_envelope as E          # noqa: E402
from lib import govd_holder as H            # noqa: E402

ENVELOPE = {
    "global": {"max_blast_radius": 2, "min_voi_score": 0.5, "scope": "internal"},
    "overrides": {
        "inception_go": {"max_blast_radius": 2, "min_voi_score": 0.5},
        "dispatch_approve": {"max_blast_radius": 1, "max_tier": 1},
        "focus_change": {"delegable": True},
        "tier0_approve": {"delegable": False},
        "directive_author": {"delegable": False},
    },
}


# ── resolve_rule ────────────────────────────────────────────────────────────
def test_resolve_rule_override_wins_over_global():
    eff = E.resolve_rule(ENVELOPE, "dispatch_approve")
    assert eff["max_blast_radius"] == 1          # override, not the global 2
    assert eff["scope"] == "internal"            # inherited from global
    assert eff["max_tier"] == 1                   # override-only key


def test_resolve_rule_unknown_type_falls_back_to_global():
    eff = E.resolve_rule(ENVELOPE, "no_such_type")
    assert eff == ENVELOPE["global"]


# ── evaluate: the §4e worked example ────────────────────────────────────────
def test_worked_example_low_blast_commits_autonomously():
    v = E.evaluate(ENVELOPE, {"type": "inception_go", "blast_radius": 1, "voi_score": 0.85})
    assert v["commit"] == "agent"
    assert v["tier_log"] == 3


def test_worked_example_high_blast_queues_to_human():
    # T-2428 itself: blast_radius 7 → beyond the ceiling → human
    v = E.evaluate(ENVELOPE, {"type": "inception_go", "blast_radius": 7, "voi_score": 0.85})
    assert v["commit"] == "human"
    assert v["tier_log"] == 2
    assert "blast_radius 7" in v["reason"]


# ── evaluate: hard floors ───────────────────────────────────────────────────
def test_tier0_is_hard_floor_even_if_envelope_says_delegable():
    poisoned = {"global": {}, "overrides": {"tier0_approve": {"delegable": True}}}
    v = E.evaluate(poisoned, {"type": "tier0_approve"})
    assert v["commit"] == "human"                 # HARD_FLOOR_TYPES wins
    assert v["tier_log"] == 0


def test_directive_author_non_delegable():
    v = E.evaluate(ENVELOPE, {"type": "directive_author"})
    assert v["commit"] == "human"


def test_delegable_type_commits():
    v = E.evaluate(ENVELOPE, {"type": "focus_change"})
    assert v["commit"] == "agent"


# ── evaluate: each bound ────────────────────────────────────────────────────
def test_voi_breach_queues():
    v = E.evaluate(ENVELOPE, {"type": "inception_go", "blast_radius": 1, "voi_score": 0.2})
    assert v["commit"] == "human"
    assert "voi_score" in v["reason"]


def test_scope_breach_queues():
    v = E.evaluate(ENVELOPE, {"type": "inception_go", "blast_radius": 1, "scope": "external"})
    assert v["commit"] == "human"
    assert "scope" in v["reason"]


def test_tier_breach_queues():
    v = E.evaluate(ENVELOPE, {"type": "dispatch_approve", "blast_radius": 1, "tier": 2})
    assert v["commit"] == "human"
    assert "tier" in v["reason"]


def test_missing_type_routes_to_human():
    v = E.evaluate(ENVELOPE, {"blast_radius": 1})
    assert v["commit"] == "human"


# ── load_envelope fails closed ──────────────────────────────────────────────
def test_load_envelope_missing_raises(tmp_path):
    with pytest.raises(FileNotFoundError):
        E.load_envelope(tmp_path / "nope.yaml")


# ── Holder ──────────────────────────────────────────────────────────────────
@pytest.fixture
def holder(tmp_path):
    env_path = tmp_path / "env.yaml"
    import yaml
    env_path.write_text(yaml.safe_dump(ENVELOPE))
    return H.Holder(env_path, tmp_path / "audit.jsonl", tmp_path / "state.json", sovereign_uid=4242)


def test_holder_propose_within_commits_and_writes_state(holder):
    r = holder.handle({"op": "propose", "decision": {"type": "focus_change"},
                       "payload": {"task": "T-2430"}}, peer_uid=1000)
    assert r["ok"] and r["commit"] == "agent"
    assert holder.state.read()["focus"] == {"task": "T-2430"}


def test_holder_propose_over_queues_no_state_change(holder):
    r = holder.handle({"op": "propose",
                       "decision": {"type": "inception_go", "blast_radius": 7, "voi_score": 0.9}},
                      peer_uid=1000)
    assert r["ok"] and r["commit"] == "human"
    assert "last_inception_decision" not in holder.state.read()


def test_holder_commit_requires_sovereign(holder):
    denied = holder.handle({"op": "commit", "decision": {"type": "inception_go"}}, peer_uid=1000)
    assert denied["ok"] is False
    allowed = holder.handle({"op": "commit", "decision": {"type": "inception_go"},
                             "payload": {"go": True}}, peer_uid=4242)
    assert allowed["ok"] and allowed["commit"] == "sovereign"
    assert holder.state.read()["last_inception_decision"] == {"go": True}


def test_holder_query_returns_state(holder):
    holder.handle({"op": "propose", "decision": {"type": "focus_change"}, "payload": {"task": "T-x"}}, 1000)
    q = holder.handle({"op": "query"}, peer_uid=1000)
    assert q["state"]["focus"] == {"task": "T-x"}


def test_holder_socket_roundtrip_real_unix_socket(tmp_path):
    """Integration: drive the real UnixStreamServer over a live socket (not handle()
    directly) — proves the serve() path + SO_PEERCRED extraction work end to end."""
    import os
    import socket
    import threading
    import time

    import yaml
    env_path = tmp_path / "env.yaml"
    env_path.write_text(yaml.safe_dump(ENVELOPE))
    holder = H.Holder(env_path, tmp_path / "audit.jsonl", tmp_path / "state.json",
                      sovereign_uid=os.getuid())
    sock_path = str(tmp_path / "h.sock")
    t = threading.Thread(target=H.serve, args=(sock_path, holder), daemon=True)
    t.start()
    for _ in range(50):
        if os.path.exists(sock_path):
            break
        time.sleep(0.02)

    c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    c.connect(sock_path)
    c.sendall((json.dumps({"op": "propose", "decision": {"type": "focus_change"},
                           "payload": {"task": "T-2430"}}) + "\n").encode())
    resp = json.loads(c.recv(4096))
    c.close()
    assert resp["ok"] and resp["commit"] == "agent"
    assert holder.state.read()["focus"] == {"task": "T-2430"}


def test_audit_is_append_only(holder):
    holder.handle({"op": "propose", "decision": {"type": "focus_change"}, "payload": {}}, 1000)
    n1 = len(Path(holder.audit.path).read_text().splitlines())
    holder.handle({"op": "propose", "decision": {"type": "focus_change"}, "payload": {}}, 1000)
    n2 = len(Path(holder.audit.path).read_text().splitlines())
    assert n2 == n1 + 1                            # grew, never rewrote
    # every line is valid JSON with an audit_id
    for line in Path(holder.audit.path).read_text().splitlines():
        assert json.loads(line)["audit_id"].startswith("A-")
