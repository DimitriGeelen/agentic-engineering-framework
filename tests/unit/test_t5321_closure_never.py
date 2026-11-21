"""T-5321 — lib/dispatch_records.py as a `closure: never` backend (wc v0.3.4 item 2, A3).

(a) a close is answered with the typed refusal `closure_not_supported`: nothing changes, nothing
is appended, a later T1 is still accepted; (b) the client rule: a `fence_reject` reason the
client does not know is a non-retryable typed refusal naming the reason, never an exception.
"""
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(_HERE / "tests" / "conformance" / "worker-contract"))

from lib import dispatch_records as dr  # noqa: E402

KEY = b"k" * 32


@pytest.fixture
def store(tmp_path):
    return dr.Store(tmp_path / "records", signing_key=KEY, clock=lambda: 100)


def test_backend_declares_closure_never(store):
    assert dr.CLOSURE == "never"
    assert store.closure == "never"
    assert dr.conformance_adapter().closure == "never"


def test_close_is_typed_refusal_and_changes_nothing(store, tmp_path):
    v = store.create(dispatcher={"session": "s"})["values"]
    did = v["dispatch_id"]
    before = store.load(did)
    files_before = sorted((tmp_path / "records").iterdir())
    res = store.close(did, 1, credential=v["supervisor_token"], reason="r", writer="supervisor")
    assert res == {"refused": "closure_not_supported", "notices": 0}
    assert not res.get("ok") and "accepted" not in res and "fence_reject" not in res
    assert store.load(did) == before
    assert store.load(did).get("closed") is None
    assert "dispatch_history" not in store.load(did)
    assert sorted((tmp_path / "records").iterdir()) == files_before


def test_close_of_unknown_dispatch_is_still_the_typed_refusal(store):
    assert store.close("D-01JAAAAAAAAAAAAAAAAAAAAAZZ")["refused"] == "closure_not_supported"


def test_allocate_after_refused_close_succeeds(store):
    v = store.create(dispatcher={"session": "s"})["values"]
    did = v["dispatch_id"]
    store.close(did, 1, credential=v["supervisor_token"], reason="r")
    # finish A1 by withdrawal so T1 has a terminal predecessor
    w = store.withdraw(did, 1, reason="r", actor="a", nonce=v["nonce"], credential=v["supervisor_token"],
                       supervisor_gen=1, writer="submitter")
    assert w.get("accepted") == "T3w", w
    assert store.allocate(did).get("accepted") == "T1"


@pytest.mark.parametrize("reason", ["a_reason_from_a_later_revision", "", None, 42])
def test_unknown_fence_reason_is_non_retryable_typed_refusal(reason):
    out = dr.classify_fence_reject(reason)
    assert out["ok"] is True
    assert out["values"]["retryable"] is False
    assert out["values"]["known"] is False
    assert out["values"]["typed_refusal"]
    if isinstance(reason, str) and reason:
        assert out["values"]["typed_refusal"] == reason


def test_known_fence_reason_and_result_mapping():
    out = dr.classify_fence_reject({"fence_reject": "stale_attempt", "notices": 0})
    assert out["values"] == {"typed_refusal": "stale_attempt", "retryable": False, "known": True}


def test_cc35_passes_on_local_run():
    import run_local
    import yaml
    doc = yaml.safe_load((_HERE / "tests/conformance/worker-contract/vectors.yaml").read_text())
    vec = next(v for v in doc["vectors"] if v["id"] == "CC-35")
    adapter, reason = run_local.load_backend(None)
    r = run_local.run_vector(vec, adapter, reason)
    assert r["status"] == "pass", r
    assert "CC-35" not in run_local.LOCAL_PENDING
