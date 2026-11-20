"""T-5312 — T3w (dispatched -> done{withdrawn}) in lib/dispatch_records.py, wc v0.3.4.

Covers CC-26..CC-29 as docs/specs/shared-worker-contract-transitions.md §9 words them, the
T2/T3w race through the CAS under real threads, and the two further v0.3.4 cases: a
different-reason withdrawal of a withdrawn attempt (forbidden_transition) and a later real
completion of a withdrawn attempt (done_conflict).
"""
import hashlib
import sys
import threading
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from lib import dispatch_records as dr  # noqa: E402

KEY = b"k" * 32


class FakeTime:
    def __init__(self):
        self.now = 100
        self.mono = 0.0

    def clock(self):
        return self.now

    def monotonic(self):
        return self.mono

    def sleep(self, dt):
        self.mono += dt


@pytest.fixture
def store(tmp_path):
    ft = FakeTime()
    return dr.Store(tmp_path / "records", signing_key=KEY, clock=ft.clock, monotonic=ft.monotonic,
                    sleep=ft.sleep)


def _dispatched(store):
    v = store.create(dispatcher={"session": "claude-master-1"})["values"]
    return v["dispatch_id"], v["nonce"], v["supervisor_token"]


def _withdraw(store, did, nonce, tok, reason="r", actor="a", gen: "int | None" = 1, writer="submitter", attempt=1):
    return store.withdraw(did, attempt, reason=reason, actor=actor, nonce=nonce, credential=tok,
                          supervisor_gen=gen, writer=writer)


def _evidence(did, nonce, attempt=1):
    hb = {"commission": did, "attempt": attempt, "nonce": nonce, "status": "complete"}
    return dr.sign_completion({"dispatch_id": did, "attempt": attempt, "nonce": nonce, "exit_code": 0,
                               "handback": hb, "persisted_at": 100}, KEY)


def _att(store, did, n=1):
    return store.load(did)["attempts"][n - 1]


# ── CC-26 ──────────────────────────────────────────────────────────────
def test_cc26_withdraw_from_dispatched(store):
    did, nonce, tok = _dispatched(store)
    assert store.append_question(did, 1, nonce=nonce, question_id="q1", body="?")["ok"]
    res = _withdraw(store, did, nonce, tok)
    assert res["accepted"] == "T3w" and res["notices"] == 0
    att = _att(store, did)
    assert att["state"] == "done" and att["outcome"] == "withdrawn"
    assert att["evidence_digest"] == hashlib.sha256("r".encode("utf-8")).hexdigest()
    assert att["result"]["kind"] == "none" and att["result"]["value"] is None
    assert att["exit_code"] is None and att["handback"] is None and att["attested"] is False
    last = att["history"][-1]
    assert (last["from"], last["to"], last["transition"]) == ("dispatched", "done", "T3w")
    assert last["actor"] == "a" and last["reason"] == "r"
    assert store.load(did)["notices"] == []                       # no operator notice
    assert all(q.get("closed_at") is not None for q in att["questions"])   # question closed


def test_cc26_without_credential_is_bad_credential(store):
    did, nonce, _ = _dispatched(store)
    res = _withdraw(store, did, nonce, None)
    assert res["fence_reject"] == "bad_credential"
    assert _att(store, did)["state"] == "dispatched"


def test_cc26_sweep_writer_refused(store):
    did, nonce, tok = _dispatched(store)
    res = _withdraw(store, did, nonce, tok, writer="hub")
    assert "fence_reject" in res
    assert _att(store, did)["state"] == "dispatched"


def test_cc26_bad_nonce_and_stale_gen_refused(store):
    did, nonce, tok = _dispatched(store)
    assert _withdraw(store, did, "wrong", tok)["fence_reject"] == "bad_nonce"
    assert _withdraw(store, did, nonce, tok, gen=2)["fence_reject"] == "stale_gen"
    assert _withdraw(store, did, nonce, tok, gen=None)["fence_reject"] == "stale_gen"
    assert _att(store, did)["state"] == "dispatched"


def test_cc26_consumers_refuse_and_a2_may_follow(store):
    did, nonce, tok = _dispatched(store)
    _withdraw(store, did, nonce, tok)
    assert store.consume(did, 1, consumer="review")["refused"] == "not_finished_work"
    assert store.allocate(did)["accepted"] == "T1"
    assert _att(store, did, 2)["state"] == "dispatched"


def test_reader_rule_unknown_outcome_is_not_finished_work(store):
    did, nonce, tok = _dispatched(store)
    _withdraw(store, did, nonce, tok)
    rec = store.load(did)
    rec["attempts"][0]["outcome"] = "some-future-outcome"
    store._write(rec)
    assert store.consume(did, 1, consumer="pass-rate")["refused"] == "not_finished_work"


def test_operator_cannot_attest_withdrawn(store):
    did, nonce, tok = _dispatched(store)
    rec = store.load(did)
    rec["attempts"][0]["state"] = "unknown"
    store._write(rec)
    res = store.resolve(did, 1, as_="done", reason="x", actor="op", outcome="withdrawn")
    assert res == {"error": "bad_resolve"}


# ── CC-27 ──────────────────────────────────────────────────────────────
@pytest.mark.parametrize("rounds", [20])
def test_cc27_withdraw_races_start_exactly_one_wins(tmp_path, rounds):
    for i in range(rounds):
        store = dr.Store(tmp_path / f"r{i}", signing_key=KEY)
        did, nonce, tok = _dispatched(store)
        out = {}
        barrier = threading.Barrier(2)

        def t2():
            barrier.wait()
            out["t2"] = store.start(did, 1, nonce=nonce, credential=tok, supervisor_gen=1)

        def t3w():
            barrier.wait()
            out["t3w"] = _withdraw(store, did, nonce, tok)
        ths = [threading.Thread(target=t2), threading.Thread(target=t3w)]
        for t in ths:
            t.start()
        for t in ths:
            t.join()
        accepted = [k for k, v in out.items() if v.get("accepted")]
        assert len(accepted) == 1, out
        loser = "t3w" if accepted == ["t2"] else "t2"
        assert out[loser]["fence_reject"] == "cas_mismatch", out
        hist = [e["to"] for e in _att(store, did)["history"]]
        assert hist in (["dispatched", "done"], ["dispatched", "running"])


def test_cc27_sequential_orders(store):
    did, nonce, tok = _dispatched(store)
    _withdraw(store, did, nonce, tok)
    assert store.start(did, 1, nonce=nonce, credential=tok)["fence_reject"] == "cas_mismatch"
    assert _att(store, did)["outcome"] == "withdrawn"


# ── CC-28 ──────────────────────────────────────────────────────────────
def test_cc28_withdraw_from_running_is_cas_mismatch(store):
    did, nonce, tok = _dispatched(store)
    store.start(did, 1, nonce=nonce, credential=tok)
    before = _att(store, did)
    assert _withdraw(store, did, nonce, tok)["fence_reject"] == "cas_mismatch"
    after = _att(store, did)
    assert after["state"] == "running" and after["history"] == before["history"]


@pytest.mark.parametrize("state", ["lost", "unknown"])
def test_cc28_withdraw_from_lost_or_unknown_is_forbidden(store, state):
    did, nonce, tok = _dispatched(store)
    rec = store.load(did)
    rec["attempts"][0]["state"] = state
    store._write(rec)
    assert _withdraw(store, did, nonce, tok)["fence_reject"] == "forbidden_transition"
    assert _att(store, did)["state"] == state


def test_withdraw_from_other_done_is_forbidden(store):
    did, nonce, tok = _dispatched(store)
    store.start(did, 1, nonce=nonce, credential=tok)
    assert store.complete(did, 1, nonce=nonce, credential=tok, evidence=_evidence(did, nonce))["accepted"] == "T3"
    assert _withdraw(store, did, nonce, tok)["fence_reject"] == "forbidden_transition"
    assert _att(store, did)["outcome"] == "succeeded"


# ── CC-29 ──────────────────────────────────────────────────────────────
def test_cc29a_identical_repeat_is_t8(store):
    did, nonce, tok = _dispatched(store)
    _withdraw(store, did, nonce, tok)
    before = store.load(did)
    res = _withdraw(store, did, nonce, tok)
    assert res["response"] == "T8" and res["notices"] == 0
    assert store.load(did) == before                               # nothing appended


def test_cc29b_different_reason_is_forbidden(store):
    did, nonce, tok = _dispatched(store)
    _withdraw(store, did, nonce, tok)
    hist = _att(store, did)["history"]
    assert _withdraw(store, did, nonce, tok, reason="r2")["fence_reject"] == "forbidden_transition"
    att = _att(store, did)
    assert att["history"] == hist and att["evidence_digest"] == hashlib.sha256(b"r").hexdigest()


def test_cc29c_later_real_completion_is_done_conflict(store):
    did, nonce, tok = _dispatched(store)
    _withdraw(store, did, nonce, tok)
    hist = _att(store, did)["history"]
    res = store.complete(did, 1, nonce=nonce, credential=tok, evidence=_evidence(did, nonce))
    assert res["fence_reject"] == "done_conflict" and res["notices"] == 1
    att = _att(store, did)
    assert att["outcome"] == "withdrawn" and att["history"] == hist
    assert store.load(did)["notices"][-1]["kind"] == "done_conflict"


def test_t8_repeat_on_non_current_attempt(store):
    did, nonce, tok = _dispatched(store)
    _withdraw(store, did, nonce, tok)
    store.allocate(did)
    assert _withdraw(store, did, nonce, tok)["response"] == "T8"


def test_conformance_adapter_withdraw_op():
    ad = dr.conformance_adapter()
    ad.reset({"clock": 0})
    ad.apply({"op": "create", "args": {}, "expect": {"bind": {"nonce": "n1", "credential": "c1"}}})
    res = ad.apply({"op": "withdraw", "attempt": 1, "nonce": "n1", "credential": "c1",
                    "args": {"reason": "r", "actor": "a"}})
    assert res["accepted"] == "T3w"
    assert ad.snapshot()["attempts"]["A1"]["outcome"] == "withdrawn"
