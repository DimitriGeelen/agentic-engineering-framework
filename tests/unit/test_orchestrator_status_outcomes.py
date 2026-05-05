"""T-1749 — Regression tests for `fw orchestrator status --outcomes`.

Pins the substrate observability contract:

    1. Default `fw orchestrator status` is unchanged (no regression on T-1699
       output structure).
    2. `--outcomes` adds an "Outcome quality (by task_type)" section that
       aggregates outcomes by their shape — verdict-style and
       verification-style are both surfaced.
    3. `--outcomes --json` exposes `by_task_type_outcomes` at the top level.
    4. Empty/synthetic-only outcome sets render gracefully.
    5. The aggregator routes by shape, not hardcoded evaluator name —
       new evaluators that emit `verdict` or `verification_passed`/`ac_satisfied`
       fields surface automatically.

Origin: T-1748 ship validation required hand-running yaml.safe_load against
.context/working/escalation-drift-LATEST-v0.5.yaml because the substrate's
own status command surfaces only dispatch counts. This test+command move
outcome quality to where it belongs — the orchestrator status report.
"""

from __future__ import annotations

import json
import os
import subprocess
import textwrap
from pathlib import Path

import pytest

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
# A3 — default output unchanged
# ---------------------------------------------------------------------------


def test_default_status_does_not_show_outcome_quality(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100", "task_type": "X", "worker_kind": "ollama-loop"}
    ], [
        {"dispatch_id": "d1", "task_id": "T-100",
         "outcome": {"evaluator": "default", "verification_passed": True, "ac_satisfied": True}}
    ])
    result = _run_status(tmp_path)
    assert result.returncode == 0, result.stderr
    assert "Outcome quality" not in result.stdout
    # Default headline content still present.
    assert "Dispatch substrate" in result.stdout
    assert "By task_type" in result.stdout


# ---------------------------------------------------------------------------
# A1 — --outcomes adds the Outcome quality section
# ---------------------------------------------------------------------------


def test_outcomes_flag_renders_verdict_style(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": f"d{i}", "task_id": f"T-{i}",
         "task_type": "escalation-triage", "worker_kind": "ollama-loop"}
        for i in range(5)
    ], [
        {"dispatch_id": "d0", "task_id": "T-0",
         "outcome": {"evaluator": "escalation-scan-v0.5", "verdict": "real_symptom_fix"}},
        {"dispatch_id": "d1", "task_id": "T-1",
         "outcome": {"evaluator": "escalation-scan-v0.5", "verdict": "false_positive"}},
        {"dispatch_id": "d2", "task_id": "T-2",
         "outcome": {"evaluator": "escalation-scan-v0.5", "verdict": "false_positive"}},
        {"dispatch_id": "d3", "task_id": "T-3",
         "outcome": {"evaluator": "escalation-scan-v0.5", "verdict": "PARSE-FAIL"}},
        {"dispatch_id": "d4", "task_id": "T-4",
         "outcome": {"evaluator": "escalation-scan-v0.5", "verdict": "defer"}},
    ])
    result = _run_status(tmp_path, "--outcomes")
    assert result.returncode == 0, result.stderr
    assert "Outcome quality" in result.stdout
    assert "escalation-triage" in result.stdout
    # All four verdict lines visible.
    assert "real_symptom_fix" in result.stdout
    assert "false_positive" in result.stdout
    assert "PARSE-FAIL" in result.stdout
    assert "defer" in result.stdout
    # false_positive should be the most common verdict.
    out = result.stdout
    assert out.index("false_positive") < out.index("real_symptom_fix")


def test_outcomes_flag_renders_verification_style(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100",
         "task_type": "build", "worker_kind": "Task"},
        {"dispatch_id": "d2", "task_id": "T-101",
         "task_type": "build", "worker_kind": "Task"},
    ], [
        {"dispatch_id": "d1", "task_id": "T-100",
         "outcome": {"evaluator": "default", "verification_passed": True, "ac_satisfied": True}},
        {"dispatch_id": "d2", "task_id": "T-101",
         "outcome": {"evaluator": "default", "verification_passed": False, "ac_satisfied": True}},
    ])
    result = _run_status(tmp_path, "--outcomes")
    assert result.returncode == 0, result.stderr
    assert "Outcome quality" in result.stdout
    assert "verification_passed" in result.stdout
    assert "True=1" in result.stdout
    assert "False=1" in result.stdout
    assert "ac_satisfied" in result.stdout


# ---------------------------------------------------------------------------
# A5 — shape-routed, both shapes visible together
# ---------------------------------------------------------------------------


def test_outcomes_flag_routes_by_shape_not_evaluator(tmp_path):
    """Two task_types with different evaluator shapes must both surface."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100",
         "task_type": "escalation-triage", "worker_kind": "ollama-loop"},
        {"dispatch_id": "d2", "task_id": "T-101",
         "task_type": "build", "worker_kind": "Task"},
        {"dispatch_id": "d3", "task_id": "T-102",
         "task_type": "novel-evaluator", "worker_kind": "Task"},
    ], [
        {"dispatch_id": "d1", "task_id": "T-100",
         "outcome": {"evaluator": "escalation-scan-v0.5", "verdict": "false_positive"}},
        {"dispatch_id": "d2", "task_id": "T-101",
         "outcome": {"evaluator": "default", "verification_passed": True}},
        # Novel evaluator — emits a verdict field, no hardcoding required.
        {"dispatch_id": "d3", "task_id": "T-102",
         "outcome": {"evaluator": "future-evaluator", "verdict": "approved"}},
    ])
    result = _run_status(tmp_path, "--outcomes")
    assert result.returncode == 0, result.stderr
    assert "escalation-triage" in result.stdout
    assert "build" in result.stdout
    assert "novel-evaluator" in result.stdout
    # Novel evaluator's verdict field is surfaced even though the evaluator
    # name is unknown to the aggregator.
    assert "approved" in result.stdout


# ---------------------------------------------------------------------------
# A2 — JSON output exposes by_task_type_outcomes
# ---------------------------------------------------------------------------


def test_outcomes_json_exposes_aggregation(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100",
         "task_type": "escalation-triage", "worker_kind": "ollama-loop"},
    ], [
        {"dispatch_id": "d1", "task_id": "T-100",
         "outcome": {"evaluator": "escalation-scan-v0.5", "verdict": "real_symptom_fix"}},
    ])
    result = _run_status(tmp_path, "--outcomes", "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert "by_task_type_outcomes" in data
    bucket = data["by_task_type_outcomes"]["escalation-triage"]
    assert bucket["verdicts"]["real_symptom_fix"] == 1
    assert bucket["evaluators"]["escalation-scan-v0.5"] == 1
    assert bucket["outcome_total"] == 1


def test_default_json_does_not_have_outcomes_key(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100",
         "task_type": "X", "worker_kind": "Task"}
    ], [
        {"dispatch_id": "d1", "task_id": "T-100",
         "outcome": {"evaluator": "default", "verification_passed": True}}
    ])
    result = _run_status(tmp_path, "--json")
    assert result.returncode == 0, result.stderr
    data = json.loads(result.stdout)
    assert "by_task_type_outcomes" not in data


# ---------------------------------------------------------------------------
# A4 — graceful handling of empty and synthetic-only outcomes
# ---------------------------------------------------------------------------


def test_outcomes_flag_handles_empty_outcomes(tmp_path):
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-100",
         "task_type": "escalation-triage", "worker_kind": "ollama-loop"}
    ], [])
    result = _run_status(tmp_path, "--outcomes")
    assert result.returncode == 0, result.stderr
    # Empty outcomes → "no outcomes captured yet" or empty section.
    assert "Outcome quality" in result.stdout
    assert "no outcomes captured yet" in result.stdout


def test_outcomes_flag_skips_synthetic_dispatches(tmp_path):
    """Synthetic T-stress-* dispatches must not pollute the per-task-type
    outcome view (T-1712 contract — synthetic excluded from headline)."""
    _seed_jsonl(tmp_path, [
        {"dispatch_id": "d1", "task_id": "T-stress-1",
         "task_type": "stress", "worker_kind": "Task"},
        {"dispatch_id": "d2", "task_id": "T-100",
         "task_type": "real", "worker_kind": "Task"},
    ], [
        {"dispatch_id": "d1", "task_id": "T-stress-1",
         "outcome": {"evaluator": "synthetic", "verdict": "synthetic_value"}},
        {"dispatch_id": "d2", "task_id": "T-100",
         "outcome": {"evaluator": "default", "verification_passed": True}},
    ])
    result = _run_status(tmp_path, "--outcomes")
    assert result.returncode == 0, result.stderr
    # Slice out the Outcome quality section — "stress" appears in the headline
    # ("Synthetic: 1 (T-stress-*)") which is fine; the contract is that synthetic
    # task_types do NOT show up in the per-task-type outcome aggregation.
    section = result.stdout.split("Outcome quality")[-1] if "Outcome quality" in result.stdout else ""
    assert "real" in section
    assert "synthetic_value" not in section
    # The synthetic task_type "stress" must not appear as a row in the
    # outcome aggregation. Match the row format ("  stress —") not the bare word.
    assert "  stress —" not in section
    assert "  stress " not in section.replace("  stress —", "")
