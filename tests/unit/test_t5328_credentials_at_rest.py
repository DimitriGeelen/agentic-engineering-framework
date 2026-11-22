"""T-5328 (risk R-NEW-5, T-5300 matrix risk 1): attempt credentials at rest in the local backend.

The attempt nonce plus the supervisor_token authorise a withdrawal (T3w). The local store must keep
only their sha256, and its record and lock files must not be readable beyond the owning uid
(docs/specs/shared-worker-contract-transitions.md §6.5a). These tests go through the real Store.
"""
import stat
import sys
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


def _no_group_or_other(path: Path) -> bool:
    return stat.S_IMODE(path.stat().st_mode) & 0o077 == 0


def test_record_holds_hashes_never_plain_values(store):
    v = store.create(dispatcher={"session": "claude-master-1"})["values"]
    did, nonce, tok = v["dispatch_id"], v["nonce"], v["supervisor_token"]
    text = (store.root / f"{did}.json").read_text()
    assert nonce not in text and tok not in text
    att = store.load(did)["attempts"][0]
    assert att["nonce_sha256"] == dr._sha256(nonce) and att["token_sha256"] == dr._sha256(tok)


def test_record_and_lock_are_owner_only_including_after_a_write(store):
    v = store.create(dispatcher={"session": "claude-master-1"})["values"]
    did, nonce, tok = v["dispatch_id"], v["nonce"], v["supervisor_token"]
    rec, lock = store.root / f"{did}.json", store.root / f"{did}.lock"
    assert rec.exists() and lock.exists()
    assert _no_group_or_other(rec), oct(rec.stat().st_mode)
    assert _no_group_or_other(lock), oct(lock.stat().st_mode)
    # a further lifecycle write (withdrawal) rewrites the record: still owner-only, still hash-only
    res = store.withdraw(did, 1, reason="r", actor="a", nonce=nonce, credential=tok,
                         supervisor_gen=1, writer="submitter")
    assert res.get("accepted") == "T3w"
    assert _no_group_or_other(rec), oct(rec.stat().st_mode)
    text = rec.read_text()
    assert nonce not in text and tok not in text


def test_second_attempt_credentials_also_hash_only(store):
    v = store.create(dispatcher={"session": "claude-master-1"})["values"]
    did, nonce, tok = v["dispatch_id"], v["nonce"], v["supervisor_token"]
    store.withdraw(did, 1, reason="r", actor="a", nonce=nonce, credential=tok, supervisor_gen=1,
                   writer="submitter")
    a2 = store.allocate(did)["values"]
    text = (store.root / f"{did}.json").read_text()
    assert a2["nonce"] not in text and a2["supervisor_token"] not in text
