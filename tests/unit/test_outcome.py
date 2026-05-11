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


# ---------------------------------------------------------------------------
# T-1780: cmd_read surfaces terminal_event sub-fields (mirror of T-1778)
# ---------------------------------------------------------------------------
import argparse  # noqa: E402


def _read_args(dispatch_id, json_flag=False, tail_events=None):
    return argparse.Namespace(
        dispatch_id=dispatch_id, json=json_flag, tail_events=tail_events,
    )


def test_cmd_read_prints_agent_done_terminal(isolated_root, capsys):
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "d1", "task_id": "T-100", "task_type": "x",
         "worker_kind": "pi", "model": "claude-3",
         "terminal_event": {"type": "agent.done"}},
    ])
    rc = o.cmd_read(_read_args("d1"))
    assert rc == 0
    out = capsys.readouterr().out
    assert "terminal:       agent.done" in out
    # No sub-field noise for agent.done.
    assert "retryable:" not in out
    assert "is_error:" not in out


def test_cmd_read_prints_pi_error_retryable(isolated_root, capsys):
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "d2", "task_id": "T-101", "task_type": "x",
         "worker_kind": "pi", "model": "claude-3",
         "terminal_event": {"type": "error", "retryable": True, "message": "429"}},
    ])
    rc = o.cmd_read(_read_args("d2"))
    assert rc == 0
    out = capsys.readouterr().out
    assert "terminal:       error" in out
    assert "retryable:      True" in out
    assert "is_error:" not in out


def test_cmd_read_prints_ollama_result_is_error(isolated_root, capsys):
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "d3", "task_id": "T-102", "task_type": "x",
         "worker_kind": "ollama-loop", "model": "claude-3",
         "terminal_event": {"type": "result", "is_error": False, "result": "ok"}},
    ])
    rc = o.cmd_read(_read_args("d3"))
    assert rc == 0
    out = capsys.readouterr().out
    assert "terminal:       result" in out
    assert "is_error:       False" in out
    assert "retryable:" not in out


def test_cmd_read_legacy_row_no_terminal_event(isolated_root, capsys):
    """Rows without terminal_event (legacy data) → no terminal lines printed."""
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "d4", "task_id": "T-103", "task_type": "x",
         "worker_kind": "pi", "model": "claude-3"},
    ])
    rc = o.cmd_read(_read_args("d4"))
    assert rc == 0
    out = capsys.readouterr().out
    assert "terminal:" not in out
    assert "retryable:" not in out
    assert "is_error:" not in out


# ---------------------------------------------------------------------------
# T-1782: cmd_list surfaces terminal_event via dispatch join
# ---------------------------------------------------------------------------


def _list_args(task_id, json_flag=False):
    return argparse.Namespace(task_id=task_id, json=json_flag)


def _list_line(stdout: str, did_prefix: str) -> str:
    for line in stdout.splitlines():
        if f"[{did_prefix}" in line:
            return line
    return ""


def test_cmd_list_shows_terminal_agent_done(isolated_root, capsys):
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "L1-abcd", "task_id": "T-200",
         "terminal_event": {"type": "agent.done"}},
    ])
    o.backprop_outcome("T-200", {"verification_passed": True, "ac_satisfied": True})
    rc = o.cmd_list(_list_args("T-200"))
    assert rc == 0
    line = _list_line(capsys.readouterr().out, "L1-abcd")
    assert "terminal=agent.done" in line


def test_cmd_list_shows_retryable_error(isolated_root, capsys):
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "L2-abcd", "task_id": "T-201",
         "terminal_event": {"type": "error", "retryable": True}},
    ])
    o.backprop_outcome("T-201", {"verification_passed": False})
    rc = o.cmd_list(_list_args("T-201"))
    assert rc == 0
    line = _list_line(capsys.readouterr().out, "L2-abcd")
    assert "terminal=error(retryable)" in line


def test_cmd_list_shows_result_is_error_suffix(isolated_root, capsys):
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "L3-abcd", "task_id": "T-202",
         "terminal_event": {"type": "result", "is_error": True}},
    ])
    o.backprop_outcome("T-202", {"verification_passed": False})
    rc = o.cmd_list(_list_args("T-202"))
    assert rc == 0
    line = _list_line(capsys.readouterr().out, "L3-abcd")
    assert "terminal=result(is_error)" in line


def test_cmd_list_no_suffix_on_result_success(isolated_root, capsys):
    """is_error=False is the common success path — `terminal=result` with no suffix."""
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "L4-abcd", "task_id": "T-203",
         "terminal_event": {"type": "result", "is_error": False}},
    ])
    o.backprop_outcome("T-203", {"verification_passed": True, "ac_satisfied": True})
    rc = o.cmd_list(_list_args("T-203"))
    assert rc == 0
    line = _list_line(capsys.readouterr().out, "L4-abcd")
    assert "terminal=result" in line
    assert "(is_error)" not in line
    assert "(retryable)" not in line


def test_cmd_list_no_terminal_when_dispatch_row_lacks_it(isolated_root, capsys):
    """Legacy dispatch (no terminal_event) → list line has no `terminal=` suffix."""
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "L5-abcd", "task_id": "T-204"},  # legacy row
    ])
    o.backprop_outcome("T-204", {"verification_passed": True, "ac_satisfied": True})
    rc = o.cmd_list(_list_args("T-204"))
    assert rc == 0
    line = _list_line(capsys.readouterr().out, "L5-abcd")
    assert "terminal=" not in line


def test_cmd_list_no_terminal_when_dispatch_not_in_log(isolated_root, capsys):
    """Orphan outcome row (no matching dispatch) → no crash, no suffix."""
    root, o = isolated_root
    # Seed an unrelated dispatch so log exists but no matching row for T-205.
    _seed_dispatches(root, [
        {"dispatch_id": "OTHER-abcd", "task_id": "T-999",
         "terminal_event": {"type": "agent.done"}},
    ])
    # Manually append an outcome with no matching dispatch.
    outcomes_log = root / ".context" / "dispatch-outcomes.jsonl"
    outcomes_log.write_text(json.dumps({
        "dispatch_id": "ORPHAN-abcd", "task_id": "T-205", "ts": "2026-05-11T00:00:00",
        "outcome": {"verification_passed": True, "ac_satisfied": True},
    }) + "\n")
    rc = o.cmd_list(_list_args("T-205"))
    assert rc == 0
    line = _list_line(capsys.readouterr().out, "ORPHAN-a")
    assert line  # row was rendered
    assert "terminal=" not in line


# ---------------------------------------------------------------------------
# T-1783: --tail-events N — forensic event tail from blob
# ---------------------------------------------------------------------------


def _seed_events_blob(root: Path, dispatch_id: str, events: list[dict]) -> str:
    blob_dir = root / ".context" / "dispatch-blobs" / dispatch_id
    blob_dir.mkdir(parents=True, exist_ok=True)
    (blob_dir / "events.jsonl").write_text(
        "\n".join(json.dumps(e) for e in events) + ("\n" if events else "")
    )
    return str(blob_dir)


def test_tail_events_shows_last_n_event_types(isolated_root, capsys):
    root, o = isolated_root
    blob = _seed_events_blob(root, "tail-1", [
        {"type": "thinking", "msg": "step1"},
        {"type": "tool_use", "name": "Read"},
        {"type": "tool_use", "name": "Bash"},
        {"type": "result", "is_error": False, "result": "ok"},
    ])
    _seed_dispatches(root, [
        {"dispatch_id": "tail-1", "task_id": "T-300", "task_type": "x",
         "worker_kind": "ollama-loop", "model": "m", "blob_dir": blob,
         "terminal_event": {"type": "result", "is_error": False}},
    ])
    rc = o.cmd_read(_read_args("tail-1", tail_events=2))
    assert rc == 0
    out = capsys.readouterr().out
    assert "events (last 2 of 4)" in out
    # Last two events: tool_use Bash + result(is_error=False)
    # Earlier events should not appear in the tail summary.
    assert "tool_use" in out
    assert "result (is_error=False)" in out
    # thinking step1 was 4 events back — not in tail.
    assert "step1" not in out


def test_tail_events_rejects_zero_and_negative(isolated_root, capsys):
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "tail-2", "task_id": "T-301", "blob_dir": "/tmp"},
    ])
    rc = o.cmd_read(_read_args("tail-2", tail_events=0))
    assert rc == 1
    err = capsys.readouterr().err
    assert ">= 1" in err

    rc = o.cmd_read(_read_args("tail-2", tail_events=-3))
    assert rc == 1


def test_tail_events_missing_blob_dir_field(isolated_root, capsys):
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "tail-3", "task_id": "T-302",
         "task_type": "x", "worker_kind": "pi", "model": "m"},
    ])
    rc = o.cmd_read(_read_args("tail-3", tail_events=3))
    assert rc == 0
    out = capsys.readouterr().out
    assert "no event log for this dispatch" in out


def test_tail_events_missing_events_file(isolated_root, capsys):
    """blob_dir set but events.jsonl absent → graceful notice."""
    root, o = isolated_root
    empty_blob = root / ".context" / "dispatch-blobs" / "empty"
    empty_blob.mkdir(parents=True)
    _seed_dispatches(root, [
        {"dispatch_id": "tail-4", "task_id": "T-303",
         "task_type": "x", "worker_kind": "pi", "model": "m",
         "blob_dir": str(empty_blob)},
    ])
    rc = o.cmd_read(_read_args("tail-4", tail_events=3))
    assert rc == 0
    out = capsys.readouterr().out
    assert "no event log for this dispatch" in out


def test_tail_events_skips_malformed_lines(isolated_root, capsys):
    root, o = isolated_root
    blob_dir = root / ".context" / "dispatch-blobs" / "tail-5"
    blob_dir.mkdir(parents=True)
    # 1 good, 1 malformed, 1 good.
    (blob_dir / "events.jsonl").write_text(
        '{"type":"agent.done"}\n'
        'not-json-at-all\n'
        '{"type":"result","is_error":false}\n'
    )
    _seed_dispatches(root, [
        {"dispatch_id": "tail-5", "task_id": "T-304",
         "task_type": "x", "worker_kind": "ollama-loop", "model": "m",
         "blob_dir": str(blob_dir)},
    ])
    rc = o.cmd_read(_read_args("tail-5", tail_events=5))
    assert rc == 0
    out = capsys.readouterr().out
    # Two valid events parsed, malformed skipped.
    assert "events (last 2 of 2)" in out
    assert "agent.done" in out
    assert "result" in out


def test_tail_events_omitted_default_behavior(isolated_root, capsys):
    """Without --tail-events, no event tail section is printed (T-1780 unchanged)."""
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "tail-6", "task_id": "T-305",
         "task_type": "x", "worker_kind": "pi", "model": "m",
         "blob_dir": "/tmp/whatever",
         "terminal_event": {"type": "agent.done"}},
    ])
    rc = o.cmd_read(_read_args("tail-6"))  # no tail_events kwarg
    assert rc == 0
    out = capsys.readouterr().out
    assert "events" not in out.lower().split("terminal:")[-1] or "events (last" not in out


def test_cmd_read_json_carries_terminal_event(isolated_root, capsys):
    """--json output includes terminal_event from the dispatch row (T-1777)."""
    root, o = isolated_root
    _seed_dispatches(root, [
        {"dispatch_id": "d5", "task_id": "T-104", "task_type": "x",
         "worker_kind": "ollama-loop", "model": "claude-3",
         "terminal_event": {"type": "result", "is_error": True}},
    ])
    rc = o.cmd_read(_read_args("d5", json_flag=True))
    assert rc == 0
    data = json.loads(capsys.readouterr().out)
    assert data["terminal_event"]["type"] == "result"
    assert data["terminal_event"]["is_error"] is True
