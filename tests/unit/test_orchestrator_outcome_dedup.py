"""T-1757 — Regression test for orchestrator status outcome dedup.

Pre-fix: `_aggregate_outcomes_by_task_type` counted every outcome row, so when a
dispatch had multiple evaluations (e.g. re-runs, or T-1756's append-only replays),
the rollup double-counted them. PARSE-FAIL stuck at 4.5% even after T-1756
back-propagated 8 corrective outcomes.

Post-fix: keep only the latest outcome per dispatch_id (by ts), so replay rows
supersede their originals in the rollup. Substrate stays append-only — the rollup
honors supersession without mutating the audit trail.

The aggregator is inlined in bin/fw inside a python heredoc, so this test
exercises it via subprocess rather than direct import.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
FW = REPO_ROOT / "bin" / "fw"


def _run_status(cwd: Path) -> dict:
    """Run `fw orchestrator status --outcomes --json` in cwd and parse."""
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(cwd)
    env["FRAMEWORK_ROOT"] = str(REPO_ROOT)
    proc = subprocess.run(
        ["bash", str(FW), "orchestrator", "status", "--outcomes", "--json"],
        capture_output=True, text=True, cwd=str(cwd), env=env, timeout=30,
    )
    assert proc.returncode == 0, f"fw failed: {proc.stderr}"
    # The fw script prints other lines before JSON; isolate the JSON object.
    txt = proc.stdout.strip()
    # Find the start of the JSON (first '{' on its own line is fine here).
    start = txt.find("{")
    if start == -1:
        return {}
    return json.loads(txt[start:])


@pytest.fixture
def project(tmp_path):
    """Build a minimal project tree with substrate files."""
    (tmp_path / ".context").mkdir()
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir(parents=True)
    return tmp_path


def _write_substrate(project_root: Path, dispatches: list[dict], outcomes: list[dict]) -> None:
    with (project_root / ".context" / "dispatches.jsonl").open("w") as f:
        for d in dispatches:
            f.write(json.dumps(d) + "\n")
    with (project_root / ".context" / "dispatch-outcomes.jsonl").open("w") as f:
        for o in outcomes:
            f.write(json.dumps(o) + "\n")


def test_dedup_replay_supersedes_original(project):
    """A later (replay) outcome for the same dispatch_id wins the rollup."""
    dispatches = [
        {"dispatch_id": "d-a", "task_type": "escalation-triage", "ts": "2026-05-05T10:00:00Z"},
    ]
    outcomes = [
        # Original: PARSE-FAIL
        {"dispatch_id": "d-a", "ts": "2026-05-05T10:01:00Z",
         "outcome": {"evaluator": "escalation-scan-v0.5", "verdict": "PARSE-FAIL"}},
        # Replay (later ts): false_positive
        {"dispatch_id": "d-a", "ts": "2026-05-05T11:00:00Z",
         "outcome": {"evaluator": "escalation-scan-v0.5-replay", "verdict": "false_positive"}},
    ]
    _write_substrate(project, dispatches, outcomes)
    stats = _run_status(project)
    by_type = stats.get("by_task_type_outcomes", {})
    bucket = by_type.get("escalation-triage", {})
    assert bucket.get("outcome_total") == 1, f"expected 1, got {bucket.get('outcome_total')}"
    assert bucket.get("verdicts", {}).get("false_positive") == 1
    assert bucket.get("verdicts", {}).get("PARSE-FAIL", 0) == 0


def test_no_replay_counts_originals_unchanged(project):
    """When there are no duplicates, every outcome counts once."""
    dispatches = [
        {"dispatch_id": "d-a", "task_type": "escalation-triage", "ts": "2026-05-05T10:00:00Z"},
        {"dispatch_id": "d-b", "task_type": "escalation-triage", "ts": "2026-05-05T10:01:00Z"},
        {"dispatch_id": "d-c", "task_type": "escalation-triage", "ts": "2026-05-05T10:02:00Z"},
    ]
    outcomes = [
        {"dispatch_id": "d-a", "ts": "2026-05-05T10:10:00Z",
         "outcome": {"evaluator": "escalation-scan-v0.5", "verdict": "false_positive"}},
        {"dispatch_id": "d-b", "ts": "2026-05-05T10:11:00Z",
         "outcome": {"evaluator": "escalation-scan-v0.5", "verdict": "real_symptom_fix"}},
        {"dispatch_id": "d-c", "ts": "2026-05-05T10:12:00Z",
         "outcome": {"evaluator": "escalation-scan-v0.5", "verdict": "PARSE-FAIL"}},
    ]
    _write_substrate(project, dispatches, outcomes)
    stats = _run_status(project)
    bucket = stats.get("by_task_type_outcomes", {}).get("escalation-triage", {})
    assert bucket.get("outcome_total") == 3
    assert bucket.get("verdicts", {}).get("false_positive") == 1
    assert bucket.get("verdicts", {}).get("real_symptom_fix") == 1
    assert bucket.get("verdicts", {}).get("PARSE-FAIL") == 1


def test_orphan_outcome_is_skipped(project):
    """Outcome whose dispatch_id is unknown to dispatches.jsonl is skipped."""
    dispatches = [
        {"dispatch_id": "d-a", "task_type": "escalation-triage", "ts": "2026-05-05T10:00:00Z"},
    ]
    outcomes = [
        {"dispatch_id": "d-a", "ts": "2026-05-05T10:10:00Z",
         "outcome": {"evaluator": "default", "verification_passed": True, "ac_satisfied": True}},
        # Orphan — no matching dispatch.
        {"dispatch_id": "d-orphan", "ts": "2026-05-05T10:11:00Z",
         "outcome": {"evaluator": "default", "verification_passed": False, "ac_satisfied": False}},
    ]
    _write_substrate(project, dispatches, outcomes)
    stats = _run_status(project)
    bucket = stats.get("by_task_type_outcomes", {}).get("escalation-triage", {})
    assert bucket.get("outcome_total") == 1
    assert bucket.get("verification_passed", {}).get("True") == 1
    assert bucket.get("verification_passed", {}).get("False", 0) == 0


def test_three_outcomes_same_dispatch_keeps_latest(project):
    """Three outcomes for one dispatch — only the latest wins."""
    dispatches = [
        {"dispatch_id": "d-a", "task_type": "escalation-triage", "ts": "2026-05-05T10:00:00Z"},
    ]
    outcomes = [
        {"dispatch_id": "d-a", "ts": "2026-05-05T10:01:00Z",
         "outcome": {"evaluator": "v1", "verdict": "PARSE-FAIL"}},
        {"dispatch_id": "d-a", "ts": "2026-05-05T10:02:00Z",
         "outcome": {"evaluator": "v2", "verdict": "false_positive"}},
        {"dispatch_id": "d-a", "ts": "2026-05-05T10:03:00Z",
         "outcome": {"evaluator": "v3", "verdict": "real_symptom_fix"}},
    ]
    _write_substrate(project, dispatches, outcomes)
    stats = _run_status(project)
    bucket = stats.get("by_task_type_outcomes", {}).get("escalation-triage", {})
    assert bucket.get("outcome_total") == 1
    assert bucket.get("verdicts", {}).get("real_symptom_fix") == 1
    assert bucket.get("evaluators", {}).get("v3") == 1
    assert bucket.get("evaluators", {}).get("v1", 0) == 0
    assert bucket.get("evaluators", {}).get("v2", 0) == 0
