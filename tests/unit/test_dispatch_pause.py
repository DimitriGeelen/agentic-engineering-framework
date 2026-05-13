"""Tests for lib/dispatch_pause.py — operator review-queue surface for paused
dispatches.

Origin: T-1808 (dispatch-safety slice 4).
"""

from __future__ import annotations

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

FRAMEWORK_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(FRAMEWORK_ROOT / "lib"))

import dispatch_pause  # noqa: E402
from dispatch_pause import (  # noqa: E402
    format_age,
    list_paused_dispatches,
    truncate,
)


def _now_iso(offset_seconds: int = 0) -> str:
    return (datetime.now(timezone.utc) - timedelta(seconds=offset_seconds)).isoformat().replace(
        "+00:00", "Z"
    )


def _make_dispatch(
    dispatch_id: str,
    task_id: str,
    outcome: str,
    age_s: int = 60,
    terminal_event: dict | None = None,
    retry_of: str | None = None,
):
    row = {
        "schema_version": 1,
        "ts": _now_iso(age_s),
        "dispatch_id": dispatch_id,
        "task_id": task_id,
        "task_type": "default",
        "worker_kind": "TermLink",
        "model": "sonnet",
        "outcome": outcome,
    }
    if terminal_event is not None:
        row["terminal_event"] = terminal_event
    if retry_of is not None:
        row["retry_of_dispatch_id"] = retry_of
    return row


def _write_log(tmp_path: Path, rows: list[dict]) -> Path:
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text("\n".join(json.dumps(r) for r in rows) + "\n")
    return log


@pytest.fixture(autouse=True)
def _isolate_default_root(tmp_path, monkeypatch):
    """Default root → tmp_path so module-level scans don't see the live repo log."""
    monkeypatch.setattr(dispatch_pause, "_PROJECT_ROOT_DEFAULT", tmp_path)
    return tmp_path


# ---------------------------------------------------------------------------
# Filtering: only paused rows are surfaced.
# ---------------------------------------------------------------------------


def test_filters_to_paused_rows(tmp_path):
    _write_log(tmp_path, [
        _make_dispatch("d-success", "T-1", "success"),
        _make_dispatch("d-error", "T-2", "error"),
        _make_dispatch("d-pending", "T-3", "pending"),
        _make_dispatch("d-paused", "T-4", "paused",
                       terminal_event={"type": "pause_requested",
                                       "question": "Drop legacy auth?"}),
    ])
    out = list_paused_dispatches(tmp_path)
    assert len(out) == 1
    assert out[0]["dispatch_id"] == "d-paused"
    assert out[0]["task_id"] == "T-4"
    assert out[0]["question"] == "Drop legacy auth?"


def test_empty_log_returns_empty(tmp_path):
    assert list_paused_dispatches(tmp_path) == []


def test_missing_log_returns_empty(tmp_path):
    # No .context/dispatches.jsonl exists in fresh tmp_path
    assert list_paused_dispatches(tmp_path) == []


def test_malformed_rows_skipped(tmp_path):
    log = tmp_path / ".context" / "dispatches.jsonl"
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(
        "not json\n"
        + json.dumps(_make_dispatch("d-paused", "T-1", "paused",
                                    terminal_event={"type": "pause_requested"})) + "\n"
        + "{also not valid\n"
    )
    out = list_paused_dispatches(tmp_path)
    assert len(out) == 1
    assert out[0]["dispatch_id"] == "d-paused"


# ---------------------------------------------------------------------------
# Field extraction: question / severity / likelihood / state_ref.
# ---------------------------------------------------------------------------


def test_full_terminal_event_fields_extracted(tmp_path):
    _write_log(tmp_path, [_make_dispatch(
        "d-paused", "T-1", "paused",
        terminal_event={
            "type": "pause_requested",
            "question": "Is this safe to delete?",
            "assessment": {"severity": "high", "likelihood": "medium"},
            "state_ref": "lib/auth_legacy.py:42",
        },
    )])
    row = list_paused_dispatches(tmp_path)[0]
    assert row["question"] == "Is this safe to delete?"
    assert row["severity"] == "high"
    assert row["likelihood"] == "medium"
    assert row["state_ref"] == "lib/auth_legacy.py:42"


def test_missing_terminal_event_fields_default_empty(tmp_path):
    _write_log(tmp_path, [_make_dispatch("d-paused", "T-1", "paused",
                                         terminal_event={"type": "pause_requested"})])
    row = list_paused_dispatches(tmp_path)[0]
    assert row["question"] == ""
    assert row["severity"] == ""
    assert row["likelihood"] == ""
    assert row["state_ref"] == ""


def test_no_terminal_event_dispatches_still_surface_with_empty_fields(tmp_path):
    _write_log(tmp_path, [_make_dispatch("d-paused", "T-1", "paused")])
    rows = list_paused_dispatches(tmp_path)
    assert len(rows) == 1
    assert rows[0]["question"] == ""


def test_age_seconds_computed(tmp_path):
    _write_log(tmp_path, [_make_dispatch("d-paused", "T-1", "paused", age_s=300,
                                          terminal_event={"type": "pause_requested"})])
    row = list_paused_dispatches(tmp_path)[0]
    assert 290 <= row["age_seconds"] <= 320  # tolerate test clock jitter


# ---------------------------------------------------------------------------
# Slice-5 forward-compat: retry_of_dispatch_id resolution.
# ---------------------------------------------------------------------------


def test_retry_resolves_paused_dispatch(tmp_path):
    """A paused dispatch with a subsequent retry should NOT surface as awaiting."""
    _write_log(tmp_path, [
        _make_dispatch("d-orig", "T-1", "paused",
                       terminal_event={"type": "pause_requested", "question": "?"}),
        _make_dispatch("d-retry", "T-1", "success",
                       retry_of="d-orig"),
    ])
    assert list_paused_dispatches(tmp_path) == []


def test_unresolved_pause_still_surfaces_alongside_other_retries(tmp_path):
    _write_log(tmp_path, [
        _make_dispatch("d-resolved", "T-1", "paused",
                       terminal_event={"type": "pause_requested", "question": "A?"}),
        _make_dispatch("d-resolved-retry", "T-1", "success", retry_of="d-resolved"),
        _make_dispatch("d-awaiting", "T-2", "paused",
                       terminal_event={"type": "pause_requested", "question": "B?"}),
    ])
    rows = list_paused_dispatches(tmp_path)
    assert [r["dispatch_id"] for r in rows] == ["d-awaiting"]


# ---------------------------------------------------------------------------
# Sort: newest-first by timestamp.
# ---------------------------------------------------------------------------


def test_rows_sorted_newest_first(tmp_path):
    _write_log(tmp_path, [
        _make_dispatch("d-old", "T-1", "paused", age_s=3600,
                       terminal_event={"type": "pause_requested", "question": "old?"}),
        _make_dispatch("d-mid", "T-2", "paused", age_s=600,
                       terminal_event={"type": "pause_requested", "question": "mid?"}),
        _make_dispatch("d-new", "T-3", "paused", age_s=60,
                       terminal_event={"type": "pause_requested", "question": "new?"}),
    ])
    rows = list_paused_dispatches(tmp_path)
    assert [r["dispatch_id"] for r in rows] == ["d-new", "d-mid", "d-old"]


# ---------------------------------------------------------------------------
# Formatting helpers.
# ---------------------------------------------------------------------------


def test_format_age_buckets():
    assert format_age(0) == "<10m"
    assert format_age(500) == "<10m"
    assert format_age(600) == "10m"
    assert format_age(2700) == "45m"
    assert format_age(3600) == "1h"
    assert format_age(7200) == "2h"
    assert format_age(86400) == "1d"
    assert format_age(259200) == "3d"


def test_truncate_short_unchanged():
    assert truncate("hello", 10) == "hello"
    assert truncate("", 10) == ""


def test_truncate_long_with_ellipsis():
    assert truncate("a" * 50, 10) == "aaaaaaa..."
    assert len(truncate("a" * 50, 10)) == 10
