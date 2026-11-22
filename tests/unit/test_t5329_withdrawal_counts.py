"""T-5329 (R-043) — withdrawals per submitter per UTC day from the local dispatch-records store.

Records are built through the real Store (lib/dispatch_records.py) with a fake clock; the
counter and its CLI (the line `fw audit` grades) are then read back. Hermetic: tmp_path only.
"""
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))

from lib import dispatch_records as dr  # noqa: E402

KEY = b"k" * 32
DAY1 = 1_795_000_000            # 2026-11-18 UTC
DAY2 = DAY1 + 86_400            # 2026-11-19 UTC
MODULE = _HERE / "lib" / "dispatch_records.py"
AUDIT = _HERE / "agents" / "audit" / "audit.sh"


class FakeTime:
    def __init__(self):
        self.now = DAY1
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
def root(tmp_path):
    return tmp_path / "dispatch-records"


@pytest.fixture
def store(root, ft):
    return dr.Store(root, signing_key=KEY, clock=ft.clock, monotonic=ft.monotonic, sleep=ft.sleep)


def _withdraw(store, session: "str | None" = "sess-a", actor="cleanup"):
    v = store.create(dispatcher={"session": session} if session else None)["values"]
    res = store.withdraw(v["dispatch_id"], 1, reason="not wanted", actor=actor, nonce=v["nonce"],
                         credential=v["supervisor_token"], supervisor_gen=1, writer="submitter")
    assert res["accepted"] == "T3w"
    return v["dispatch_id"]


def _complete(store, session="sess-a"):
    v = store.create(dispatcher={"session": session})["values"]
    did, nonce = v["dispatch_id"], v["nonce"]
    hb = {"commission": did, "attempt": 1, "nonce": nonce, "status": "complete"}
    ev = dr.sign_completion({"dispatch_id": did, "attempt": 1, "nonce": nonce, "exit_code": 0,
                             "handback": hb, "persisted_at": DAY1}, KEY)
    res = store.complete(did, 1, nonce=nonce, credential=v["supervisor_token"], evidence=ev)
    assert res.get("accepted"), res
    assert store.load(did)["attempts"][0]["outcome"] == "succeeded"
    return did


def _cli(root, threshold=5):
    p = subprocess.run([sys.executable, str(MODULE), "withdrawals", "--root", str(root),
                        "--threshold", str(threshold)], capture_output=True, text=True, timeout=60)
    return p.returncode, p.stdout


def _snapshot(root):
    return {p.name: p.read_bytes() for p in sorted(root.iterdir())} if root.exists() else None


def test_no_store_is_info_and_creates_nothing(root):
    assert dr.withdrawal_counts(root) is None
    rc, out = _cli(root)
    assert rc == 0 and out.startswith("INFO ") and "local backend not wired" in out
    assert not root.exists()


def test_under_threshold_is_pass_with_count(store, root):
    for _ in range(3):
        _withdraw(store)
    assert dr.withdrawal_counts(root) == {("sess-a", "2026-11-18"): 3}
    before = _snapshot(root)
    rc, out = _cli(root, threshold=5)
    assert rc == 0
    assert out.strip().splitlines()[-1] == "withdrawals: 3 in 1 submitter-day(s), 0 over 5/day"
    assert "OVER" not in out
    assert _snapshot(root) == before                 # read-only: no byte changed, no file added


def test_over_threshold_is_warn_naming_submitter_day_count(store, root):
    for _ in range(4):
        _withdraw(store, session="loop-x")
    _withdraw(store, session="calm-y")
    rc, out = _cli(root, threshold=3)
    assert rc == 1
    over = [ln for ln in out.splitlines() if ln.startswith("OVER")]
    assert over == ["OVER loop-x 2026-11-18 4"]


def test_non_withdrawn_done_is_not_counted(store, root):
    _complete(store)
    _complete(store)
    _withdraw(store)
    assert dr.withdrawal_counts(root) == {("sess-a", "2026-11-18"): 1}


def test_two_days_counted_per_day_and_actor_fallback(store, root, ft):
    _withdraw(store)
    _withdraw(store)
    ft.now = DAY2
    _withdraw(store)
    _withdraw(store, session=None, actor="batch-bot")
    assert dr.withdrawal_counts(root) == {
        ("sess-a", "2026-11-18"): 2,
        ("sess-a", "2026-11-19"): 1,
        ("batch-bot", "2026-11-19"): 1,
    }
    rc, _ = _cli(root, threshold=2)
    assert rc == 0                                    # 2 is not above 2


def test_unreadable_record_is_error_exit_2(root):
    root.mkdir()
    (root / "D-0000000000000000000000000A.json").write_text("{not json")
    rc, out = _cli(root)
    assert rc == 2 and out.startswith("ERROR ")


def test_audit_line_grades_all_three_outcomes():
    src = AUDIT.read_text()
    block = src[src.index("# T-5329 (Risk R-043)"):]
    block = block[:block.index("# T-3695")]
    assert 'info "Withdrawals per submitter/day: no local dispatch records (local backend not wired) (T-5329)"' in block
    assert 'pass "Withdrawals per submitter/day:' in block
    assert block.count('warn "Withdrawals per submitter/day:') == 2   # over threshold, not checked
    assert "fail " not in block
    assert "WITHDRAWALS_WARN_PER_DAY" in block
