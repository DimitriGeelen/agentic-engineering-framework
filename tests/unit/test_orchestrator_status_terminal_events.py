"""T-1779 — Regression tests for `fw orchestrator status` terminal_event breakdown.

Pins the substrate observability contract introduced by T-1777 (spawn driver
persists terminal_event into dispatch rows):

    1. When dispatch rows carry terminal_event, the status output shows a
       "By terminal event:" section listing each terminal type and count.
    2. For "error" terminal events with a `retryable` flag, the count line
       carries `(retryable=N / non-retryable=M)`.
    3. For "result" terminal events with an `is_error` flag, an indented
       sub-line shows `is_error: True=N False=M`.
    4. Rows without terminal_event (legacy data) do not pollute the section —
       it is omitted entirely when the breakdown is empty.
    5. Synthetic T-stress-* rows are excluded from terminal aggregation.
    6. `--json` output exposes `by_terminal_type`, `terminal_retryable`,
       `terminal_is_error` at top level.

Origin: T-1777 made the data available; T-1779 makes it visible. Without
this, operators had to crack open dispatches.jsonl to see what terminated
recent dispatches.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
FW = REPO_ROOT / "bin" / "fw"


def _run_status(tmp_root: Path, *args: str) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(tmp_root)
    return subprocess.run(
        [str(FW), "orchestrator", "status", *args],
        capture_output=True, text=True, env=env, cwd=str(tmp_root),
    )


def _seed_jsonl(root: Path, dispatches: list[dict], outcomes: list[dict]) -> None:
    cdir = root / ".context"
    cdir.mkdir(parents=True, exist_ok=True)
    (cdir / "dispatches.jsonl").write_text(
        "\n".join(json.dumps(d) for d in dispatches) + ("\n" if dispatches else "")
    )
    (cdir / "dispatch-outcomes.jsonl").write_text(
        "\n".join(json.dumps(o) for o in outcomes) + ("\n" if outcomes else "")
    )


# ---------------------------------------------------------------------------
# Text output — section presence and content
# ---------------------------------------------------------------------------


def test_terminal_event_breakdown_rendered_when_rows_carry_it(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100", "task_type": "X",
         "worker_kind": "pi", "terminal_event": {"type": "agent.done"}},
        {"dispatch_id": "d2", "task_id": "T-101", "task_type": "X",
         "worker_kind": "pi", "terminal_event": {"type": "agent.done"}},
        {"dispatch_id": "d3", "task_id": "T-102", "task_type": "Y",
         "worker_kind": "ollama-loop",
         "terminal_event": {"type": "result", "is_error": False}},
    ], [])
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "By terminal event:" in result.stdout
    assert "agent.done" in result.stdout
    assert "result" in result.stdout
    # agent.done has 2 → appears before result (1) due to sort-by-count
    out = result.stdout.split("By terminal event:")[1]
    assert out.index("agent.done") < out.index("result")


def test_error_event_shows_retryable_split(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100", "task_type": "X",
         "worker_kind": "pi",
         "terminal_event": {"type": "error", "retryable": True, "message": "429"}},
        {"dispatch_id": "d2", "task_id": "T-101", "task_type": "X",
         "worker_kind": "pi",
         "terminal_event": {"type": "error", "retryable": False, "message": "auth"}},
        {"dispatch_id": "d3", "task_id": "T-102", "task_type": "X",
         "worker_kind": "pi",
         "terminal_event": {"type": "error", "retryable": True, "message": "429"}},
    ], [])
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "By terminal event:" in result.stdout
    # error count = 3, retryable split = 2/1
    section = result.stdout.split("By terminal event:")[1]
    assert "error" in section
    assert "retryable=2" in section
    assert "non-retryable=1" in section


def test_result_event_shows_is_error_split(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100", "task_type": "X",
         "worker_kind": "ollama-loop",
         "terminal_event": {"type": "result", "is_error": False, "result": "ok"}},
        {"dispatch_id": "d2", "task_id": "T-101", "task_type": "X",
         "worker_kind": "ollama-loop",
         "terminal_event": {"type": "result", "is_error": True, "result": "fail"}},
    ], [])
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    section = result.stdout.split("By terminal event:")[1]
    assert "result" in section
    assert "is_error: True=1 False=1" in section


def test_section_omitted_when_no_row_has_terminal_event(tmp_path):
    """Legacy data (rows without terminal_event) must not produce empty section."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100", "task_type": "X",
         "worker_kind": "pi"},
        {"dispatch_id": "d2", "task_id": "T-101", "task_type": "Y",
         "worker_kind": "ollama-loop"},
    ], [])
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "By terminal event:" not in result.stdout
    # Existing breakdowns still present.
    assert "By task_type:" in result.stdout
    assert "By worker_kind:" in result.stdout


def test_synthetic_dispatches_excluded_from_terminal_breakdown(tmp_path):
    """T-stress-* synthetic rows must not pollute the terminal_event breakdown."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-stress-1", "task_type": "stress",
         "worker_kind": "Task",
         "terminal_event": {"type": "synthetic_termination"}},
        {"dispatch_id": "d2", "task_id": "T-100", "task_type": "real",
         "worker_kind": "pi",
         "terminal_event": {"type": "agent.done"}},
    ], [])
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    section = result.stdout.split("By terminal event:")[1] if "By terminal event:" in result.stdout else ""
    assert "agent.done" in section
    assert "synthetic_termination" not in section


def test_mixed_legacy_and_new_rows_only_count_those_with_terminal_event(tmp_path):
    """Rows without terminal_event are silently skipped (not counted as ?)."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100", "task_type": "X",
         "worker_kind": "pi"},  # legacy, no terminal_event
        {"dispatch_id": "d2", "task_id": "T-101", "task_type": "X",
         "worker_kind": "pi",
         "terminal_event": {"type": "agent.done"}},
    ], [])
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "By terminal event:" in result.stdout
    section = result.stdout.split("By terminal event:")[1]
    assert "agent.done" in section
    # No "?" line — legacy row is skipped, not bucketed as unknown.
    assert "  ? " not in section.split("Recent dispatches")[0]


# ---------------------------------------------------------------------------
# JSON output
# ---------------------------------------------------------------------------


def test_json_exposes_terminal_event_keys(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100", "task_type": "X",
         "worker_kind": "pi",
         "terminal_event": {"type": "error", "retryable": True}},
        {"dispatch_id": "d2", "task_id": "T-101", "task_type": "Y",
         "worker_kind": "ollama-loop",
         "terminal_event": {"type": "result", "is_error": False}},
    ], [])
    result = _run_status(tmp_path, "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert "by_terminal_type" in data
    assert "terminal_retryable" in data
    assert "terminal_is_error" in data
    assert data["by_terminal_type"]["error"] == 1
    assert data["by_terminal_type"]["result"] == 1
    assert data["terminal_retryable"]["True"] == 1
    assert data["terminal_is_error"]["False"] == 1


# ---------------------------------------------------------------------------
# T-1781 — Recent dispatches inline terminal_event
# ---------------------------------------------------------------------------


def _recent_line(stdout: str, dispatch_prefix: str) -> str:
    """Return the 'Recent dispatches:' line matching a dispatch_id prefix."""
    block = stdout.split("Recent dispatches:")[-1]
    for line in block.splitlines():
        if f"[{dispatch_prefix}" in line:
            return line
    return ""


def test_recent_line_shows_terminal_agent_done(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "deadbeef-1", "ts": "2026-05-11T00:00:01", "task_id": "T-100",
         "task_type": "X", "worker_kind": "pi",
         "terminal_event": {"type": "agent.done"}},
    ], [])
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    line = _recent_line(result.stdout, "deadbeef")
    assert "terminal=agent.done" in line


def test_recent_line_shows_retryable_error(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "deadbeef-2", "ts": "2026-05-11T00:00:02", "task_id": "T-101",
         "task_type": "X", "worker_kind": "pi",
         "terminal_event": {"type": "error", "retryable": True, "message": "429"}},
    ], [])
    result = _run_status(tmp_path)
    line = _recent_line(result.stdout, "deadbeef")
    assert "terminal=error(retryable)" in line


def test_recent_line_shows_non_retryable_error(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "deadbeef-3", "ts": "2026-05-11T00:00:03", "task_id": "T-102",
         "task_type": "X", "worker_kind": "pi",
         "terminal_event": {"type": "error", "retryable": False, "message": "auth"}},
    ], [])
    result = _run_status(tmp_path)
    line = _recent_line(result.stdout, "deadbeef")
    assert "terminal=error(non-retryable)" in line


def test_recent_line_shows_result_is_error_true(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "deadbeef-4", "ts": "2026-05-11T00:00:04", "task_id": "T-103",
         "task_type": "X", "worker_kind": "ollama-loop",
         "terminal_event": {"type": "result", "is_error": True}},
    ], [])
    result = _run_status(tmp_path)
    line = _recent_line(result.stdout, "deadbeef")
    assert "terminal=result(is_error)" in line


def test_recent_line_shows_result_no_suffix_on_success(tmp_path):
    """is_error: False is the common success case — no suffix noise."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "deadbeef-5", "ts": "2026-05-11T00:00:05", "task_id": "T-104",
         "task_type": "X", "worker_kind": "ollama-loop",
         "terminal_event": {"type": "result", "is_error": False}},
    ], [])
    result = _run_status(tmp_path)
    line = _recent_line(result.stdout, "deadbeef")
    assert "terminal=result" in line
    # No suffix on the success path.
    assert "(is_error)" not in line
    assert "(retryable)" not in line


def test_recent_line_unchanged_when_no_terminal_event(tmp_path):
    """Legacy rows without terminal_event must not have a `terminal=` field."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "deadbeef-6", "ts": "2026-05-11T00:00:06", "task_id": "T-105",
         "task_type": "X", "worker_kind": "pi"},
    ], [])
    result = _run_status(tmp_path)
    line = _recent_line(result.stdout, "deadbeef")
    assert "terminal=" not in line
    # Existing line content still rendered.
    assert "worker=pi" in line


def test_json_recent_carries_terminal_event(tmp_path):
    """`--json` exposes terminal_event per recent entry (mirrors row shape)."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "deadbeef-7", "ts": "2026-05-11T00:00:07", "task_id": "T-106",
         "task_type": "X", "worker_kind": "ollama-loop",
         "terminal_event": {"type": "result", "is_error": False}},
    ], [])
    result = _run_status(tmp_path, "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    entry = next(r for r in data["recent"] if r["dispatch_id"].startswith("deadbeef"))
    assert entry["terminal_event"]["type"] == "result"
    assert entry["terminal_event"]["is_error"] is False


# ---------------------------------------------------------------------------
# T-1785: --since DURATION filter
# ---------------------------------------------------------------------------


def test_since_filter_rejects_invalid_format(tmp_path):
    _seed_jsonl(tmp_path, [], [])
    for bad in ("xyz", "0h", "-1h", "1", "1s", "30 minutes"):
        result = _run_status(tmp_path, "--since", bad)
        assert result.returncode == 1, f"expected error for --since {bad!r}"
        assert "invalid --since" in result.stderr


def test_since_filter_accepts_m_h_d(tmp_path):
    """Smoke that all three units parse — empty data, just verifies no parse error."""
    _seed_jsonl(tmp_path, [], [])
    for good in ("1m", "24h", "7d", "999m"):
        result = _run_status(tmp_path, "--since", good)
        # No matching rows → exit 0 with notice; parse error would exit 1.
        assert result.returncode == 0, f"--since {good!r} should parse: {result.stderr}"


def test_since_filter_narrows_to_recent_only(tmp_path):
    """Rows older than the cutoff are excluded."""
    from datetime import datetime, timezone, timedelta
    now = datetime.now(timezone.utc)
    recent_ts = (now - timedelta(minutes=30)).isoformat()
    old_ts = (now - timedelta(days=2)).isoformat()
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "RECENT-1", "ts": recent_ts, "task_id": "T-100",
         "task_type": "X", "worker_kind": "pi"},
        {"dispatch_id": "OLD-1", "ts": old_ts, "task_id": "T-100",
         "task_type": "X", "worker_kind": "pi"},
    ], [])
    result = _run_status(tmp_path, "--since", "1h")
    assert result.returncode == 0, result.stderr
    assert "Filter:            since=1h" in result.stdout
    assert "Dispatches:        1" in result.stdout
    assert "[RECENT-1" in result.stdout
    assert "[OLD-1" not in result.stdout


def test_since_filter_empty_result_notice(tmp_path):
    """Old rows + --since 1h → empty notice."""
    from datetime import datetime, timezone, timedelta
    old_ts = (datetime.now(timezone.utc) - timedelta(days=5)).isoformat()
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "OLD-x", "ts": old_ts, "task_id": "T-100",
         "task_type": "X", "worker_kind": "pi"},
    ], [])
    result = _run_status(tmp_path, "--since", "1h")
    assert result.returncode == 0, result.stderr
    assert "no dispatches captured for the last 1h" in result.stdout


def test_since_and_task_filters_compose_AND(tmp_path):
    """When both --task and --since are set, both must match."""
    from datetime import datetime, timezone, timedelta
    now = datetime.now(timezone.utc)
    recent = (now - timedelta(minutes=10)).isoformat()
    old = (now - timedelta(days=3)).isoformat()
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "MATCH-1", "ts": recent, "task_id": "T-100",
         "task_type": "X", "worker_kind": "pi"},
        {"dispatch_id": "WRONG-TASK", "ts": recent, "task_id": "T-200",
         "task_type": "X", "worker_kind": "pi"},
        {"dispatch_id": "WRONG-TIME", "ts": old, "task_id": "T-100",
         "task_type": "X", "worker_kind": "pi"},
    ], [])
    result = _run_status(tmp_path, "--task", "T-100", "--since", "1h")
    assert result.returncode == 0, result.stderr
    assert "Dispatches:        1" in result.stdout
    assert "[MATCH-1" in result.stdout
    assert "[WRONG-TASK" not in result.stdout
    assert "[WRONG-TIME" not in result.stdout


# ---------------------------------------------------------------------------
# T-1784: --task T-XXX filter
# ---------------------------------------------------------------------------


def test_task_filter_narrows_to_matching_dispatches(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "f1-aaaa", "ts": "2026-05-11T00:00:01", "task_id": "T-100",
         "task_type": "X", "worker_kind": "pi"},
        {"dispatch_id": "f2-bbbb", "ts": "2026-05-11T00:00:02", "task_id": "T-200",
         "task_type": "Y", "worker_kind": "ollama-loop"},
        {"dispatch_id": "f3-cccc", "ts": "2026-05-11T00:00:03", "task_id": "T-100",
         "task_type": "X", "worker_kind": "pi"},
    ], [])
    result = _run_status(tmp_path, "--task", "T-100")
    assert result.returncode == 0, result.stderr
    assert "Filter:            task=T-100" in result.stdout
    assert "Dispatches:        2" in result.stdout
    # T-200 row excluded.
    assert "[f2-bbbb" not in result.stdout
    # T-100 rows present.
    assert "[f1-aaaa" in result.stdout
    assert "[f3-cccc" in result.stdout


def test_task_filter_empty_result_prints_notice(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "f1-aaaa", "task_id": "T-100",
         "task_type": "X", "worker_kind": "pi"},
    ], [])
    result = _run_status(tmp_path, "--task", "T-999")
    assert result.returncode == 0, result.stderr
    assert "no dispatches captured for task T-999" in result.stdout


def test_task_filter_with_json_returns_empty_stats(tmp_path):
    """--json --task with no match returns parseable empty stats, not free text."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "f1-aaaa", "task_id": "T-100",
         "task_type": "X", "worker_kind": "pi"},
    ], [])
    result = _run_status(tmp_path, "--task", "T-999", "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert data["dispatch_total"] == 0
    assert data["by_task_type"] == {}
    assert data["by_worker_kind"] == {}


def test_task_filter_composes_with_json(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "f1-aaaa", "task_id": "T-100",
         "task_type": "X", "worker_kind": "pi"},
        {"dispatch_id": "f2-bbbb", "task_id": "T-200",
         "task_type": "Y", "worker_kind": "ollama-loop"},
    ], [])
    result = _run_status(tmp_path, "--task", "T-100", "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert data["dispatch_total"] == 1
    # Only T-100's task_type appears.
    assert "X" in data["by_task_type"]
    assert "Y" not in data["by_task_type"]


def test_task_filter_excludes_synthetic_rows(tmp_path):
    """Synthetic T-stress-* are not matched even when filter looks for them."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "f1-aaaa", "task_id": "T-stress-100",
         "task_type": "stress", "worker_kind": "pi"},
    ], [])
    result = _run_status(tmp_path, "--task", "T-stress-100")
    assert result.returncode == 0, result.stderr
    # Synthetic rows excluded BEFORE filter applies, so the filter sees zero.
    assert "no dispatches captured for task T-stress-100" in result.stdout


def test_json_terminal_keys_empty_when_no_rows_have_terminal_event(tmp_path):
    """Legacy-only data → empty dicts (not missing keys, not None)."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100", "task_type": "X",
         "worker_kind": "pi"},
    ], [])
    result = _run_status(tmp_path, "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert data["by_terminal_type"] == {}
    assert data["terminal_retryable"] == {}
    assert data["terminal_is_error"] == {}


# ---------------------------------------------------------------------------
# T-1786: --worker-kind X filter
# ---------------------------------------------------------------------------


def test_worker_kind_filter_narrows_to_matching_dispatches(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "w1-aaaa", "ts": "2026-05-11T00:00:01", "task_id": "T-100",
         "task_type": "X", "worker_kind": "ollama-loop"},
        {"dispatch_id": "w2-bbbb", "ts": "2026-05-11T00:00:02", "task_id": "T-200",
         "task_type": "Y", "worker_kind": "TermLink"},
        {"dispatch_id": "w3-cccc", "ts": "2026-05-11T00:00:03", "task_id": "T-300",
         "task_type": "Z", "worker_kind": "ollama-loop"},
    ], [])
    result = _run_status(tmp_path, "--worker-kind", "ollama-loop")
    assert result.returncode == 0, result.stderr
    assert "Filter:            worker_kind=ollama-loop" in result.stdout
    assert "Dispatches:        2" in result.stdout
    # TermLink row excluded.
    assert "[w2-bbbb" not in result.stdout
    # ollama-loop rows present.
    assert "[w1-aaaa" in result.stdout
    assert "[w3-cccc" in result.stdout


def test_worker_kind_filter_empty_result_prints_notice(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "w1-aaaa", "task_id": "T-100",
         "task_type": "X", "worker_kind": "ollama-loop"},
    ], [])
    result = _run_status(tmp_path, "--worker-kind", "Task")
    assert result.returncode == 0, result.stderr
    assert "no dispatches captured for worker_kind Task" in result.stdout


def test_worker_kind_filter_composes_with_task_AND(tmp_path):
    """--worker-kind and --task: both filters must match."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "w1-aaaa", "ts": "2026-05-11T00:00:01", "task_id": "T-100",
         "task_type": "X", "worker_kind": "ollama-loop"},
        {"dispatch_id": "w2-bbbb", "ts": "2026-05-11T00:00:02", "task_id": "T-100",
         "task_type": "X", "worker_kind": "TermLink"},
        {"dispatch_id": "w3-cccc", "ts": "2026-05-11T00:00:03", "task_id": "T-200",
         "task_type": "Y", "worker_kind": "ollama-loop"},
    ], [])
    result = _run_status(tmp_path, "--worker-kind", "ollama-loop", "--task", "T-100")
    assert result.returncode == 0, result.stderr
    assert "Filter:            task=T-100" in result.stdout
    assert "Filter:            worker_kind=ollama-loop" in result.stdout
    assert "Dispatches:        1" in result.stdout
    assert "[w1-aaaa" in result.stdout
    assert "[w2-bbbb" not in result.stdout
    assert "[w3-cccc" not in result.stdout


def test_worker_kind_filter_composes_with_since_AND(tmp_path):
    """--worker-kind and --since: AND-composition with time window."""
    from datetime import datetime, timezone, timedelta
    now = datetime.now(timezone.utc)
    recent = (now - timedelta(minutes=10)).isoformat()
    old = (now - timedelta(days=2)).isoformat()
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "w1-aaaa", "ts": recent, "task_id": "T-100",
         "task_type": "X", "worker_kind": "ollama-loop"},
        {"dispatch_id": "w2-bbbb", "ts": old, "task_id": "T-100",
         "task_type": "X", "worker_kind": "ollama-loop"},
        {"dispatch_id": "w3-cccc", "ts": recent, "task_id": "T-100",
         "task_type": "X", "worker_kind": "TermLink"},
    ], [])
    result = _run_status(tmp_path, "--worker-kind", "ollama-loop", "--since", "1h")
    assert result.returncode == 0, result.stderr
    assert "Dispatches:        1" in result.stdout
    assert "[w1-aaaa" in result.stdout  # recent + ollama-loop
    assert "[w2-bbbb" not in result.stdout  # old (filtered by --since)
    assert "[w3-cccc" not in result.stdout  # TermLink (filtered by --worker-kind)


def test_worker_kind_filter_composes_with_json(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "w1-aaaa", "task_id": "T-100",
         "task_type": "X", "worker_kind": "ollama-loop"},
        {"dispatch_id": "w2-bbbb", "task_id": "T-200",
         "task_type": "Y", "worker_kind": "TermLink"},
    ], [])
    result = _run_status(tmp_path, "--worker-kind", "ollama-loop", "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert data["dispatch_total"] == 1
    # Only ollama-loop's worker_kind appears in breakdown.
    assert "ollama-loop" in data["by_worker_kind"]
    assert "TermLink" not in data["by_worker_kind"]


# ---------------------------------------------------------------------------
# T-1787: --recent N — view-density knob
# ---------------------------------------------------------------------------


def _seed_n_dispatches(tmp_path, n):
    """Seed n dispatches with ascending ts; ids r0001..r{n:04d}."""
    rows = []
    for i in range(n):
        rows.append({
            "dispatch_id": f"r{i:04d}-aa",
            "ts": f"2026-05-11T00:{i // 60:02d}:{i % 60:02d}",
            "task_id": f"T-{1000 + i}",
            "task_type": "escalation-triage",
            "worker_kind": "ollama-loop",
        })
    _seed_jsonl(tmp_path, rows, [])


def test_recent_default_is_5(tmp_path):
    """No --recent → last 5 dispatches (preserves pre-flag behavior)."""
    _seed_n_dispatches(tmp_path, 10)
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    # Last 5 dispatches: r0005..r0009 present, r0000..r0004 absent.
    for i in range(5):
        assert f"[r{i:04d}-a" not in result.stdout, f"row {i} should be hidden"
    for i in range(5, 10):
        assert f"[r{i:04d}-a" in result.stdout, f"row {i} should be visible"


def test_recent_n_shows_n_rows(tmp_path):
    """--recent 10 → up to 10 dispatches."""
    _seed_n_dispatches(tmp_path, 20)
    result = _run_status(tmp_path, "--recent", "10")
    assert result.returncode == 0, result.stderr
    # Last 10: r0010..r0019 present, r0000..r0009 absent.
    for i in range(10):
        assert f"[r{i:04d}-a" not in result.stdout, f"row {i} should be hidden"
    for i in range(10, 20):
        assert f"[r{i:04d}-a" in result.stdout, f"row {i} should be visible"


def test_recent_1_shows_only_latest(tmp_path):
    """--recent 1 → only the latest row."""
    _seed_n_dispatches(tmp_path, 5)
    result = _run_status(tmp_path, "--recent", "1")
    assert result.returncode == 0, result.stderr
    assert "[r0004-a" in result.stdout  # latest
    for i in range(4):
        assert f"[r{i:04d}-a" not in result.stdout


def test_recent_zero_rejected(tmp_path):
    _seed_n_dispatches(tmp_path, 3)
    result = _run_status(tmp_path, "--recent", "0")
    assert result.returncode == 1
    assert "--recent must be >= 1" in result.stderr


def test_recent_negative_rejected(tmp_path):
    _seed_n_dispatches(tmp_path, 3)
    result = _run_status(tmp_path, "--recent", "-5")
    assert result.returncode == 1
    # Negative parses as int but fails the >=1 check.
    assert "--recent must be >= 1" in result.stderr


def test_recent_non_integer_rejected(tmp_path):
    _seed_n_dispatches(tmp_path, 3)
    result = _run_status(tmp_path, "--recent", "abc")
    assert result.returncode == 1
    assert "invalid --recent" in result.stderr


def test_recent_composes_with_worker_kind(tmp_path):
    """--recent applies AFTER --worker-kind filter; count reflects matches only."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "a01-aa", "ts": "2026-05-11T00:00:01", "task_id": "T-1",
         "task_type": "X", "worker_kind": "ollama-loop"},
        {"dispatch_id": "a02-aa", "ts": "2026-05-11T00:00:02", "task_id": "T-2",
         "task_type": "X", "worker_kind": "TermLink"},
        {"dispatch_id": "a03-aa", "ts": "2026-05-11T00:00:03", "task_id": "T-3",
         "task_type": "X", "worker_kind": "ollama-loop"},
        {"dispatch_id": "a04-aa", "ts": "2026-05-11T00:00:04", "task_id": "T-4",
         "task_type": "X", "worker_kind": "ollama-loop"},
    ], [])
    result = _run_status(tmp_path, "--worker-kind", "ollama-loop", "--recent", "2")
    assert result.returncode == 0, result.stderr
    # 3 ollama-loop rows in scope; recent 2 → a03, a04.
    assert "[a03-a" in result.stdout
    assert "[a04-a" in result.stdout
    # a01 (ollama-loop but bumped out by --recent 2)
    assert "[a01-a" not in result.stdout
    # a02 (filtered by --worker-kind)
    assert "[a02-a" not in result.stdout


def test_recent_composes_with_json(tmp_path):
    """--recent affects stats['recent'] in JSON output."""
    _seed_n_dispatches(tmp_path, 10)
    result = _run_status(tmp_path, "--recent", "3", "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert len(data["recent"]) == 3
    # Totals unchanged (recent only narrows the view, not stats).
    assert data["dispatch_total"] == 10


# ---------------------------------------------------------------------------
# T-1788: model surface — by_model breakdown + recent-line model=
# ---------------------------------------------------------------------------


def test_by_model_section_rendered_when_model_present(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "m1-aaaa", "task_id": "T-1", "task_type": "X",
         "worker_kind": "ollama-loop", "model": "claude-3-5-sonnet"},
        {"dispatch_id": "m2-bbbb", "task_id": "T-2", "task_type": "X",
         "worker_kind": "ollama-loop", "model": "claude-3-5-sonnet"},
        {"dispatch_id": "m3-cccc", "task_id": "T-3", "task_type": "Y",
         "worker_kind": "TermLink", "model": "sonnet"},
    ], [])
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "By model:" in result.stdout
    assert "claude-3-5-sonnet" in result.stdout
    assert "sonnet" in result.stdout
    # Most-common first.
    assert result.stdout.index("claude-3-5-sonnet") < result.stdout.index("  sonnet")


def test_by_model_section_omitted_when_no_model_field(tmp_path):
    """Legacy-only rows (no model field) → section absent (graceful)."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "m1-aaaa", "task_id": "T-1", "task_type": "X",
         "worker_kind": "ollama-loop"},
        {"dispatch_id": "m2-bbbb", "task_id": "T-2", "task_type": "Y",
         "worker_kind": "ollama-loop"},
    ], [])
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "By model:" not in result.stdout


def test_recent_line_shows_model(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "m1-aaaa", "ts": "2026-05-11T00:00:01", "task_id": "T-1",
         "task_type": "X", "worker_kind": "ollama-loop",
         "model": "claude-3-5-sonnet-hermes3"},
    ], [])
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "model=claude-3-5-sonnet-hermes3" in result.stdout


def test_recent_line_shows_model_question_when_missing(tmp_path):
    """No model field → model=? in recent line (column shape preserved)."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "m1-aaaa", "ts": "2026-05-11T00:00:01", "task_id": "T-1",
         "task_type": "X", "worker_kind": "ollama-loop"},
    ], [])
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "model=?" in result.stdout


def test_by_model_respects_worker_kind_filter(tmp_path):
    """--worker-kind filter narrows the by_model breakdown."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "m1-aaaa", "task_id": "T-1", "task_type": "X",
         "worker_kind": "ollama-loop", "model": "claude-3-5-sonnet"},
        {"dispatch_id": "m2-bbbb", "task_id": "T-2", "task_type": "Y",
         "worker_kind": "TermLink", "model": "sonnet"},
    ], [])
    result = _run_status(tmp_path, "--worker-kind", "ollama-loop")
    assert result.returncode == 0, result.stderr
    assert "claude-3-5-sonnet" in result.stdout
    # TermLink's model excluded by the filter.
    # Check the model row inside By model: section (not other contexts).
    assert "  sonnet                  " not in result.stdout


def test_json_exposes_by_model_key(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "m1-aaaa", "task_id": "T-1", "task_type": "X",
         "worker_kind": "ollama-loop", "model": "claude-3-5-sonnet"},
        {"dispatch_id": "m2-bbbb", "task_id": "T-2", "task_type": "Y",
         "worker_kind": "TermLink", "model": "sonnet"},
    ], [])
    result = _run_status(tmp_path, "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert "by_model" in data
    assert data["by_model"]["claude-3-5-sonnet"] == 1
    assert data["by_model"]["sonnet"] == 1
    # Each recent row carries the model field.
    for r in data["recent"]:
        assert "model" in r


def test_json_by_model_empty_when_no_model_field(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "m1-aaaa", "task_id": "T-1", "task_type": "X",
         "worker_kind": "ollama-loop"},
    ], [])
    result = _run_status(tmp_path, "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert data["by_model"] == {}
    # Recent row carries model=None (key present, value None).
    assert data["recent"][0]["model"] is None


# ---------------------------------------------------------------------------
# T-1790: --task-type X filter
# ---------------------------------------------------------------------------


def test_task_type_filter_narrows_to_matching_dispatches(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "tt1-aaa", "ts": "2026-05-11T00:00:01", "task_id": "T-1",
         "task_type": "escalation-triage", "worker_kind": "ollama-loop"},
        {"dispatch_id": "tt2-bbb", "ts": "2026-05-11T00:00:02", "task_id": "T-2",
         "task_type": "build", "worker_kind": "TermLink"},
        {"dispatch_id": "tt3-ccc", "ts": "2026-05-11T00:00:03", "task_id": "T-3",
         "task_type": "escalation-triage", "worker_kind": "ollama-loop"},
    ], [])
    result = _run_status(tmp_path, "--task-type", "escalation-triage")
    assert result.returncode == 0, result.stderr
    assert "Filter:            task_type=escalation-triage" in result.stdout
    assert "Dispatches:        2" in result.stdout
    assert "[tt2-bbb" not in result.stdout
    assert "[tt1-aaa" in result.stdout
    assert "[tt3-ccc" in result.stdout


def test_task_type_filter_empty_result_prints_notice(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "tt1-aaa", "task_id": "T-1", "task_type": "build",
         "worker_kind": "ollama-loop"},
    ], [])
    result = _run_status(tmp_path, "--task-type", "design")
    assert result.returncode == 0, result.stderr
    assert "no dispatches captured for task_type design" in result.stdout


def test_task_type_filter_composes_with_worker_kind_AND(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "tt1-aaa", "ts": "2026-05-11T00:00:01", "task_id": "T-1",
         "task_type": "escalation-triage", "worker_kind": "ollama-loop"},
        {"dispatch_id": "tt2-bbb", "ts": "2026-05-11T00:00:02", "task_id": "T-2",
         "task_type": "escalation-triage", "worker_kind": "TermLink"},
        {"dispatch_id": "tt3-ccc", "ts": "2026-05-11T00:00:03", "task_id": "T-3",
         "task_type": "build", "worker_kind": "ollama-loop"},
    ], [])
    result = _run_status(tmp_path,
                         "--task-type", "escalation-triage",
                         "--worker-kind", "ollama-loop")
    assert result.returncode == 0, result.stderr
    assert "Dispatches:        1" in result.stdout
    assert "[tt1-aaa" in result.stdout
    assert "[tt2-bbb" not in result.stdout
    assert "[tt3-ccc" not in result.stdout
