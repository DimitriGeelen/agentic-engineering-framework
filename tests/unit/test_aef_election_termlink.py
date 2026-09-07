"""T-3335 (arc-020 S8): live termlink wiring for the claim-backend seam.

Exercises TermlinkChannelClaimBackend against a stateful *fake* invoke that
models the termlink `channel` verb family observed on a real hub (T-3335
probe): claim is an offset-lease within a topic (won → JSON with claim_id;
contested → non-JSON "already claimed" error; an unposted offset cannot be
claimed — the slot must be seeded). No live hub required.

The live-hub leg (two real candidate_ids racing one target) is the task's
[REVIEW] Human AC + tests/manual/s8_claim_smoke.py — not here.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from lib.aef_election import (  # noqa: E402
    LOST,
    WON,
    ClaimBackend,
    ClaimTicket,
    TermlinkChannelClaimBackend,
    election_topic,
    elect,
)


# ── a stateful fake hub modelling the observed termlink channel semantics ──


class FakeHub:
    """Minimal in-memory model of the termlink `channel` verbs used by the
    backend. Tracks per-topic message count (frontier) and live claims by
    offset, so the win/lose/holder/release/seed paths are all reachable
    deterministically. Also records the raw arg-vectors for assertions."""

    def __init__(self):
        # topic -> {"count": int, "claims": {offset: {claimer, claim_id, claimed_until}}}
        self.topics: dict[str, dict] = {}
        self.seq = 0
        self.calls: list[list[str]] = []

    def _topic(self, name):
        return self.topics.setdefault(name, {"count": 0, "claims": {}})

    @staticmethod
    def _split(args):
        pos, opts, i = [], {}, 0
        a = [x for x in args if x != "--json"]
        while i < len(a):
            if a[i].startswith("--"):
                key = a[i][2:]
                if i + 1 < len(a) and not a[i + 1].startswith("--"):
                    opts[key] = a[i + 1]
                    i += 2
                else:
                    opts[key] = True
                    i += 1
            else:
                pos.append(a[i])
                i += 1
        return pos, opts

    def _ok(self, data):
        return {"ok": True, "code": 0, "data": data, "stdout": "json", "stderr": ""}

    def _err(self, msg):
        return {"ok": False, "code": 1, "data": {}, "stdout": "", "stderr": msg}

    def invoke(self, args, *, timeout=20.0):
        self.calls.append(list(args))
        pos, opts = self._split(args)
        # pos like ["channel", "<verb>", ...positionals]
        verb = pos[1] if len(pos) > 1 else ""

        if verb == "create":
            self._topic(pos[2])
            return self._ok({"created": True, "topic": pos[2]})

        if verb == "info":
            t = self._topic(pos[2])
            return self._ok({"count": t["count"], "topic": pos[2]})

        if verb == "post":
            t = self._topic(pos[2])
            offset = t["count"]
            t["count"] += 1
            return self._ok({"delivered": {"offset": offset}, "confirmed": False})

        if verb == "claim":
            topic, offset = pos[2], int(pos[3])
            t = self._topic(topic)
            if offset >= t["count"]:
                # matches hub code -32022: cannot claim at/beyond frontier
                return self._err(
                    f"channel.claim failed: offset {offset} is at/beyond the frontier"
                )
            if offset in t["claims"]:
                return self._err(
                    f"channel.claim failed: offset {offset} of topic "
                    f'"{topic}" is already claimed by another worker'
                )
            self.seq += 1
            claim_id = f"clm-fake-{self.seq}"
            row = {
                "claimer": opts["claimer"],
                "claim_id": claim_id,
                "claimed_until": 9_999_999_999_999,
                "offset": offset,
            }
            t["claims"][offset] = row
            return self._ok({"ok": True, **row, "topic": topic})

        if verb == "claims":
            t = self._topic(pos[2])
            rows = [dict(r) for r in t["claims"].values()]
            return self._ok({"claims": rows, "count": len(rows), "topic": pos[2]})

        if verb == "release":
            cid = opts.get("claim-id")
            for topic in self.topics.values():
                for off, row in list(topic["claims"].items()):
                    if row["claim_id"] == cid:
                        del topic["claims"][off]
                        return self._ok({"released": True})
            return self._err("channel.release failed: no such claim (already lapsed)")

        return self._err(f"fake hub: unhandled verb {verb!r}")


TARGET = "aef::host=h1.example::project=/opt/p::@peer::"


def _backend(hub):
    return TermlinkChannelClaimBackend("aef-elect-test", invoke=hub.invoke)


# ── protocol conformance ──────────────────────────────────────────────────


def test_backend_satisfies_claimbackend_protocol():
    hub = FakeHub()
    assert isinstance(_backend(hub), ClaimBackend)


def test_no_notimplemented_stub_remains():
    # The shape-only stub raised on every call; the live backend must not.
    hub = FakeHub()
    ticket = _backend(hub).try_claim(TARGET, "cand-A")
    assert ticket is not None
    assert isinstance(ticket, ClaimTicket)


# ── win / lose / holder ────────────────────────────────────────────────────


def test_first_claimant_wins():
    hub = FakeHub()
    b = _backend(hub)
    ticket = b.try_claim(TARGET, "cand-A")
    assert ticket is not None
    assert ticket.claimer == "cand-A"
    assert ticket.claim_id.startswith("clm-fake-")


def test_second_claimant_loses_returns_none():
    hub = FakeHub()
    b = _backend(hub)
    assert b.try_claim(TARGET, "cand-A") is not None
    assert b.try_claim(TARGET, "cand-B") is None  # LOST, not an exception


def test_holder_names_the_winner():
    hub = FakeHub()
    b = _backend(hub)
    b.try_claim(TARGET, "cand-A")
    held = b.holder(TARGET)
    assert held is not None
    assert held["holder"] == "cand-A"
    assert held["offset"] == 0


def test_holder_none_when_unclaimed():
    hub = FakeHub()
    # holder() must be a free read — it may seed nothing and find nothing.
    assert _backend(hub).holder(TARGET) is None


# ── release / idempotency ──────────────────────────────────────────────────


def test_release_reopens_the_slot():
    hub = FakeHub()
    b = _backend(hub)
    ticket = b.try_claim(TARGET, "cand-A")
    assert b.try_claim(TARGET, "cand-B") is None  # contested
    ticket.release()
    # slot reopened → a later candidate now wins
    assert b.try_claim(TARGET, "cand-B") is not None


def test_release_is_idempotent():
    hub = FakeHub()
    ticket = _backend(hub).try_claim(TARGET, "cand-A")
    ticket.release()
    ticket.release()  # must not raise
    assert ticket.released is True


# ── seeding: the offset-cannot-be-claimed-at-frontier reality ──────────────


def test_slot_is_seeded_exactly_once_across_claims():
    hub = FakeHub()
    b = _backend(hub)
    b.try_claim(TARGET, "cand-A")
    b.try_claim(TARGET, "cand-B")
    posts = [c for c in hub.calls if len(c) > 1 and c[1] == "post"]
    assert len(posts) == 1  # sentinel posted once, not per-claim


def test_topic_is_stable_and_namespaced():
    topic = election_topic("aef-elect-test", TARGET)
    assert topic == election_topic("aef-elect-test", TARGET)  # deterministic
    assert topic.startswith("aef-elect-test-")


# ── integration through elect() ────────────────────────────────────────────


def test_elect_win_then_loss_through_the_public_verb():
    hub = FakeHub()
    b = _backend(hub)
    won = elect(TARGET, "cand-A", b)
    lost = elect(TARGET, "cand-B", b)
    assert won.role == WON
    assert won.won is True
    assert lost.role == LOST
    assert lost.holder is not None
    assert lost.holder["holder"] == "cand-A"
    # winner releases → target returns to electable
    won.release()
    again = elect(TARGET, "cand-B", b)
    assert again.role == WON


def test_idempotent_reclaim_by_same_candidate():
    # If the same candidate re-claims a slot it already holds, it gets a
    # ticket back (renew race), not None.
    hub = FakeHub()
    b = _backend(hub)
    t1 = b.try_claim(TARGET, "cand-A")
    assert t1 is not None
    t2 = b.try_claim(TARGET, "cand-A")
    assert t2 is not None
    assert t2.claimer == "cand-A"


if __name__ == "__main__":  # pragma: no cover
    sys.exit(pytest.main([__file__, "-q"]))
