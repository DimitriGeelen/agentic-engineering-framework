"""T-1697: Unit tests for lib/outcome.py.

Pinned behaviors:
- parse_task_file extracts Verification commands + Agent AC ticks
- default_evaluator runs verification (or skips when asked)
- backprop appends one row per matching dispatch_id (NEVER modifies dispatches.jsonl)
- Append-only invariant via SHA256 unchanged
- read_dispatch joins dispatches.jsonl × dispatch-outcomes.jsonl by dispatch_id
- Concurrent backprop on distinct task_ids preserves all writes (unlike
  the modify-in-place spike which lost 35/50 in stress)
"""

from __future__ import annotations

import hashlib
import json
import sys
import threading
import uuid
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))


@pytest.fixture
def isolated_root(tmp_path, monkeypatch):
    (tmp_path / ".context").mkdir(parents=True, exist_ok=True)
    (tmp_path / ".tasks" / "active").mkdir(parents=True, exist_ok=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True, exist_ok=True)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    if "outcome" in sys.modules:
        del sys.modules["outcome"]
    import outcome as o  # noqa

    return tmp_path, o


def _write_task(root: Path, task_id: str, *, ac_total=3, ac_checked=3, verification=()):
    body = [
        f"---",
        f"id: {task_id}",
        f"status: started-work",
        f"---",
        f"# {task_id}: test",
        f"## Acceptance Criteria",
        f"### Agent",
    ]
    for i in range(ac_total):
        mark = "x" if i < ac_checked else " "
        body.append(f"- [{mark}] AC {i}")
    body.append("## Verification")
    for cmd in verification:
        body.append(cmd)
    p = root / ".tasks" / "active" / f"{task_id}-test.md"
    p.write_text("\n".join(body) + "\n")
    return p


def _seed_dispatches(root: Path, rows):
    log = root / ".context" / "dispatches.jsonl"
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")


# ---------------------------------------------------------------------------
# parse_task_file
# ---------------------------------------------------------------------------
def test_parse_task_file_counts_acs(isolated_root):
    root, o = isolated_root
    p = _write_task(root, "T-001", ac_total=4, ac_checked=2)
    out = o.parse_task_file(p)
    assert out["ac_total"] == 4
    assert out["ac_checked"] == 2


def test_parse_task_file_extracts_verification_commands(isolated_root):
    root, o = isolated_root
    p = _write_task(root, "T-001", verification=("echo hi", "# comment", "test -f /etc/hostname"))
    out = o.parse_task_file(p)
    assert "echo hi" in out["verification_commands"]
    assert "# comment" not in out["verification_commands"]
    assert "test -f /etc/hostname" in out["verification_commands"]


def test_parse_task_file_no_acs_returns_zero(isolated_root):
    root, o = isolated_root
    p = root / ".tasks" / "active" / "T-001-empty.md"
    p.write_text("# Empty task with no sections\n")
    out = o.parse_task_file(p)
    assert out["ac_total"] == 0


# ---------------------------------------------------------------------------
# default_evaluator
# ---------------------------------------------------------------------------
def test_evaluator_passing_task(isolated_root):
    root, o = isolated_root
    _write_task(root, "T-001", ac_total=2, ac_checked=2, verification=("true",))
    out = o.default_evaluator("T-001")
    assert out["verification_passed"] is True
    assert out["ac_satisfied"] is True
    assert out["ac_total"] == 2


def test_evaluator_failing_verification(isolated_root):
    root, o = isolated_root
    _write_task(root, "T-001", ac_total=1, ac_checked=1, verification=("false",))
    out = o.default_evaluator("T-001")
    assert out["verification_passed"] is False
    assert len(out["verification_failed_commands"]) == 1


def test_evaluator_unticked_acs(isolated_root):
    root, o = isolated_root
    _write_task(root, "T-001", ac_total=3, ac_checked=1, verification=("true",))
    out = o.default_evaluator("T-001")
    assert out["verification_passed"] is True  # the command passes
    assert out["ac_satisfied"] is False  # but ACs unticked


def test_evaluator_missing_task_file(isolated_root):
    _, o = isolated_root
    out = o.default_evaluator("T-NONEXISTENT")
    assert out["verification_passed"] is False
    assert "not found" in out["notes"]


def test_evaluator_skip_verification(isolated_root):
    """--skip-verification flag bypasses subprocess calls (speed for hook path)."""
    root, o = isolated_root
    _write_task(root, "T-001", ac_total=2, ac_checked=2, verification=("false",))
    out = o.default_evaluator("T-001", run_verification=False)
    # With skip_verification, even a "false" command is treated as pass
    assert out["verification_passed"] is True


# ---------------------------------------------------------------------------
# Backprop (append-only)
# ---------------------------------------------------------------------------
def test_backprop_appends_one_row_per_matching_dispatch(isolated_root):
    root, o = isolated_root
    _seed_dispatches(
        root,
        [
            {"dispatch_id": "d1", "task_id": "T-001"},
            {"dispatch_id": "d2", "task_id": "T-001"},
            {"dispatch_id": "d3", "task_id": "T-002"},
        ],
    )
    n = o.backprop_outcome("T-001", {"verification_passed": True, "ac_satisfied": True})
    assert n == 2
    out_log = root / ".context" / "dispatch-outcomes.jsonl"
    rows = [json.loads(l) for l in out_log.read_text().splitlines() if l]
    assert len(rows) == 2
    assert {r["dispatch_id"] for r in rows} == {"d1", "d2"}


def test_backprop_no_match_returns_zero(isolated_root):
    root, o = isolated_root
    _seed_dispatches(root, [{"dispatch_id": "d1", "task_id": "T-other"}])
    n = o.backprop_outcome("T-NOMATCH", {"x": 1})
    assert n == 0


def test_backprop_never_modifies_dispatches_jsonl(isolated_root):
    """Append-only invariant: SHA256 of dispatches.jsonl unchanged after backprop."""
    root, o = isolated_root
    _seed_dispatches(root, [{"dispatch_id": "d1", "task_id": "T-001"}])
    log = root / ".context" / "dispatches.jsonl"
    sha_before = hashlib.sha256(log.read_bytes()).hexdigest()
    o.backprop_outcome("T-001", {"x": 1})
    sha_after = hashlib.sha256(log.read_bytes()).hexdigest()
    assert sha_before == sha_after, "dispatches.jsonl must not be modified by backprop"


def test_backprop_no_dispatches_log_exits_clean(isolated_root):
    """No dispatches.jsonl yet → backprop is a no-op."""
    _, o = isolated_root
    n = o.backprop_outcome("T-001", {"x": 1})
    assert n == 0


# ---------------------------------------------------------------------------
# Read-path join
# ---------------------------------------------------------------------------
def test_read_dispatch_joins_outcome_event(isolated_root):
    root, o = isolated_root
    _seed_dispatches(
        root,
        [
            {"dispatch_id": "abc-123", "task_id": "T-001", "task_type": "build", "model": "sonnet"},
        ],
    )
    o.backprop_outcome("T-001", {"verification_passed": True, "ac_satisfied": True})
    merged = o.read_dispatch("abc-123")
    assert merged is not None
    assert merged["dispatch_id"] == "abc-123"
    assert "outcome_event" in merged
    assert merged["outcome_event"]["outcome"]["verification_passed"] is True


def test_read_dispatch_prefix_match(isolated_root):
    root, o = isolated_root
    _seed_dispatches(root, [{"dispatch_id": "abc-123-xyz", "task_id": "T-001"}])
    merged = o.read_dispatch("abc")
    assert merged is not None
    assert merged["dispatch_id"] == "abc-123-xyz"


def test_read_dispatch_no_outcome_yet(isolated_root):
    root, o = isolated_root
    _seed_dispatches(root, [{"dispatch_id": "d1", "task_id": "T-001"}])
    merged = o.read_dispatch("d1")
    assert merged is not None
    assert "outcome_event" not in merged  # back-prop hasn't fired


# ---------------------------------------------------------------------------
# Concurrent backprop (the load-bearing test for the design pivot)
# ---------------------------------------------------------------------------
def test_concurrent_backprop_distinct_task_ids_preserves_all_writes(isolated_root):
    """The whole point of the design pivot from T-1690.

    Spike showed modify-in-place lost 35/50 enrichments at 10 threads.
    Append-only must preserve all 50.
    """
    root, o = isolated_root
    rows = []
    for i in range(10):
        for _ in range(5):
            rows.append({"dispatch_id": str(uuid.uuid4()), "task_id": f"T-stress-{i}"})
    _seed_dispatches(root, rows)

    def worker(tid):
        o.backprop_outcome(tid, {"verification_passed": True, "tid": tid})

    threads = [threading.Thread(target=worker, args=(f"T-stress-{i}",)) for i in range(10)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    out_log = root / ".context" / "dispatch-outcomes.jsonl"
    written = [json.loads(l) for l in out_log.read_text().splitlines() if l]
    assert len(written) == 50, f"expected 50 outcome rows, got {len(written)}"
    # Verify all 10 task_ids represented
    by_tid = {}
    for r in written:
        by_tid.setdefault(r["task_id"], 0)
        by_tid[r["task_id"]] += 1
    assert len(by_tid) == 10
    assert all(c == 5 for c in by_tid.values())


def test_list_outcomes_for_task(isolated_root):
    root, o = isolated_root
    _seed_dispatches(
        root,
        [
            {"dispatch_id": "d1", "task_id": "T-001"},
            {"dispatch_id": "d2", "task_id": "T-001"},
        ],
    )
    o.backprop_outcome("T-001", {"v": 1})
    o.backprop_outcome("T-001", {"v": 2})  # second call appends another set
    rows = o.list_outcomes_for_task("T-001")
    assert len(rows) == 4  # 2 dispatches × 2 backprop calls
