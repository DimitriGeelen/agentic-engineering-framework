"""T-4802 — the §6.2 store mechanics of lib/dispatch_records.py, tested directly.

The conformance vectors (tests/conformance/worker-contract/run_local.py) judge the transition
table; these tests pin the storage contract underneath it: CAS on the prior state, the lock
timeout failing closed, crash atomicity of the write, and concurrent writers serialising.
Clocks are injected; nothing sleeps for real beyond lock polling between threads.
"""
import fcntl
import json
import os
import subprocess
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
def ft():
    return FakeTime()


@pytest.fixture
def store(tmp_path, ft):
    return dr.Store(tmp_path / "records", signing_key=KEY, clock=ft.clock, monotonic=ft.monotonic,
                    sleep=ft.sleep)


def _running(store):
    res = store.create(dispatcher={"session": "claude-master-1"})
    did, nonce, tok = res["values"]["dispatch_id"], res["values"]["nonce"], res["values"]["supervisor_token"]
    assert store.start(did, 1, nonce=nonce, credential=tok)["accepted"] == "T2"
    return did, nonce, tok


def _evidence(did, nonce, attempt=1, exit_code=0, status="complete", key=KEY, **hb):
    handback = {"commission": did, "attempt": attempt, "nonce": nonce, "status": status, **hb}
    body = {"dispatch_id": did, "attempt": attempt, "nonce": nonce, "exit_code": exit_code,
            "handback": handback, "persisted_at": 90}
    return dr.sign_completion(body, key)


def test_record_shape_and_secrets_stored_hashed(store):
    did, nonce, tok = _running(store)
    assert dr.DISPATCH_ID_RE.match(did)
    raw = (store.root / f"{did}.json").read_text()
    rec = json.loads(raw)
    assert rec["contract_version"] == "wc/0.3" and rec["backend"] == "local"
    assert rec["attempts"][0]["session_binding"]["worker_binding"] == f"{did}:1"
    assert nonce not in raw and tok not in raw          # only sha256 of nonce and token on disk
    assert [e["to"] for e in rec["attempts"][0]["history"]] == ["dispatched", "running"]


def test_cas_refuses_stale_prior_state(store):
    did, nonce, tok = _running(store)
    before = (store.root / f"{did}.json").read_bytes()
    # T2 again: expected prior `dispatched`, actual `running`
    assert store.start(did, 1, nonce=nonce, credential=tok) == {"fence_reject": "cas_mismatch", "notices": 0}
    # T1 while attempt 1 is not terminal (§4.3)
    assert store.allocate(did)["fence_reject"] == "cas_mismatch"
    rec = store.load(did)
    assert rec["attempts"][0]["state"] == "running" and len(rec["attempts"]) == 1
    assert [f["reason"] for f in rec["fence_log"]] == ["cas_mismatch", "cas_mismatch"]
    assert json.loads(before)["attempts"] == rec["attempts"]   # rejects change no attempt


def test_forbidden_rows_and_fences(store):
    did, nonce, tok = _running(store)
    assert store.complete(did, 1, nonce="wrong", credential=tok, evidence=_evidence(did, nonce))["fence_reject"] == "bad_nonce"
    assert store.complete(did, 1, nonce=nonce, credential="wrong", evidence=_evidence(did, nonce))["fence_reject"] == "bad_credential"
    assert store.complete(did, 1, nonce=nonce, credential=tok, writer="worker",
                          evidence=_evidence(did, nonce))["fence_reject"] == "bad_credential"
    unsigned = _evidence(did, nonce, key=b"x" * 32)
    assert store.complete(did, 1, nonce=nonce, credential=tok, evidence=unsigned)["fence_reject"] == "forbidden_transition"
    assert store.complete(did, 1, nonce=nonce, credential=tok, evidence=_evidence(did, nonce))["accepted"] == "T3"
    assert store.confirm_end(did, 1)["fence_reject"] == "forbidden_transition"   # done -> lost
    assert store.complete(did, 1, nonce=nonce, credential=tok, evidence=_evidence(did, nonce))["response"] == "T8"
    assert store.complete(did, 1, nonce=nonce, credential=tok,
                          evidence=_evidence(did, nonce, exit_code=1))["fence_reject"] == "done_conflict"


def test_outcome_derivation_order():
    did, nonce = "D-01JAAAAAAAAAAAAAAAAAAAAA99", "n"
    h = dr._sha256(nonce)
    ok = _evidence(did, nonce)
    assert dr.derive_outcome(ok, did, 1, h) == "succeeded"
    assert dr.derive_outcome({**ok, "handback": None, "supervisor_refused": True}, did, 1, h) == "refused"
    assert dr.derive_outcome({**ok, "handback": None}, did, 1, h) == "handback-malformed"
    assert dr.derive_outcome({**ok, "handback": {**ok["handback"], "commission": "D-other"}}, did, 1, h) == "handback-malformed"
    assert dr.derive_outcome({**ok, "exit_code": 2}, did, 1, h) == "failed"
    assert dr.derive_outcome(_evidence(did, nonce, status="paused"), did, 1, h) == "paused"
    assert dr.derive_outcome(_evidence(did, nonce, status="paused", exit_code=1), did, 1, h) == "failed"


def test_lock_timeout_fails_closed(store, ft):
    did, nonce, tok = _running(store)
    before = (store.root / f"{did}.json").read_bytes()
    fd = os.open(store.root / f"{did}.lock", os.O_RDWR)
    fcntl.flock(fd, fcntl.LOCK_EX)
    try:
        res = store.complete(did, 1, nonce=nonce, credential=tok, evidence=_evidence(did, nonce))
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)
    assert res == {"fence_reject": "cas_mismatch", "notices": 0}
    assert ft.mono >= store.params["lock_timeout"]        # it waited the injected 10 s, not more
    assert (store.root / f"{did}.json").read_bytes() == before


def test_crash_mid_write_leaves_old_record(store, monkeypatch):
    did, nonce, tok = _running(store)
    path = store.root / f"{did}.json"
    before = path.read_bytes()

    def crash(src, dst):
        raise OSError("simulated crash before rename")
    monkeypatch.setattr(dr.os, "replace", crash)
    with pytest.raises(OSError):
        store.complete(did, 1, nonce=nonce, credential=tok, evidence=_evidence(did, nonce))
    monkeypatch.undo()
    assert path.read_bytes() == before                    # temp file was never renamed over it
    assert store.load(did)["attempts"][0]["state"] == "running"
    assert store.dispatch_ids() == [did]                  # a stray temp file is not a record
    # the lock was released: the next write succeeds
    assert store.complete(did, 1, nonce=nonce, credential=tok, evidence=_evidence(did, nonce))["accepted"] == "T3"


def test_concurrent_writers_serialise(tmp_path):
    root = tmp_path / "records"
    s = dr.Store(root, signing_key=KEY)
    did, nonce, tok = _running(s)
    results = []
    barrier = threading.Barrier(8)

    def go():
        barrier.wait()
        results.append(dr.Store(root, signing_key=KEY).complete(
            did, 1, nonce=nonce, credential=tok, evidence=_evidence(did, nonce)))
    threads = [threading.Thread(target=go) for _ in range(8)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert sum(r.get("accepted") == "T3" for r in results) == 1
    assert all(r.get("accepted") == "T3" or r.get("response") == "T8" for r in results)
    assert [e["to"] for e in s.load(did)["attempts"][0]["history"]] == ["dispatched", "running", "done"]


def test_concurrent_allocations_across_processes(tmp_path):
    """Two processes allocating attempt 2 at once: exactly one T1, the other cas_mismatch (§4.1)."""
    root = tmp_path / "records"
    s = dr.Store(root, signing_key=KEY)
    did, nonce, tok = _running(s)
    assert s.confirm_end(did, 1)["accepted"] == "T4"
    code = ("import sys,json; sys.path.insert(0, sys.argv[1]); from lib import dispatch_records as dr;"
            "print(json.dumps(dr.Store(sys.argv[2]).allocate(sys.argv[3])))")
    procs = [subprocess.Popen([sys.executable, "-c", code, str(_HERE), str(root), did],
                              stdout=subprocess.PIPE, text=True) for _ in range(4)]
    outs = [json.loads(p.communicate(timeout=60)[0]) for p in procs]
    assert sum(o.get("accepted") == "T1" for o in outs) == 1
    assert all(o.get("accepted") == "T1" or o.get("fence_reject") == "cas_mismatch" for o in outs)
    assert len(s.load(did)["attempts"]) == 2


def test_probe_lost_after_grace_and_deadline_unknown(store, ft):
    did, nonce, tok = _running(store)
    assert store.observe(did, 1, "absent").get("no_transition")    # inside G: evidence may still win
    ft.now += store.params["G"]
    assert store.tick()["accepted"] == "T4"
    did2, n2, t2 = _running(store)
    store.observe(did2, 1, "undecided")
    ft.now += store.params["deadline_running"] + 1
    res = store.tick()
    assert res["accepted"] == "T6" and res["notices"] == 1       # undecidable -> unknown, never lost
    assert store.observe(did2, 1, "alive")["accepted"] == "T7a"


def test_caller_chosen_ids(store):
    did = "D-01JAAAAAAAAAAAAAAAAAAAAA42"
    assert store.create(dispatch_id=did)["values"]["dispatch_id"] == did
    assert store.create(dispatch_id=did)["error"] == "id_taken"
    assert store.create(dispatch_id="D-bad")["error"] == "malformed_id"
    assert dr.DISPATCH_ID_RE.match(dr.new_dispatch_id())
