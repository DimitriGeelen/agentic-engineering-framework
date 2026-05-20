"""T-1750 — Regression tests for tools/g064-readiness.py.

Pins the closure-readiness contract:

    1. Empty input + missing file produce sane verdicts/exit codes.
    2. Manual-only runs (e.g. T-1727 backfill at 16:26 UTC) report NOT_READY.
    3. A single natural cron firing is counted but threshold not met.
    4. >= 3 distinct cron-firing dates flips the verdict to READY.
    5. Synthetic T-stress-* dispatches are excluded from counts.
    6. Malformed timestamps are silently skipped, not crashed on.
    7. JSON shape is stable for downstream consumers (Watchtower / fw cmds).

Origin: T-1750 — G-064 status_notes named route_cache.json as the closure
artefact, but that file does not exist on disk. This script reads the real
substrate (.context/dispatches.jsonl) and reports readiness mechanically
so the 2026-05-08 review is paste-and-decide rather than YAML grep.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
TOOL_PATH = REPO_ROOT / "tools" / "g064-readiness.py"


@pytest.fixture(scope="module")
def gauge():
    spec = importlib.util.spec_from_file_location("g064_gauge", TOOL_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _seed(tmp_path: Path, rows: list[dict]) -> Path:
    cdir = tmp_path / ".context"
    cdir.mkdir(parents=True, exist_ok=True)
    path = cdir / "dispatches.jsonl"
    path.write_text("\n".join(json.dumps(r) for r in rows) + ("\n" if rows else ""))
    return path


def _row(task_id: str, ts: str, task_type: str = "escalation-triage") -> dict:
    return {
        "schema_version": 1,
        "ts": ts,
        "dispatch_id": f"id-{task_id}",
        "task_id": task_id,
        "task_type": task_type,
        "worker_kind": "ollama-loop",
    }


# ---------------------------------------------------------------------------
# A1 — empty + missing
# ---------------------------------------------------------------------------


def test_empty_dispatches_reports_not_ready(gauge, tmp_path):
    _seed(tmp_path, [])
    a = gauge.assess([])
    assert a["ready"] is False
    assert a["verdict"] == "NOT_READY"
    assert a["total_dispatches"] == 0
    assert a["cron_firing_dates"] == []


def test_missing_file_returns_exit_2(tmp_path):
    result = subprocess.run(
        ["python3", str(TOOL_PATH), "--dispatches", str(tmp_path / "nope.jsonl")],
        capture_output=True, text=True,
    )
    assert result.returncode == 2


# ---------------------------------------------------------------------------
# A2 — manual-only runs (current state of the world on 2026-05-05)
# ---------------------------------------------------------------------------


def test_manual_only_runs_are_not_ready(gauge):
    rows = [
        _row("T-1014", "2026-05-05T16:26:19+00:00"),
        _row("T-1015", "2026-05-05T16:26:21+00:00"),
        _row("T-1016", "2026-05-05T18:00:00+00:00"),
    ]
    a = gauge.assess(rows)
    assert a["cron_firings"] == 0
    assert a["manual_runs"] == 3
    assert a["ready"] is False


# ---------------------------------------------------------------------------
# A3 — one cron firing counted, threshold not yet met
# ---------------------------------------------------------------------------


def test_single_cron_firing_below_threshold(gauge):
    rows = [
        _row("T-100", "2026-05-06T05:33:14+00:00"),
        _row("T-101", "2026-05-06T05:34:01+00:00"),
        _row("T-200", "2026-05-05T16:26:19+00:00"),
    ]
    a = gauge.assess(rows)
    assert a["cron_firings"] == 2
    assert a["cron_firing_dates"] == ["2026-05-06"]
    assert a["manual_runs"] == 1
    assert a["ready"] is False


# ---------------------------------------------------------------------------
# A4 — >= 3 distinct cron-firing dates flips to READY
# ---------------------------------------------------------------------------


def test_three_distinct_cron_dates_flips_ready(gauge):
    rows = [
        _row("T-A", "2026-05-06T05:33:00+00:00"),
        _row("T-B", "2026-05-07T05:34:00+00:00"),
        _row("T-C", "2026-05-08T05:32:00+00:00"),
        _row("T-MAN", "2026-05-05T16:26:00+00:00"),
    ]
    a = gauge.assess(rows)
    assert a["cron_firings"] == 3
    assert a["cron_firing_dates"] == ["2026-05-06", "2026-05-07", "2026-05-08"]
    assert a["ready"] is True
    assert a["verdict"] == "READY"


def test_window_edge_cases(gauge):
    # 5:28 UTC is exactly at the -5 min edge (inside).
    # 5:38 UTC is exactly at the +5 min edge (inside).
    # 5:39 UTC is outside (manual).
    rows = [
        _row("T-edge-low", "2026-05-06T05:28:00+00:00"),
        _row("T-edge-high", "2026-05-07T05:38:00+00:00"),
        _row("T-out", "2026-05-08T05:39:00+00:00"),
    ]
    a = gauge.assess(rows)
    assert a["cron_firings"] == 2
    assert a["manual_runs"] == 1


# ---------------------------------------------------------------------------
# A5 — synthetic skip (T-1712 contract)
# ---------------------------------------------------------------------------


def test_synthetic_dispatches_are_excluded(gauge):
    rows = [
        _row("T-stress-0", "2026-05-06T05:33:00+00:00"),
        _row("T-stress-1", "2026-05-07T05:33:00+00:00"),
        _row("T-real", "2026-05-08T05:33:00+00:00"),
    ]
    a = gauge.assess(rows)
    assert a["synthetic_skipped"] == 2
    assert a["cron_firings"] == 1
    assert a["ready"] is False, "synthetic-only crons must not satisfy threshold"


# ---------------------------------------------------------------------------
# A6 — malformed inputs do not crash
# ---------------------------------------------------------------------------


def test_malformed_timestamp_silently_skipped(gauge):
    rows = [
        _row("T-bad-1", "not-a-timestamp"),
        _row("T-bad-2", ""),
        {"task_type": "escalation-triage", "task_id": "T-no-ts"},  # no ts field
        _row("T-good", "2026-05-06T05:33:00+00:00"),
    ]
    a = gauge.assess(rows)
    assert a["total_dispatches"] == 1, "only the good row should be counted"
    assert a["cron_firings"] == 1


def test_other_workflow_not_counted(gauge):
    rows = [
        _row("T-other", "2026-05-06T05:33:00+00:00", task_type="prompt-triage"),
        _row("T-default", "2026-05-07T05:33:00+00:00", task_type="default"),
    ]
    a = gauge.assess(rows)
    assert a["total_dispatches"] == 0
    assert a["cron_firings"] == 0


# ---------------------------------------------------------------------------
# A7 — JSON shape stability for downstream consumers
# ---------------------------------------------------------------------------


def test_json_shape_pinned(gauge, tmp_path):
    path = _seed(tmp_path, [
        _row("T-100", "2026-05-06T05:33:00+00:00"),
        _row("T-200", "2026-05-05T16:26:00+00:00"),
    ])
    result = subprocess.run(
        ["python3", str(TOOL_PATH), "--json", "--dispatches", str(path)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    required_keys = {
        "workflow", "total_dispatches", "cron_firings", "manual_runs",
        "synthetic_skipped", "cron_firing_dates", "manual_run_dates",
        "earliest_ts", "latest_ts", "closure_threshold_dates",
        "cron_window", "ready", "verdict",
    }
    missing = required_keys - set(data.keys())
    assert not missing, f"JSON output missing keys: {missing}"
    assert data["workflow"] == "escalation-triage"
    assert isinstance(data["ready"], bool)
    assert data["verdict"] in {"READY", "NOT_READY"}


# ---------------------------------------------------------------------------
# Strict-mode exit codes
# ---------------------------------------------------------------------------


def test_strict_exits_1_when_not_ready(tmp_path):
    path = _seed(tmp_path, [
        _row("T-100", "2026-05-05T16:26:00+00:00"),
    ])
    result = subprocess.run(
        ["python3", str(TOOL_PATH), "--strict", "--dispatches", str(path)],
        capture_output=True, text=True,
    )
    assert result.returncode == 1


def test_strict_exits_0_when_ready(tmp_path):
    path = _seed(tmp_path, [
        _row("T-A", "2026-05-06T05:33:00+00:00"),
        _row("T-B", "2026-05-07T05:33:00+00:00"),
        _row("T-C", "2026-05-08T05:33:00+00:00"),
    ])
    result = subprocess.run(
        ["python3", str(TOOL_PATH), "--strict", "--dispatches", str(path)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0


def test_default_no_strict_returns_0_even_when_not_ready(tmp_path):
    path = _seed(tmp_path, [
        _row("T-100", "2026-05-05T16:26:00+00:00"),
    ])
    result = subprocess.run(
        ["python3", str(TOOL_PATH), "--dispatches", str(path)],
        capture_output=True, text=True,
    )
    assert result.returncode == 0


# ---------------------------------------------------------------------------
# T-1952 — v0.5 LATEST fallback (idempotency-saturation case)
# ---------------------------------------------------------------------------


def test_v0_5_latest_missing_backward_compat(gauge):
    """No v0.5 LATEST file → old behaviour, no new fields populated."""
    a = gauge.assess([], v0_5_latest=None)
    assert a["v0_5_last_generated"] is None
    assert a["v0_5_last_dispatched"] is None
    assert a["v0_5_last_skipped_idempotent"] is None
    assert a["v0_5_date_added_to_cron"] is False
    assert a["cron_firing_dates"] == []


def test_v0_5_latest_in_window_adds_cron_date(gauge):
    """v0.5 LATEST with `generated` ts in cron window → date counted."""
    v0_5 = {
        "generated": "2026-05-06T05:33:01+00:00",
        "dispatched": 0,
        "skipped_idempotent": 83,
    }
    a = gauge.assess([], v0_5_latest=v0_5)
    assert a["v0_5_last_generated"] == "2026-05-06T05:33:01+00:00"
    assert a["v0_5_last_dispatched"] == 0
    assert a["v0_5_last_skipped_idempotent"] == 83
    assert a["v0_5_date_added_to_cron"] is True
    assert a["cron_firing_dates"] == ["2026-05-06"]


def test_v0_5_latest_outside_window_does_not_add(gauge):
    """v0.5 LATEST with ts outside cron window → not counted."""
    v0_5 = {
        "generated": "2026-05-06T16:26:00+00:00",  # manual run
        "dispatched": 0,
        "skipped_idempotent": 83,
    }
    a = gauge.assess([], v0_5_latest=v0_5)
    assert a["v0_5_last_generated"] == "2026-05-06T16:26:00+00:00"
    assert a["v0_5_date_added_to_cron"] is False
    assert a["cron_firing_dates"] == []


def test_v0_5_latest_does_not_double_count(gauge):
    """v0.5 LATEST date already in cron_firing_dates via dispatch row → no double."""
    rows = [_row("T-A", "2026-05-06T05:33:00+00:00")]  # adds 2026-05-06
    v0_5 = {
        "generated": "2026-05-06T05:34:00+00:00",  # same date, in window
        "dispatched": 0,
        "skipped_idempotent": 83,
    }
    a = gauge.assess(rows, v0_5_latest=v0_5)
    assert a["cron_firing_dates"] == ["2026-05-06"]  # single entry
    assert a["v0_5_date_added_to_cron"] is False  # not newly added


def test_v0_5_latest_malformed_does_not_crash(gauge):
    """v0.5 LATEST with missing or malformed `generated` → graceful fallback."""
    # Empty dict
    a = gauge.assess([], v0_5_latest={})
    assert a["v0_5_last_generated"] is None
    assert a["v0_5_date_added_to_cron"] is False
    # Malformed ts
    a = gauge.assess([], v0_5_latest={"generated": "not-a-ts"})
    assert a["v0_5_last_generated"] == "not-a-ts"
    assert a["v0_5_date_added_to_cron"] is False


def test_read_v0_5_latest_helper(gauge, tmp_path):
    """_read_v0_5_latest parses minimal yaml fields without pyyaml."""
    p = tmp_path / "v0_5.yaml"
    p.write_text(
        "generated: '2026-05-20T03:33:01.952466+00:00'\n"
        "dispatched: 0\n"
        "skipped_idempotent: 83\n"
        "model: claude-3-5-sonnet-hermes3\n"
    )
    result = gauge._read_v0_5_latest(p)
    assert result is not None
    assert result["generated"] == "2026-05-20T03:33:01.952466+00:00"
    assert result["dispatched"] == 0
    assert result["skipped_idempotent"] == 83


def test_read_v0_5_latest_missing_file(gauge, tmp_path):
    """Missing file → None, no crash."""
    result = gauge._read_v0_5_latest(tmp_path / "nope.yaml")
    assert result is None
    assert gauge._read_v0_5_latest(None) is None


def test_render_human_shows_saturation_note(gauge):
    """When dispatched=0 + skipped_idempotent>0, render the saturation hint."""
    v0_5 = {
        "generated": "2026-05-06T05:33:01+00:00",
        "dispatched": 0,
        "skipped_idempotent": 83,
    }
    a = gauge.assess([], v0_5_latest=v0_5)
    text = gauge.render_human(a)
    assert "v0.5 LATEST:" in text
    assert "idempotency saturation" in text
    assert "Avoid manual re-runs" in text
