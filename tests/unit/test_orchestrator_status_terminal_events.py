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
