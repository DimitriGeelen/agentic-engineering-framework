"""Unit tests for the BVP estimator (T-1922, arc-006).

Coverage:
  - Determinism: same task body → same scores (R3, ship-blocking)
  - M3 v2-delta: skip when confirmed differs <2; append when ≥2
  - Sovereignty: never writes to bvp_scores: (only bvp_scores_proposed:)
  - Frontmatter preservation across the write cycle
  - Per-driver scoring contract: returns int 0-5 with evidence list

Calibration against rubric worked examples is covered by the A3 report
(`docs/reports/T-1922-a3-measurement.md`), not these tests — calibration
is policy not invariant.
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

import pytest

# Make the estimator importable. PROJECT_ROOT is the framework repo root
# (this file lives at $PROJECT_ROOT/tests/unit/test_bvp_estimator.py).
PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "agents" / "termlink" / "bvp-estimator"))
os.environ.setdefault("PROJECT_ROOT", str(PROJECT_ROOT))
os.environ.setdefault("FRAMEWORK_ROOT", str(PROJECT_ROOT))

import estimator  # noqa: E402


# ----------------------------------------------------------------- fixtures

DRIVERS = {"D1": 9, "D2": 7, "D3": 5, "D4": 3}


def _make_task(tmp_path: Path, body: str, fm_extra: dict | None = None) -> Path:
    """Write a synthetic task file and return its path."""
    fm_extra = fm_extra or {}
    fm_lines = [
        "id: T-9999",
        "name: \"Synthetic test task\"",
        "status: started-work",
        "workflow_type: build",
        "owner: agent",
        "horizon: now",
    ]
    tags = fm_extra.get("tags") or []
    if tags:
        fm_lines.append(f"tags: [{', '.join(tags)}]")
    for k, v in fm_extra.items():
        if k == "tags":
            continue
        fm_lines.append(f"{k}: {v}")
    path = tmp_path / "T-9999-synthetic.md"
    path.write_text("---\n" + "\n".join(fm_lines) + "\n---\n\n" + body + "\n")
    return path


# ----------------------------------------------------------- per-driver shape

def test_each_driver_returns_int_0_to_5():
    fm = {"workflow_type": "build", "tags": []}
    body = ""
    for handler in (
        estimator.score_d1_antifragility,
        estimator.score_d2_reliability,
        estimator.score_d3_usability,
        estimator.score_d4_portability,
    ):
        score, ev = handler(fm, body, [])
        assert isinstance(score, int)
        assert 0 <= score <= 5
        assert isinstance(ev, list)
        assert any(e.startswith("→") for e in ev), "evidence should include a → arrow line"


def test_empty_body_scores_zero_on_all_drivers():
    fm = {"workflow_type": "build", "tags": []}
    for handler in (
        estimator.score_d1_antifragility,
        estimator.score_d2_reliability,
        estimator.score_d3_usability,
        estimator.score_d4_portability,
    ):
        score, _ = handler(fm, "", [])
        assert score == 0


# -------------------------------------------------- d1 signal escalation

def test_d1_structural_gate_keyword_scores_4():
    """A body mentioning a PreToolUse hook should escalate D1 to 4."""
    fm = {"workflow_type": "build", "tags": []}
    body = "Added a PreToolUse hook that refuses --status work-completed for unscored tasks."
    score, _ = estimator.score_d1_antifragility(fm, body, [])
    assert score == 4


def test_d1_novel_mechanism_tag_plus_class_body_scores_5():
    fm = {"workflow_type": "build", "tags": ["novel-mechanism"]}
    body = "Introduces a new sovereignty boundary at policy-edit time."
    score, ev = estimator.score_d1_antifragility(fm, body, ["novel-mechanism"])
    assert score == 5


def test_d1_bug_with_learning_ref_scores_2():
    fm = {"workflow_type": "build", "tags": ["fix"]}
    body = "Fix the bug in update-task.sh (L-291)."
    score, _ = estimator.score_d1_antifragility(fm, body, ["fix"])
    assert score == 2


# -------------------------------------------------- d2 silent-failure class

def test_d2_silent_class_keyword_scores_5():
    fm = {"workflow_type": "build", "tags": []}
    body = "Removes the silent-failure class where SIGPIPE caused exit 141 with no message."
    score, _ = estimator.score_d2_reliability(fm, body, [])
    assert score == 5


def test_d2_fw_doctor_keyword_scores_4():
    fm = {"workflow_type": "build", "tags": []}
    body = "Added an fw doctor check that surfaces cron-registry drift."
    score, _ = estimator.score_d2_reliability(fm, body, [])
    assert score == 4


# --------------------------------------- f-recall / f-orch (T-2168)

def test_f_recall_empty_scores_zero():
    """L0 — no durable artifact, no signal anywhere."""
    score, _ = estimator.score_f_recall({}, "", [])
    assert score == 0


def test_f_recall_layer_substrate_scores_5():
    """L5 — touches the retrieval/synthesis layer itself."""
    fm = {"workflow_type": "build", "components": ["lib/recall.sh"]}
    body = "Improves the retrieval engine with selective recall."
    score, ev = estimator.score_f_recall(fm, body, [])
    assert score == 5
    assert any("retrieval-layer" in e for e in ev)


def test_f_recall_recallable_artifact_scores_3():
    """L3 — writes a `[[memory-slug]]` link / fw recall mention."""
    fm = {"workflow_type": "build", "components": []}
    body = "Records the pattern as [[feedback-handoff-url-per-class]] for fw recall."
    score, _ = estimator.score_f_recall(fm, body, [])
    assert score == 3


def test_f_orch_empty_scores_zero():
    """L0 — primary-agent serial, no routable surface."""
    score, _ = estimator.score_f_orch({}, "", [])
    assert score == 0


def test_f_orch_typed_io_scores_3():
    """L3 — clean typed I/O contract / decision gate."""
    fm = {"workflow_type": "build", "components": []}
    body = "Adds a typed I/O contract: dispatch envelope schema for fw bus post."
    score, _ = estimator.score_f_orch(fm, body, [])
    assert score == 3


def test_f_orch_rubric_routable_scores_4():
    """L4 — rubric-scored work routable to TermLink worker."""
    fm = {"workflow_type": "build", "components": ["agents/termlink/bvp-estimator/estimator.py"]}
    body = "BVP estimator now rubric-scored, routable to peer responder via fw bus post."
    score, _ = estimator.score_f_orch(fm, body, [])
    assert score == 4


def test_f_orch_substrate_expand_scores_5():
    """L5 — expands the orchestration substrate itself."""
    fm = {"workflow_type": "build", "components": ["agents/orchestrator/orchestrator.sh", "lib/peer/responder.sh"]}
    body = "Expands the orchestration substrate with a new worker class."
    score, _ = estimator.score_f_orch(fm, body, [])
    assert score == 5


def test_f_orch_refuse_wrap_without_substrate():
    """R5 anti-Goodhart: 'delegate this' without substrate touch → 0."""
    fm = {"workflow_type": "build", "components": ["docs/notes.md"]}
    body = "Suggests we delegate this work to a TermLink worker — easy win."
    score, ev = estimator.score_f_orch(fm, body, [])
    assert score == 0
    assert any("refuse" in e for e in ev)


def test_estimate_task_routes_f_recall_to_dedicated_scorer(tmp_path):
    """estimate_task wires F-RECALL into the new dedicated handler."""
    fm_extra = {"components": "[CLAUDE.md]"}  # serialise as YAML list
    body = "Sync rule into CLAUDE.md closing the capture loop."
    path = _make_task(tmp_path, body, fm_extra)
    drivers = {"D1": 9, "F-RECALL": 6, "F-ORCH": 5}
    result = estimator.estimate_task(path, drivers)
    # F-RECALL should be 4 (instruction-sync), not 0 (no driver-id mention) or 1
    # (which is what the placeholder score_free_driver would have produced if
    # called for "F-RECALL").
    assert result["scores"]["F-RECALL"] == 4
    assert any("instruction-sync" in e for e in result["evidence"]["F-RECALL"])


def test_unknown_free_driver_falls_back_to_generic_score_free_driver(tmp_path):
    """Generic fallback retained for any active free driver without dedicated scorer."""
    body = "A task mentioning F-NEWHYPOTHETICAL once in its body."
    path = _make_task(tmp_path, body)
    drivers = {"D1": 9, "F-NEWHYPOTHETICAL": 3}
    result = estimator.estimate_task(path, drivers)
    # Body says "F-NEWHYPOTHETICAL" once → generic scores 1.
    assert result["scores"]["F-NEWHYPOTHETICAL"] in (1, 2)
    assert any("F-NEWHYPOTHETICAL" in e for e in result["evidence"]["F-NEWHYPOTHETICAL"])


# ----------------------------------------------- audit_severity (T-2354, T-2352 S2)

def test_audit_severity_fail_scores_5():
    """A FAIL audit-finding task scores the top triage band."""
    score, ev = estimator.score_audit_severity({"audit_severity": "fail"}, "", [])
    assert score == 5
    assert any("audit_severity=fail" in e for e in ev)


def test_audit_severity_warn_scores_4():
    """A WARN audit-finding task scores the next band, below FAIL."""
    score, ev = estimator.score_audit_severity({"audit_severity": "warn"}, "", [])
    assert score == 4
    assert any("audit_severity=warn" in e for e in ev)


def test_audit_severity_absent_scores_0():
    """A routine task (no audit_severity field) scores 0 / no-signal."""
    score, ev = estimator.score_audit_severity({}, "some routine body", [])
    assert score == 0
    assert any("absent" in e for e in ev)


def test_audit_severity_unrecognised_value_scores_0():
    """An unrecognised severity value is not a triage boost."""
    score, _ = estimator.score_audit_severity({"audit_severity": "info"}, "", [])
    assert score == 0


def test_audit_severity_case_insensitive():
    """Field value is normalised — FAIL / Fail / fail all score 5."""
    assert estimator.score_audit_severity({"audit_severity": "FAIL"}, "", [])[0] == 5
    assert estimator.score_audit_severity({"audit_severity": "Warn"}, "", [])[0] == 4


def test_estimate_task_routes_audit_severity_to_dedicated_scorer(tmp_path):
    """AC #2/#5: estimate_task dispatches the audit_severity driver to the
    dedicated handler, and a FAIL finding outranks an otherwise-equal routine
    task on the same active driver set."""
    drivers = {"D1": 9, "audit_severity": 6}

    fail_dir = tmp_path / "fail"
    routine_dir = tmp_path / "routine"
    fail_dir.mkdir()
    routine_dir.mkdir()
    fail_path = _make_task(fail_dir, "Audit fixing body.", {"audit_severity": "fail"})
    routine_path = _make_task(routine_dir, "Audit fixing body.")

    fail_res = estimator.estimate_task(fail_path, drivers)
    routine_res = estimator.estimate_task(routine_path, drivers)

    # Handler fired (not the generic score_free_driver fallback): FAIL → 5.
    assert fail_res["scores"]["audit_severity"] == 5
    assert routine_res["scores"]["audit_severity"] == 0
    # Live-rank check: identical bodies, only the audit_severity field differs,
    # so the FAIL task's weighted audit_severity contribution (5×6) lifts it
    # strictly above the routine task's (0×6).
    fail_contrib = fail_res["scores"]["audit_severity"] * drivers["audit_severity"]
    routine_contrib = routine_res["scores"]["audit_severity"] * drivers["audit_severity"]
    assert fail_contrib > routine_contrib


def test_f_recall_rationale_is_informative_not_naive_count():
    """AC #4: rationale cites the SIGNAL, not a string-count placeholder."""
    fm = {"workflow_type": "build", "components": ["CLAUDE.md"]}
    body = "Adds an auto-sync rule into CLAUDE.md."
    score, ev = estimator.score_f_recall(fm, body, [])
    # Rationale must not look like the old placeholder
    # "body/tag hits for 'F-RECALL': 1" — it should cite a structural signal.
    assert score == 4
    assert not any("body/tag hits for 'F-RECALL'" in e for e in ev)
    assert any("instruction-sync" in e for e in ev)


# ----------------------------------------------------- determinism contract

def test_same_input_same_output(tmp_path):
    """R3 ship-blocking AC: deterministic by construction."""
    body = "Added a PreToolUse hook with audit FAIL on drift. Cross-machine semantics."
    path = _make_task(tmp_path, body)
    r1 = estimator.estimate_task(path, DRIVERS)
    r2 = estimator.estimate_task(path, DRIVERS)
    r3 = estimator.estimate_task(path, DRIVERS)
    assert r1["scores"] == r2["scores"] == r3["scores"]


def test_determinism_holds_with_random_body(tmp_path):
    """Throw a varied body at the engine — output must still be repeatable."""
    body = """## Context

This is a build task that adds a fw doctor check, a regression test in
tests/playwright/, and removes a hard-coded port. The PreToolUse hook
refuses operations when the rubric drifts. Cross-machine semantics
preserved. L-403 reference. Recommendation block format.
"""
    path = _make_task(tmp_path, body)
    runs = [estimator.estimate_task(path, DRIVERS) for _ in range(10)]
    base = runs[0]["scores"]
    for r in runs[1:]:
        assert r["scores"] == base


# -------------------------------------------------- m3 v2-delta semantics

def test_v2_delta_skip_when_confirmed_within_1():
    proposed = {"D1": 4, "D2": 3, "D3": 0, "D4": 0}
    confirmed = {"D1": 4, "D2": 3, "D3": 0, "D4": 1}
    assert estimator._v2_delta_should_skip(proposed, confirmed) is True


def test_v2_delta_no_skip_when_any_driver_delta_2():
    proposed = {"D1": 4, "D2": 3, "D3": 0, "D4": 0}
    confirmed = {"D1": 4, "D2": 1, "D3": 0, "D4": 0}  # D2 differs by 2
    assert estimator._v2_delta_should_skip(proposed, confirmed) is False


def test_v2_delta_no_skip_when_no_confirmed():
    proposed = {"D1": 4, "D2": 3, "D3": 0, "D4": 0}
    assert estimator._v2_delta_should_skip(proposed, {}) is False
    assert estimator._v2_delta_should_skip(proposed, None) is False


# --------------------------------------------------- write contract

def test_write_creates_bvp_scores_proposed(tmp_path):
    """Writing must populate frontmatter's bvp_scores_proposed: as a list of dicts."""
    body = "Added a PreToolUse hook."
    path = _make_task(tmp_path, body)
    result = estimator.estimate_task(path, DRIVERS)
    wrote, reason = estimator.write_proposed(
        path, result["scores"], result["evidence"],
        result["rubric_sha"], dry_run=False
    )
    assert wrote is True, reason
    fm, _ = estimator.parse_task(path)
    assert isinstance(fm.get("bvp_scores_proposed"), list)
    latest = fm["bvp_scores_proposed"][-1]
    assert latest["estimator"] == estimator.ESTIMATOR_ID
    assert set(latest["scores"].keys()) == {"D1", "D2", "D3", "D4"}
    assert "rubric_sha" in latest


def test_write_never_touches_confirmed_scores(tmp_path):
    """Sovereignty: estimator must NOT mutate bvp_scores: even when present."""
    body = "Added a PreToolUse hook."
    path = _make_task(tmp_path, body)
    # Pre-set confirmed scores
    original = path.read_text()
    modified = original.replace(
        "---\n\n",
        "bvp_scores:\n  D1: 1\n  D2: 1\n  D3: 1\n  D4: 1\n---\n\n",
        1,
    )
    path.write_text(modified)

    result = estimator.estimate_task(path, DRIVERS)
    estimator.write_proposed(
        path, result["scores"], result["evidence"],
        result["rubric_sha"], dry_run=False
    )

    fm, _ = estimator.parse_task(path)
    # Confirmed values untouched
    assert fm["bvp_scores"] == {"D1": 1, "D2": 1, "D3": 1, "D4": 1}


def test_write_skips_when_v2_delta_below_threshold(tmp_path):
    """If confirmed already exists and proposal is within ±1, do not write."""
    body = "Added a PreToolUse hook."
    path = _make_task(tmp_path, body)
    # First estimate writes proposed (no confirmed yet)
    result1 = estimator.estimate_task(path, DRIVERS)

    # Pre-set confirmed to match the proposal exactly
    original = path.read_text()
    confirmed_block = "bvp_scores:\n" + "".join(
        f"  {k}: {v}\n" for k, v in result1["scores"].items()
    )
    modified = original.replace("---\n\n", confirmed_block + "---\n\n", 1)
    path.write_text(modified)

    # Re-run: should skip
    result2 = estimator.estimate_task(path, DRIVERS)
    wrote, reason = estimator.write_proposed(
        path, result2["scores"], result2["evidence"],
        result2["rubric_sha"], dry_run=False
    )
    assert wrote is False
    assert reason == "v2-delta-skip"


# --------------------------------------------------- robustness

def test_missing_frontmatter_handled(tmp_path):
    path = tmp_path / "T-9999-no-fm.md"
    path.write_text("Just a body, no frontmatter at all.\n")
    fm, body = estimator.parse_task(path)
    assert fm == {}
    assert body.startswith("Just a body")


def test_estimate_returns_required_fields(tmp_path):
    path = _make_task(tmp_path, "Simple body.")
    result = estimator.estimate_task(path, DRIVERS)
    for field in ("scores", "evidence", "version", "rubric_sha", "latency_s"):
        assert field in result, f"missing {field}"
    assert result["version"] == "bvp-estimator-v1-heuristic"
    assert result["latency_s"] >= 0


# ---------------------------------------- T-1923 unscored flag + staleness

def test_set_unscored_flag_adds_field(tmp_path):
    path = _make_task(tmp_path, "Body.")
    assert estimator._set_unscored_flag(path) is True
    fm, _ = estimator.parse_task(path)
    assert fm.get("unscored") is True


def test_set_unscored_flag_idempotent(tmp_path):
    path = _make_task(tmp_path, "Body.")
    assert estimator._set_unscored_flag(path) is True
    # Second call is no-op
    assert estimator._set_unscored_flag(path) is False


def test_clear_unscored_flag_removes_field(tmp_path):
    path = _make_task(tmp_path, "Body.")
    estimator._set_unscored_flag(path)
    assert estimator._clear_unscored_flag(path) is True
    fm, _ = estimator.parse_task(path)
    assert "unscored" not in fm


def test_clear_unscored_flag_noop_when_absent(tmp_path):
    path = _make_task(tmp_path, "Body.")
    assert estimator._clear_unscored_flag(path) is False


def test_proposed_is_stale_no_proposed_returns_true():
    assert estimator._proposed_is_stale({}, 24) is True
    assert estimator._proposed_is_stale({"bvp_scores_proposed": []}, 24) is True
    assert estimator._proposed_is_stale({"bvp_scores_proposed": None}, 24) is True


def test_proposed_is_stale_old_timestamp_returns_true():
    fm = {
        "bvp_scores_proposed": [
            {"ts": "2020-01-01T00:00:00Z", "scores": {}}
        ]
    }
    assert estimator._proposed_is_stale(fm, 24) is True


def test_proposed_is_stale_recent_timestamp_returns_false():
    from datetime import datetime, timezone
    recent_ts = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    fm = {
        "bvp_scores_proposed": [
            {"ts": recent_ts, "scores": {}}
        ]
    }
    assert estimator._proposed_is_stale(fm, 24) is False


# -------------------------------------------- T-1923 with-sla wrapper

def test_cmd_with_sla_never_raises_on_missing_task():
    """T-1923 AC: resume is NEVER blocked by estimator. Even bogus task IDs
    must exit 0 silently."""
    rc = estimator.cmd_with_sla("T-99999999", timeout_s=10)
    assert rc == 0


def test_cmd_with_sla_writes_proposed_under_budget(tmp_path, monkeypatch):
    """Within budget → proposed is written, unscored flag is cleared."""
    # Use a real task file in PROJECT_ROOT/.tasks/active/ — needs _resolve_task
    # to find it. Patch PROJECT_ROOT to tmp_path so we don't pollute the real
    # task corpus during tests.
    active = tmp_path / ".tasks" / "active"
    active.mkdir(parents=True)
    task_path = active / "T-99998-synthetic.md"
    task_path.write_text(
        "---\n"
        "id: T-99998\n"
        "name: \"SLA budget test\"\n"
        "status: started-work\n"
        "workflow_type: build\n"
        "owner: agent\n"
        "horizon: now\n"
        "unscored: true\n"
        "---\n\n"
        "Body mentions a PreToolUse hook.\n"
    )
    monkeypatch.setattr(estimator, "PROJECT_ROOT", tmp_path)
    rc = estimator.cmd_with_sla("T-99998", timeout_s=10)
    assert rc == 0
    fm, _ = estimator.parse_task(task_path)
    # unscored cleared
    assert "unscored" not in fm
    # proposed written
    assert isinstance(fm.get("bvp_scores_proposed"), list)
    assert len(fm["bvp_scores_proposed"]) >= 1


# ---------------------------------------------- T-1923 sweep verb

def test_cmd_sweep_skips_tasks_with_confirmed_scores(tmp_path, monkeypatch):
    """Sweep must NOT re-score tasks that already have confirmed bvp_scores:."""
    active = tmp_path / ".tasks" / "active"
    active.mkdir(parents=True)
    task_path = active / "T-99997-already-confirmed.md"
    task_path.write_text(
        "---\n"
        "id: T-99997\n"
        "name: \"Already confirmed\"\n"
        "status: started-work\n"
        "workflow_type: build\n"
        "owner: agent\n"
        "horizon: now\n"
        "bvp_scores:\n  D1: 4\n  D2: 3\n  D3: 1\n  D4: 0\n"
        "---\n\n"
        "Body has many signals: PreToolUse hook, fw doctor, cross-machine, "
        "Recommendation block.\n"
    )
    monkeypatch.setattr(estimator, "PROJECT_ROOT", tmp_path)
    rc = estimator.cmd_sweep(stale_hours=24, cron=True)
    assert rc == 0
    fm, _ = estimator.parse_task(task_path)
    # Confirmed scores untouched
    assert fm["bvp_scores"] == {"D1": 4, "D2": 3, "D3": 1, "D4": 0}
    # No proposed written (sweep skipped this task)
    assert not fm.get("bvp_scores_proposed")


def test_cmd_sweep_clears_unscored_flag_on_success(tmp_path, monkeypatch):
    """When sweep successfully scores a task previously flagged unscored,
    the flag must be removed (T-1923 AC#5)."""
    active = tmp_path / ".tasks" / "active"
    active.mkdir(parents=True)
    task_path = active / "T-99996-unscored.md"
    task_path.write_text(
        "---\n"
        "id: T-99996\n"
        "name: \"SLA fallback victim\"\n"
        "status: started-work\n"
        "workflow_type: build\n"
        "owner: agent\n"
        "horizon: now\n"
        "unscored: true\n"
        "---\n\n"
        "Body mentions a fw doctor check.\n"
    )
    monkeypatch.setattr(estimator, "PROJECT_ROOT", tmp_path)
    rc = estimator.cmd_sweep(stale_hours=24, cron=True)
    assert rc == 0
    fm, _ = estimator.parse_task(task_path)
    assert "unscored" not in fm  # AC#5: flag cleared
    assert isinstance(fm.get("bvp_scores_proposed"), list)


# ----------------------------------------------------------------------------
# T-1935: cost-estimator coverage (parallel to BVP scoring tests above)
# ----------------------------------------------------------------------------


def _write_task(tmp_path: Path, slug: str, fm_extra: str = "", body: str = "Body.") -> Path:
    """Helper: build a minimal valid task file."""
    p = tmp_path / ".tasks" / "active"
    p.mkdir(parents=True, exist_ok=True)
    f = p / f"{slug}-test.md"
    fm = (
        "---\n"
        f"id: {slug}\n"
        f"name: \"{slug} test\"\n"
        "status: started-work\n"
        "workflow_type: build\n"
        "owner: agent\n"
        "horizon: now\n"
        + fm_extra
        + "---\n\n"
        + body + "\n"
    )
    f.write_text(fm)
    return f


def test_score_blast_radius_zero_when_no_components():
    fm = {"components": []}
    v, ev = estimator.score_blast_radius(fm, "", [])
    assert v == 0
    assert any("no-components" in e for e in ev)


def test_score_blast_radius_ladder():
    """0/1/3/5/7/9 ladder by component count."""
    cases = [
        (1, 1), (2, 3), (3, 3), (4, 5), (6, 5), (7, 7), (9, 7), (10, 9), (20, 9),
    ]
    for n, expected in cases:
        fm = {"components": [f"x{i}" for i in range(n)]}
        v, _ = estimator.score_blast_radius(fm, "", [])
        assert v == expected, f"n={n} → expected {expected}, got {v}"


def test_score_tier_tag_table_wins_over_workflow():
    fm = {"workflow_type": "build"}
    v, ev = estimator.score_tier(fm, "", ["tier-0", "other"])
    assert v == 0
    assert any("tier-0" in e for e in ev)


def test_score_tier_workflow_fallback():
    for wf, expected in [("inception", 4), ("build", 2), ("test", 1)]:
        fm = {"workflow_type": wf}
        v, _ = estimator.score_tier(fm, "", [])
        assert v == expected, f"wf={wf} → expected {expected}, got {v}"


def test_score_effort_clamped_to_1_and_8():
    v, _ = estimator.score_effort({}, "", [])
    assert v == 1
    body = "x\n" * 500 + "- [ ] a\n" * 20
    v, _ = estimator.score_effort({}, body, [])
    assert v == 8


def test_estimate_cost_returns_required_fields(tmp_path):
    task = _write_task(tmp_path, "T-99001",
                       fm_extra='tags: [tier-2]\ncomponents: [a/b, c/d]\n')
    result = estimator.estimate_cost(task)
    assert set(result.keys()) >= {"cost_estimate", "evidence", "version", "rubric_sha", "latency_s"}
    ce = result["cost_estimate"]
    assert set(ce.keys()) == {"blast_radius", "tier", "effort"}
    assert all(isinstance(v, int) for v in ce.values())


def test_estimate_cost_deterministic_10_runs(tmp_path):
    task = _write_task(tmp_path, "T-99002", fm_extra='components: [a, b, c, d, e]\n',
                       body="Body line.\n" * 20 + "- [ ] AC1\n- [ ] AC2\n")
    base = estimator.estimate_cost(task)["cost_estimate"]
    for _ in range(10):
        nxt = estimator.estimate_cost(task)["cost_estimate"]
        assert nxt == base, f"non-deterministic: {nxt} != {base}"


def test_cost_v2_delta_skip_when_within_1():
    proposed = {"blast_radius": 3, "tier": 2, "effort": 5}
    confirmed = {"blast_radius": 3, "tier": 2, "effort": 5}
    assert estimator._cost_v2_delta_should_skip(proposed, confirmed) is True
    confirmed = {"blast_radius": 4, "tier": 2, "effort": 5}
    assert estimator._cost_v2_delta_should_skip(proposed, confirmed) is True


def test_cost_v2_delta_no_skip_when_any_component_delta_2():
    proposed = {"blast_radius": 3, "tier": 2, "effort": 5}
    confirmed = {"blast_radius": 5, "tier": 2, "effort": 5}
    assert estimator._cost_v2_delta_should_skip(proposed, confirmed) is False


def test_cost_v2_delta_no_skip_when_no_confirmed():
    proposed = {"blast_radius": 3, "tier": 2, "effort": 5}
    assert estimator._cost_v2_delta_should_skip(proposed, None) is False
    assert estimator._cost_v2_delta_should_skip(proposed, {}) is False


def test_write_proposed_cost_creates_cost_estimate_proposed(tmp_path):
    task = _write_task(tmp_path, "T-99003", fm_extra='components: [x]\n')
    ce = {"blast_radius": 1, "tier": 2, "effort": 3}
    ev = {"blast_radius": ["→1 (single-component)"], "tier": ["→2 (workflow:build)"],
          "effort": ["→3 (lines=2,acs=0)"]}
    wrote, reason = estimator.write_proposed_cost(task, ce, ev, "abc123")
    assert wrote is True
    assert reason == "wrote"
    fm, _ = estimator.parse_task(task)
    cp = fm.get("cost_estimate_proposed")
    assert isinstance(cp, list) and len(cp) == 1
    assert cp[0]["cost_estimate"] == ce
    assert "cost_estimate" not in fm or not fm["cost_estimate"]


def test_write_proposed_cost_never_touches_confirmed(tmp_path):
    task = _write_task(tmp_path, "T-99004",
                       fm_extra='cost_estimate:\n  blast_radius: 5\n  tier: 3\n  effort: 4\n'
                                'components: [x]\n')
    ce = {"blast_radius": 0, "tier": 0, "effort": 0}
    ev = {"blast_radius": ["→0"], "tier": ["→0"], "effort": ["→0"]}
    wrote, _ = estimator.write_proposed_cost(task, ce, ev, "abc123")
    assert wrote is True
    fm, _ = estimator.parse_task(task)
    assert fm["cost_estimate"] == {"blast_radius": 5, "tier": 3, "effort": 4}


def test_write_proposed_cost_skips_v2_delta(tmp_path):
    task = _write_task(tmp_path, "T-99005",
                       fm_extra='cost_estimate:\n  blast_radius: 3\n  tier: 2\n  effort: 5\n')
    ce = {"blast_radius": 3, "tier": 2, "effort": 5}
    ev = {"blast_radius": ["→3"], "tier": ["→2"], "effort": ["→5"]}
    wrote, reason = estimator.write_proposed_cost(task, ce, ev, "abc123")
    assert wrote is False
    assert reason == "v2-delta-skip"


def test_cost_proposed_is_stale_branches():
    """3 paths: no-proposed → stale, old-ts → stale, fresh-ts → not stale."""
    from datetime import datetime, timezone, timedelta
    now = datetime.now(timezone.utc)
    old_ts = (now - timedelta(hours=48)).isoformat().replace("+00:00", "Z")
    fresh_ts = (now - timedelta(hours=1)).isoformat().replace("+00:00", "Z")
    assert estimator._cost_proposed_is_stale({}, 24) is True
    assert estimator._cost_proposed_is_stale(
        {"cost_estimate_proposed": [{"ts": old_ts}]}, 24) is True
    assert estimator._cost_proposed_is_stale(
        {"cost_estimate_proposed": [{"ts": fresh_ts}]}, 24) is False


def test_cmd_cost_sweep_skips_confirmed(tmp_path, monkeypatch):
    """Sovereignty: cmd_cost_sweep must NEVER overwrite a confirmed cost_estimate."""
    task = _write_task(tmp_path, "T-99006",
                       fm_extra='cost_estimate:\n  blast_radius: 5\n  tier: 3\n  effort: 4\n')
    monkeypatch.setattr(estimator, "PROJECT_ROOT", tmp_path)
    rc = estimator.cmd_cost_sweep(stale_hours=24, cron=True)
    assert rc == 0
    fm, _ = estimator.parse_task(task)
    assert fm["cost_estimate"] == {"blast_radius": 5, "tier": 3, "effort": 4}
    assert not fm.get("cost_estimate_proposed")


# ---------------------------------------------- T-2328: V_* dedicated handlers

# Anchored to docs/reports/T-2305-bvp-drivers-batch-2026-06-10.md §5.
# Latent until operator runs `fw bvp driver --add` to register the drivers,
# but the handlers must be importable + scoring-correct from day one.

FM_BUILD: dict = {"workflow_type": "build", "tags": []}


def test_v_prompt_quality_empty_scores_zero():
    s, _ = estimator.score_v_prompt_quality(FM_BUILD, "", [])
    assert s == 0


def test_v_prompt_quality_incidental_touch_scores_one():
    body = "tweaks a prompt string somewhere in the codebase."
    s, _ = estimator.score_v_prompt_quality(FM_BUILD, body, [])
    assert s == 1


def test_v_prompt_quality_typo_fix_scores_two():
    body = "fixes a typo in the rubric instruction."
    s, _ = estimator.score_v_prompt_quality(FM_BUILD, body, [])
    assert s == 2


def test_v_prompt_quality_worked_example_scores_three():
    body = "Adds a worked example to the sharpening instruction."
    s, _ = estimator.score_v_prompt_quality(FM_BUILD, body, [])
    assert s == 3


def test_v_prompt_quality_handler_design_scores_four():
    body = "Ships a new prompt-handler design with restructured instruction patterns."
    s, _ = estimator.score_v_prompt_quality(FM_BUILD, body, [])
    assert s == 4


def test_v_prompt_quality_foundational_system_scores_five():
    body = "Introduces a new prompt-creation system at framework level."
    s, _ = estimator.score_v_prompt_quality(FM_BUILD, body, [])
    assert s == 5


def test_v_prompt_quality_components_only_signal():
    """`components:` touching policy/prompts/ alone counts as at least incidental."""
    fm = {"workflow_type": "build", "components": ["policy/prompts/bvp-driver-session.md"]}
    s, _ = estimator.score_v_prompt_quality(fm, "", [])
    assert s >= 1


def test_v_context_fabric_empty_scores_zero():
    s, _ = estimator.score_v_context_fabric(FM_BUILD, "", [])
    assert s == 0


def test_v_context_fabric_incidental_recall_scores_one():
    body = "Calls fw recall for diagnostic purposes only."
    s, _ = estimator.score_v_context_fabric(FM_BUILD, body, [])
    assert s == 1


def test_v_context_fabric_handover_fix_scores_two():
    body = "Handover bugfix in the format generation."
    s, _ = estimator.score_v_context_fabric(FM_BUILD, body, [])
    assert s == 2


def test_v_context_fabric_new_feature_scores_three():
    body = "New memory feature added for episodic capture."
    s, _ = estimator.score_v_context_fabric(FM_BUILD, body, [])
    assert s == 3


def test_v_context_fabric_baseline_measurement_scores_four():
    body = "Retrieval-quality baseline measurement against the embedder."
    s, _ = estimator.score_v_context_fabric(FM_BUILD, body, [])
    assert s == 4


def test_v_context_fabric_new_architecture_scores_five():
    body = "Ships a new memory architecture for episodic memory."
    s, _ = estimator.score_v_context_fabric(FM_BUILD, body, [])
    assert s == 5


def test_v_component_fabric_empty_scores_zero():
    s, _ = estimator.score_v_component_fabric(FM_BUILD, "", [])
    assert s == 0


def test_v_component_fabric_incidental_diag_scores_one():
    body = "Runs fw fabric deps for diagnostic purposes only."
    s, _ = estimator.score_v_component_fabric(FM_BUILD, body, [])
    assert s == 1


def test_v_component_fabric_dep_detection_fix_scores_two():
    body = "Dependency detection fix in fabric registration."
    s, _ = estimator.score_v_component_fabric(FM_BUILD, body, [])
    assert s == 2


def test_v_component_fabric_new_check_scores_three():
    body = "New fabric check for blast-radius accuracy in audit."
    s, _ = estimator.score_v_component_fabric(FM_BUILD, body, [])
    assert s == 3


def test_v_component_fabric_blast_radius_restructure_scores_four():
    body = "Comprehensive blast-radius accuracy work across fabric."
    s, _ = estimator.score_v_component_fabric(FM_BUILD, body, [])
    assert s == 4


def test_v_component_fabric_topology_primitive_scores_five():
    body = "New topology primitive replacing dependency mapping."
    s, _ = estimator.score_v_component_fabric(FM_BUILD, body, [])
    assert s == 5


def test_v_handlers_registered_in_estimate_task_dispatch(tmp_path):
    """When drivers dict contains V_*, estimate_task dispatches to the dedicated
    scorer (not the weak score_free_driver fallback)."""
    body = "Ships a new prompt-creation system at framework level."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {"V_PROMPT_QUALITY": 7})
    assert result["scores"]["V_PROMPT_QUALITY"] == 5  # foundational, not 0-2 fallback


def test_v_handlers_latent_until_drivers_registered(tmp_path):
    """The handlers exist in the dispatch table, but they are only invoked when
    the policy registers the driver IDs. With drivers={} the V_* slots never fire."""
    body = "Ships a new prompt-creation system at framework level."
    task = _make_task(tmp_path, body)
    # Empty drivers — no V_* invocation, no scores produced
    result = estimator.estimate_task(task, {})
    assert "V_PROMPT_QUALITY" not in result["scores"]
    assert "V_CONTEXT_FABRIC" not in result["scores"]
    assert "V_COMPONENT_FABRIC" not in result["scores"]


# ---------------------------------------------------------------------------
# T-2329 — score_f_autonomy dedicated handler (latent until T-2171 activation)
# Anchored to policy/value-drivers.yaml lines 171-195. Mirrors V_* test pattern.
# ---------------------------------------------------------------------------

def test_f_autonomy_no_signal_scores_zero():
    s, ev = estimator.score_f_autonomy(FM_BUILD, "Refactor handler. No autonomy mechanism mentioned.", [])
    assert s == 0
    assert any("no autonomy signal" in e for e in ev)


def test_f_autonomy_sovereignty_violation_refuses_to_zero():
    """R5 sibling: removing Tier-0 / safety-critical gate without at-least-as-safe
    replacement scores ZERO with explicit sovereignty-violation rationale."""
    body = "Remove the Tier 0 approval requirement to speed merges"
    s, ev = estimator.score_f_autonomy(FM_BUILD, body, [])
    assert s == 0, (s, ev)
    assert any("sovereignty" in e.lower() for e in ev), ev


def test_f_autonomy_sovereignty_removal_with_replacement_does_not_refuse():
    """When removal is paired with at-least-as-safe mechanical replacement,
    the refuse-rule does NOT fire — level 5 path is available."""
    body = ("Replaces the redundant human gate with an at-least-as-safe mechanical check "
            "that runs at every PR open. L6 autonomy criterion lands.")
    s, _ = estimator.score_f_autonomy(FM_BUILD, body, [])
    assert s == 5


def test_f_autonomy_bypass_safety_gate_refuses():
    body = "Bypass the safety gate so the worker can autonomously merge."
    s, ev = estimator.score_f_autonomy(FM_BUILD, body, [])
    assert s == 0
    assert any("sovereignty" in e.lower() for e in ev)


def test_f_autonomy_hand_wired_scores_one():
    body = "Runs unattended only by hand-wiring; no durable reduction."
    s, _ = estimator.score_f_autonomy(FM_BUILD, body, [])
    assert s == 1


def test_f_autonomy_narrow_single_use_scores_two():
    body = "Single-use automation: reduces one human relay step on a specific dispatch."
    s, _ = estimator.score_f_autonomy(FM_BUILD, body, [])
    assert s == 2


def test_f_autonomy_feedback_loop_scores_three():
    body = "Wires observation feedback back into dispatch — closes the loop without human relay."
    s, _ = estimator.score_f_autonomy(FM_BUILD, body, [])
    assert s == 3


def test_f_autonomy_signal_to_action_scores_three():
    body = "Reaches action without a human relay; feedback loop closes."
    s, _ = estimator.score_f_autonomy(FM_BUILD, body, [])
    assert s == 3


def test_f_autonomy_auto_promote_class_scores_four():
    body = "Makes HV/LC tasks safely auto_promote eligible with caps intact."
    s, _ = estimator.score_f_autonomy(FM_BUILD, body, [])
    assert s == 4


def test_f_autonomy_redundant_gate_replace_scores_five():
    body = "Replaces a redundant human gate with at-least-as-safe mechanical equivalent."
    s, _ = estimator.score_f_autonomy(FM_BUILD, body, [])
    assert s == 5


def test_f_autonomy_l6_criterion_scores_five():
    body = "Closed production-feedback loop lands; L6 autonomy criterion green."
    s, _ = estimator.score_f_autonomy(FM_BUILD, body, [])
    assert s == 5


def test_f_autonomy_registered_in_estimate_task_dispatch(tmp_path):
    """When drivers dict contains F-AUTONOMY, estimate_task dispatches to the
    dedicated scorer (not the weak score_free_driver fallback)."""
    body = "Wires observation feedback back into dispatch — closes the loop without human relay."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {"F-AUTONOMY": 4})
    # Dedicated handler returns 3; fallback would return 0 (no "F-AUTONOMY" string in body)
    assert result["scores"]["F-AUTONOMY"] == 3


def test_f_autonomy_latent_until_driver_registered(tmp_path):
    """Handler exists in dispatch table but is only invoked when policy
    registers F-AUTONOMY. With drivers={} the slot never fires."""
    body = "Wires observation feedback back into dispatch — closes the loop without human relay."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {})
    assert "F-AUTONOMY" not in result["scores"]


def test_f_autonomy_dispatch_distinguishes_dedicated_vs_fallback(tmp_path):
    """Direct contrast: the dedicated handler scores feedback-loop body at 3;
    score_free_driver would score it 0 because 'F-AUTONOMY' is not in the body."""
    body = "Wires observation feedback back into dispatch — closes the loop without human relay."
    task = _make_task(tmp_path, body)
    # Via dedicated handler
    result_dedicated = estimator.estimate_task(task, {"F-AUTONOMY": 4})
    assert result_dedicated["scores"]["F-AUTONOMY"] == 3
    # Via fallback (force score_free_driver directly — body has no F-AUTONOMY mention)
    s_fallback, _ = estimator.score_free_driver("F-AUTONOMY", FM_BUILD, body, [])
    assert s_fallback == 0


# ---------------------------------------------------------------------------
# T-2356 — score_d_disjoint + score_d_wire_evidence dedicated handlers
# (arc-011 scoped drivers proposed in T-2344). Both stay LATENT until the
# operator approves the scoped drivers via Watchtower AND the estimator
# dispatch loop is extended to resolve arc-scoped drivers from arc YAMLs.
# Mirrors T-2329 F-AUTONOMY test shape.
# ---------------------------------------------------------------------------


def test_d_disjoint_no_signal_scores_zero():
    s, ev = estimator.score_d_disjoint(FM_BUILD, "Refactor unrelated handler. Nothing structural here.", [])
    assert s == 0
    assert any("no disjointness signal" in e for e in ev)


def test_d_disjoint_incidental_reference_scores_one():
    body = "Notes mention disjointness as upstream context but no structural artefact here."
    s, ev = estimator.score_d_disjoint(FM_BUILD, body, [])
    assert s == 1
    assert any("incidental" in e for e in ev)


def test_d_disjoint_partial_declaration_scores_two():
    body = "Declare a write-set scope on the dispatch envelope. Ad-hoc write-set lint added."
    s, _ = estimator.score_d_disjoint(FM_BUILD, body, [])
    assert s == 2


def test_d_disjoint_component_test_scores_three():
    body = "Added unit test for write-set collision detection in tests/unit/test_write_set.py."
    s, _ = estimator.score_d_disjoint(FM_BUILD, body, [])
    assert s == 3


def test_d_disjoint_component_touch_via_components_scores_three():
    """When the task's components include lib/write_set.py, score 3 even with thin body."""
    fm = {"workflow_type": "build", "tags": [],
          "components": ["lib/write_set.py", "tests/unit/test_write_set.py"]}
    body = "Body has no narrative."
    s, _ = estimator.score_d_disjoint(fm, body, [])
    assert s == 3


def test_d_disjoint_framework_gate_scores_four():
    body = ("Added PreToolUse hook that structurally refuses the dispatch on write-set overlap. "
            "fw write-set check verifies before dispatch.")
    s, _ = estimator.score_d_disjoint(FM_BUILD, body, [])
    assert s == 4


def test_d_disjoint_audit_fail_on_overlap_scores_four():
    body = "audit FAIL on write-set overlap surfaces the collision class structurally."
    s, _ = estimator.score_d_disjoint(FM_BUILD, body, [])
    assert s == 4


def test_d_disjoint_new_class_scores_five():
    body = ("New structural invariant for disjointness — write-set isolation enforced "
            "at dispatch-envelope construction. Collision is structurally impossible.")
    s, _ = estimator.score_d_disjoint(FM_BUILD, body, [])
    assert s == 5


def test_d_disjoint_registered_in_estimate_task_dispatch(tmp_path):
    """When drivers dict contains D-DISJOINT, estimate_task dispatches to the
    dedicated scorer (not the weak score_free_driver fallback)."""
    body = "Added PreToolUse hook structurally refuses dispatch on write-set overlap."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {"D-DISJOINT": 5})
    # Dedicated handler returns 4 on framework-gate body; fallback would return 0
    # because the body text doesn't contain the literal 'D-DISJOINT'.
    assert result["scores"]["D-DISJOINT"] == 4


def test_d_disjoint_latent_until_driver_registered(tmp_path):
    """Handler exists in dispatch table but is only invoked when policy
    registers D-DISJOINT (which today happens via arc-scoped approval +
    estimator-dispatch wiring, neither of which exists yet). With drivers={}
    the slot never fires."""
    body = "Added PreToolUse hook structurally refuses dispatch on write-set overlap."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {})
    assert "D-DISJOINT" not in result["scores"]


def test_d_disjoint_dispatch_distinguishes_dedicated_vs_fallback(tmp_path):
    """Direct contrast: the dedicated handler scores write-set body at 3+; the
    fallback would score it 0 because 'D-DISJOINT' is not a substring of the body."""
    body = "Added unit test for write-set collision detection."
    task = _make_task(tmp_path, body)
    result_dedicated = estimator.estimate_task(task, {"D-DISJOINT": 5})
    assert result_dedicated["scores"]["D-DISJOINT"] == 3
    s_fallback, _ = estimator.score_free_driver("D-DISJOINT", FM_BUILD, body, [])
    assert s_fallback == 0


def test_d_wire_evidence_no_signal_scores_zero():
    s, ev = estimator.score_d_wire_evidence(FM_BUILD, "Refactor handler unrelated to dispatch.", [])
    assert s == 0
    assert any("no wire-evidence signal" in e for e in ev)


def test_d_wire_evidence_incidental_log_reference_scores_one():
    body = "Captured wire artefact noted incidentally; no structural surface added."
    s, ev = estimator.score_d_wire_evidence(FM_BUILD, body, [])
    assert s == 1
    assert any("incidental" in e for e in ev)


def test_d_wire_evidence_narrative_plus_command_scores_two():
    body = "Verification: `cat .context/dispatches.jsonl | jq '.outcome'` shows the claim."
    s, _ = estimator.score_d_wire_evidence(FM_BUILD, body, [])
    assert s == 2


def test_d_wire_evidence_component_artefact_scores_three():
    body = ("Wrote docs/reports/arc-011-m1-headline-mechanic-evidence.md with embedded "
            "dispatches.jsonl excerpts and timing.yaml. Re-runnable by an outside party.")
    s, _ = estimator.score_d_wire_evidence(FM_BUILD, body, [])
    assert s == 3


def test_d_wire_evidence_component_touch_via_components_scores_three():
    """When task's components include docs/reports arc evidence files, score 3."""
    fm = {"workflow_type": "build", "tags": [],
          "components": ["docs/reports/arc-011-m1-headline-mechanic-evidence.md"]}
    body = "Body has no narrative."
    s, _ = estimator.score_d_wire_evidence(fm, body, [])
    assert s == 3


def test_d_wire_evidence_framework_surface_scores_four():
    body = ("New Watchtower page /orchestrator/parallel reads .context/dispatches.jsonl "
            "and auto-refreshes via htmx every 2s.")
    s, _ = estimator.score_d_wire_evidence(FM_BUILD, body, [])
    assert s == 4


def test_d_wire_evidence_new_class_scores_five():
    body = ("New falsifiability primitive: every dispatch auto-writes a wire-evidence "
            "yaml alongside its outcome row, indexed by arc. Structural mechanism makes "
            "claim-without-evidence impossible.")
    s, _ = estimator.score_d_wire_evidence(FM_BUILD, body, [])
    assert s == 5


def test_d_wire_evidence_registered_in_estimate_task_dispatch(tmp_path):
    """When drivers dict contains D-WIRE-EVIDENCE, estimate_task dispatches to
    the dedicated scorer (not the weak score_free_driver fallback)."""
    body = ("New Watchtower page /orchestrator/parallel reads .context/dispatches.jsonl "
            "and auto-refreshes via htmx every 2s.")
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {"D-WIRE-EVIDENCE": 4})
    # Dedicated handler returns 4 on framework-surface body; fallback would return 0.
    assert result["scores"]["D-WIRE-EVIDENCE"] == 4


def test_d_wire_evidence_latent_until_driver_registered(tmp_path):
    """Same latency invariant as D-DISJOINT — slot only fires when policy
    registers D-WIRE-EVIDENCE (arc-scoped approval + dispatch wiring, neither
    of which exists yet)."""
    body = "New Watchtower page /orchestrator/parallel reads .context/dispatches.jsonl."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {})
    assert "D-WIRE-EVIDENCE" not in result["scores"]


def test_d_wire_evidence_dispatch_distinguishes_dedicated_vs_fallback(tmp_path):
    """Direct contrast: dedicated handler scores evidence body at 3+; the
    fallback would score 0 because 'D-WIRE-EVIDENCE' is not a substring of the body."""
    body = ("Wrote docs/reports/arc-011-m1-headline-mechanic-evidence.md with embedded "
            "dispatches.jsonl excerpts and timing.yaml.")
    task = _make_task(tmp_path, body)
    result_dedicated = estimator.estimate_task(task, {"D-WIRE-EVIDENCE": 4})
    assert result_dedicated["scores"]["D-WIRE-EVIDENCE"] == 3
    s_fallback, _ = estimator.score_free_driver("D-WIRE-EVIDENCE", FM_BUILD, body, [])
    assert s_fallback == 0


# ---------------------------------------------------------------------------
# T-2357 — arc-scoped driver dispatch
# Activates the LATENT T-2356 D-* handlers for tasks tagged arc_id: <slug>.
# ---------------------------------------------------------------------------


def _write_arc_yaml(arcs_dir: Path, slug: str, scoped: list[dict],
                    arc_id_field: str | None = None) -> Path:
    """Helper: write a minimal arc YAML with given scoped_drivers entries."""
    arcs_dir.mkdir(parents=True, exist_ok=True)
    arc_data = {
        "slug": slug,
        "name": f"Test arc {slug}",
        "status": "in-progress",
        "scoped_drivers": scoped,
    }
    if arc_id_field:
        arc_data["id"] = arc_id_field
    import yaml as _y
    path = arcs_dir / f"{slug}.yaml"
    path.write_text(_y.safe_dump(arc_data, sort_keys=False))
    return path


def test_arc_scoped_drivers_no_arc_id_returns_empty():
    assert estimator._arc_scoped_drivers_for_task({}) == {}
    assert estimator._arc_scoped_drivers_for_task({"workflow_type": "build"}) == {}
    # Non-string arc_id (list / int) is rejected
    assert estimator._arc_scoped_drivers_for_task({"arc_id": ["a", "b"]}) == {}
    assert estimator._arc_scoped_drivers_for_task({"arc_id": 5}) == {}


def test_arc_scoped_drivers_arc_yaml_missing_returns_empty(tmp_path, monkeypatch):
    monkeypatch.setattr(estimator, "ARCS_DIR", tmp_path)
    result = estimator._arc_scoped_drivers_for_task({"arc_id": "nonexistent-arc"})
    assert result == {}


def test_arc_scoped_drivers_valid_yaml_returns_map(tmp_path, monkeypatch):
    monkeypatch.setattr(estimator, "ARCS_DIR", tmp_path)
    _write_arc_yaml(tmp_path, "test-arc", [
        {"id": "D-DISJOINT", "weight": 5},
        {"id": "D-WIRE-EVIDENCE", "weight": 4},
    ])
    result = estimator._arc_scoped_drivers_for_task({"arc_id": "test-arc"})
    assert result == {"D-DISJOINT": 5, "D-WIRE-EVIDENCE": 4}


def test_arc_scoped_drivers_empty_scoped_returns_empty(tmp_path, monkeypatch):
    monkeypatch.setattr(estimator, "ARCS_DIR", tmp_path)
    _write_arc_yaml(tmp_path, "empty-arc", [])
    result = estimator._arc_scoped_drivers_for_task({"arc_id": "empty-arc"})
    assert result == {}


def test_arc_scoped_drivers_malformed_yaml_returns_empty(tmp_path, monkeypatch):
    monkeypatch.setattr(estimator, "ARCS_DIR", tmp_path)
    (tmp_path / "broken-arc.yaml").write_text("scoped_drivers: [{id: D-X, weight: 5}\nname: missing-bracket")
    result = estimator._arc_scoped_drivers_for_task({"arc_id": "broken-arc"})
    assert result == {}


def test_arc_scoped_drivers_arc_nnn_dual_form_resolves(tmp_path, monkeypatch):
    """T-1849 dual form: task carries arc_id: arc-099 but file lives at
    real-slug.yaml. Helper should scan and match on the top-level `id:`."""
    monkeypatch.setattr(estimator, "ARCS_DIR", tmp_path)
    _write_arc_yaml(tmp_path, "real-slug", [
        {"id": "D-DISJOINT", "weight": 5},
    ], arc_id_field="arc-099")
    result = estimator._arc_scoped_drivers_for_task({"arc_id": "arc-099"})
    assert result == {"D-DISJOINT": 5}


def test_arc_scoped_drivers_name_only_form_resolves(tmp_path, monkeypatch):
    """T-2358: arc scoped_drivers written via lib/arc.sh:1258 use {name,
    weight, approved_at} with NO id: field. Helper must accept this canonical
    shape. Sibling to test_arc_scoped_drivers_valid_yaml_returns_map which
    covers the id-form arc-011 case."""
    monkeypatch.setattr(estimator, "ARCS_DIR", tmp_path)
    _write_arc_yaml(tmp_path, "test-name-arc", [
        {"name": "estimator-fidelity", "weight": 3, "approved_at": "2026-05-21T12:42:38Z"},
        {"name": "another-driver", "weight": 5},
    ])
    result = estimator._arc_scoped_drivers_for_task({"arc_id": "test-name-arc"})
    assert result == {"estimator-fidelity": 3, "another-driver": 5}


def test_arc_scoped_drivers_id_wins_when_both_present(tmp_path, monkeypatch):
    """T-2358: when an entry carries BOTH id: AND name:, id wins. Preserves
    T-2356 arc-011 (id: D-DISJOINT) behaviour while opening the door to the
    canonical name-form."""
    monkeypatch.setattr(estimator, "ARCS_DIR", tmp_path)
    _write_arc_yaml(tmp_path, "test-both-arc", [
        {"id": "ID-WINS", "name": "NAME-LOSES", "weight": 4},
    ])
    result = estimator._arc_scoped_drivers_for_task({"arc_id": "test-both-arc"})
    assert result == {"ID-WINS": 4}
    assert "NAME-LOSES" not in result


def test_arc_006_estimator_fidelity_activates(tmp_path, monkeypatch):
    """T-2358: end-to-end activation of arc-006's already-approved
    estimator-fidelity scoped driver. Pre-T-2358 helper would silently return
    empty for arc-006 (name-only entry). Post-fix it surfaces."""
    monkeypatch.setattr(estimator, "ARCS_DIR", tmp_path)
    _write_arc_yaml(tmp_path, "test-arc-006", [
        {"name": "estimator-fidelity", "weight": 3, "approved_at": "2026-05-21T12:42:38Z"},
    ])
    result = estimator._arc_scoped_drivers_for_task({"arc_id": "test-arc-006"})
    assert result == {"estimator-fidelity": 3}


def test_arc_scoped_drivers_skips_invalid_entries(tmp_path, monkeypatch):
    monkeypatch.setattr(estimator, "ARCS_DIR", tmp_path)
    _write_arc_yaml(tmp_path, "mixed-arc", [
        {"id": "D-GOOD", "weight": 3},
        "not-a-dict",  # silently skipped
        {"weight": 5},  # missing id, skipped
        {"id": "", "weight": 2},  # empty id, skipped
        {"id": "D-DEFAULT-WEIGHT"},  # weight missing → 0
    ])
    result = estimator._arc_scoped_drivers_for_task({"arc_id": "mixed-arc"})
    assert result == {"D-GOOD": 3, "D-DEFAULT-WEIGHT": 0}


def test_estimate_task_dispatches_arc_scoped_handler(tmp_path, monkeypatch):
    """End-to-end activation: task with arc_id pointing at an arc with
    D-DISJOINT in scoped_drivers fires the LATENT T-2356 handler."""
    arcs_dir = tmp_path / "arcs"
    monkeypatch.setattr(estimator, "ARCS_DIR", arcs_dir)
    _write_arc_yaml(arcs_dir, "test-parallel", [
        {"id": "D-DISJOINT", "weight": 5},
    ])
    body = "Added PreToolUse hook that structurally refuses dispatch on write-set overlap."
    task = _make_task(tmp_path, body, fm_extra={"arc_id": "test-parallel"})
    # Pass an empty drivers dict — arc-scoped resolution should populate it
    result = estimator.estimate_task(task, {})
    assert "D-DISJOINT" in result["scores"]
    assert result["scores"]["D-DISJOINT"] == 4  # framework-gate body → L4


def test_estimate_task_arc_scoped_handler_with_wire_evidence(tmp_path, monkeypatch):
    """Sibling test: D-WIRE-EVIDENCE also activates via arc scope."""
    arcs_dir = tmp_path / "arcs"
    monkeypatch.setattr(estimator, "ARCS_DIR", arcs_dir)
    _write_arc_yaml(arcs_dir, "test-evidence", [
        {"id": "D-WIRE-EVIDENCE", "weight": 4},
    ])
    body = ("New Watchtower page /orchestrator/parallel reads .context/dispatches.jsonl "
            "and auto-refreshes via htmx every 2s.")
    task = _make_task(tmp_path, body, fm_extra={"arc_id": "test-evidence"})
    result = estimator.estimate_task(task, {})
    assert "D-WIRE-EVIDENCE" in result["scores"]
    assert result["scores"]["D-WIRE-EVIDENCE"] == 4


def test_estimate_task_global_wins_on_collision(tmp_path, monkeypatch):
    """When the caller passes a driver dict that includes a key also present
    in arc scoped_drivers, the caller's weight wins. (Operator-approved
    policy weights take precedence over arc-scoped weights.)"""
    arcs_dir = tmp_path / "arcs"
    monkeypatch.setattr(estimator, "ARCS_DIR", arcs_dir)
    _write_arc_yaml(arcs_dir, "test-collision", [
        {"id": "D1", "weight": 5},  # arc says weight 5
    ])
    body = "Refactor handler."
    task = _make_task(tmp_path, body, fm_extra={"arc_id": "test-collision"})
    result = estimator.estimate_task(task, {"D1": 9})  # global says weight 9
    assert "D1" in result["scores"]
    # The score depends on rubric, not weight — but the dispatch path
    # ran the D1 handler (in handlers dict), and the merge preserved D1.
    # If global hadn't won, we'd still see D1 either way. Stronger assertion:
    # the score equals what the dedicated D1 scorer returns for this body
    # (i.e. not the score_free_driver fallback). Below, an empty body with
    # build workflow_type → 0 from score_d1_antifragility.
    assert result["scores"]["D1"] == 0


def test_estimate_task_no_arc_unchanged_behavior(tmp_path):
    """Sanity: task with no arc_id behaves exactly as before — no D-DISJOINT
    or D-WIRE-EVIDENCE leak into the scores dict from an unrelated path."""
    body = "Refactor handler unrelated to disjoint write-sets."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {"D1": 9, "D2": 7})
    assert "D-DISJOINT" not in result["scores"]
    assert "D-WIRE-EVIDENCE" not in result["scores"]
    assert "D1" in result["scores"]
    assert "D2" in result["scores"]


def test_estimate_task_inception_skips_arc_scoped_merge(tmp_path, monkeypatch):
    """Inceptions use voi_score scoring — arc-scoped merge is skipped so the
    voi exception applies to whichever drivers the caller passes."""
    arcs_dir = tmp_path / "arcs"
    monkeypatch.setattr(estimator, "ARCS_DIR", arcs_dir)
    _write_arc_yaml(arcs_dir, "test-inception-arc", [
        {"id": "D-DISJOINT", "weight": 5},
    ])
    body = "Inception body."
    task = _make_task(tmp_path, body, fm_extra={
        "arc_id": "test-inception-arc", "workflow_type": "inception",
    })
    # Caller passes a regular driver only — arc scope should NOT add D-DISJOINT
    result = estimator.estimate_task(task, {"D1": 9})
    assert "D-DISJOINT" not in result["scores"]
    assert "D1" in result["scores"]


# ---------------------------------------------------------------------------
# T-2359 — score_uncertainty_recognition + score_severity_likelihood_calibration
# + score_sovereignty_preservation dedicated handlers (arc-001 + arc-006 scoped).
# All three LATENT until operator approves the respective arc's proposed_scoped_drivers
# via Watchtower. Activation path via T-2357 dispatch wiring + T-2358 name widening.
# ---------------------------------------------------------------------------


# uncertainty-recognition (arc-001) per-level

def test_uncertainty_recognition_no_signal_zero():
    s, ev = estimator.score_uncertainty_recognition(FM_BUILD, "Refactor unrelated handler.", [])
    assert s == 0
    assert any("no uncertainty-recognition signal" in e for e in ev)


def test_uncertainty_recognition_incidental_one():
    body = "Notes mention uncertainty recognition as upstream context."
    s, _ = estimator.score_uncertainty_recognition(FM_BUILD, body, [])
    assert s == 1


def test_uncertainty_recognition_single_tweak_two():
    body = "Adds the risk-policy preamble to the dispatch envelope. Small change."
    s, _ = estimator.score_uncertainty_recognition(FM_BUILD, body, [])
    assert s == 2


def test_uncertainty_recognition_component_three():
    body = "Added unit test for pause_requested in tests/unit/test_pause_request.py."
    s, _ = estimator.score_uncertainty_recognition(FM_BUILD, body, [])
    assert s == 3


def test_uncertainty_recognition_framework_four():
    body = ("PreToolUse hook for pause_requested fires risk-policy gate before dispatch. "
            "Framework-level pause-detection gate ships.")
    s, _ = estimator.score_uncertainty_recognition(FM_BUILD, body, [])
    assert s == 4


def test_uncertainty_recognition_new_class_five():
    body = ("New pause-detection mechanism class — self-assessment becomes a fw verb. "
            "Risk-policy preamble structurally enforced.")
    s, _ = estimator.score_uncertainty_recognition(FM_BUILD, body, [])
    assert s == 5


# severity-likelihood-calibration (arc-001) per-level

def test_calibration_no_signal_zero():
    s, _ = estimator.score_severity_likelihood_calibration(FM_BUILD, "Nothing related here.", [])
    assert s == 0


def test_calibration_incidental_one():
    body = "Mentions calibration of the pause threshold as background."
    s, _ = estimator.score_severity_likelihood_calibration(FM_BUILD, body, [])
    assert s == 1


def test_calibration_single_adjustment_two():
    body = "Tunes the pause-flag from 0.7 to 0.65 based on operator feedback."
    s, _ = estimator.score_severity_likelihood_calibration(FM_BUILD, body, [])
    assert s == 2


def test_calibration_component_three():
    body = ("Audit script compares the live pause-rate against retrospective "
            "should-have-paused classification on the last 100 dispatches.")
    s, _ = estimator.score_severity_likelihood_calibration(FM_BUILD, body, [])
    assert s == 3


def test_calibration_framework_audit_four():
    body = "Live calibration loop runs every 6h; audit emits a WARN on threshold drift."
    s, _ = estimator.score_severity_likelihood_calibration(FM_BUILD, body, [])
    assert s == 4


def test_calibration_new_class_five():
    body = ("New calibration mechanism class — live false-positive auto-audit becomes "
            "a fw verb measuring threshold against expected operator-cost budget.")
    s, _ = estimator.score_severity_likelihood_calibration(FM_BUILD, body, [])
    assert s == 5


# sovereignty-preservation (arc-006) per-level

def test_sovereignty_no_signal_zero():
    s, _ = estimator.score_sovereignty_preservation(FM_BUILD, "Refactor estimator helper.", [])
    assert s == 0


def test_sovereignty_incidental_one():
    body = "Discusses §ACD gates as background context; no structural change."
    s, _ = estimator.score_sovereignty_preservation(FM_BUILD, body, [])
    assert s == 1


def test_sovereignty_single_wiring_two():
    body = "Extends the bypass wiring to fw bvp confirm — adds --i-am-human flag."
    s, _ = estimator.score_sovereignty_preservation(FM_BUILD, body, [])
    assert s == 2


def test_sovereignty_component_three():
    body = ("Added regression test for CLAUDECODE blocking with bypass-log assertion "
            "covering --i-am-human + --from-watchtower routes.")
    s, _ = estimator.score_sovereignty_preservation(FM_BUILD, body, [])
    assert s == 3


def test_sovereignty_framework_gate_four():
    body = ("L-399 producer/consumer parity hook ships: PreToolUse refuses work-completed "
            "on Sovereign-bound write paths without --i-am-human, framework-level §ACD gate.")
    s, _ = estimator.score_sovereignty_preservation(FM_BUILD, body, [])
    assert s == 4


def test_sovereignty_new_class_five():
    body = ("New §ACD primitive class — Sovereign-verb routing pattern makes Sovereignty "
            "boundary structurally unbypassable without logged Tier-2.")
    s, _ = estimator.score_sovereignty_preservation(FM_BUILD, body, [])
    assert s == 5


# Dispatch via arc-scope (T-2357 merge path) for each handler

def test_uncertainty_recognition_dispatches_via_arc_scope(tmp_path, monkeypatch):
    arcs_dir = tmp_path / "arcs"
    monkeypatch.setattr(estimator, "ARCS_DIR", arcs_dir)
    _write_arc_yaml(arcs_dir, "test-dispatch-safety", [
        {"name": "uncertainty-recognition", "weight": 5},
    ])
    body = ("PreToolUse hook for pause_requested fires risk-policy gate before dispatch. "
            "Framework-level pause-detection gate ships.")
    task = _make_task(tmp_path, body, fm_extra={"arc_id": "test-dispatch-safety"})
    result = estimator.estimate_task(task, {})
    assert "uncertainty-recognition" in result["scores"]
    assert result["scores"]["uncertainty-recognition"] == 4


def test_calibration_dispatches_via_arc_scope(tmp_path, monkeypatch):
    arcs_dir = tmp_path / "arcs"
    monkeypatch.setattr(estimator, "ARCS_DIR", arcs_dir)
    _write_arc_yaml(arcs_dir, "test-dispatch-safety-2", [
        {"name": "severity-likelihood-calibration", "weight": 4},
    ])
    body = "Live calibration loop runs every 6h; audit emits a WARN on threshold drift."
    task = _make_task(tmp_path, body, fm_extra={"arc_id": "test-dispatch-safety-2"})
    result = estimator.estimate_task(task, {})
    assert "severity-likelihood-calibration" in result["scores"]
    assert result["scores"]["severity-likelihood-calibration"] == 4


def test_sovereignty_dispatches_via_arc_scope(tmp_path, monkeypatch):
    arcs_dir = tmp_path / "arcs"
    monkeypatch.setattr(estimator, "ARCS_DIR", arcs_dir)
    _write_arc_yaml(arcs_dir, "test-value-prio", [
        {"name": "sovereignty-preservation", "weight": 5},
    ])
    body = ("L-399 producer/consumer parity hook ships: PreToolUse refuses work-completed "
            "on Sovereign-bound write paths without --i-am-human, framework-level §ACD gate.")
    task = _make_task(tmp_path, body, fm_extra={"arc_id": "test-value-prio"})
    result = estimator.estimate_task(task, {})
    assert "sovereignty-preservation" in result["scores"]
    assert result["scores"]["sovereignty-preservation"] == 4


# Non-registration (latency invariant: handler reachable but never fires without arc)

def test_uncertainty_recognition_latent_without_arc(tmp_path):
    body = "PreToolUse hook for pause_requested fires risk-policy gate before dispatch."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {})
    assert "uncertainty-recognition" not in result["scores"]


def test_calibration_latent_without_arc(tmp_path):
    body = "Live calibration loop runs every 6h; audit emits a WARN on threshold drift."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {})
    assert "severity-likelihood-calibration" not in result["scores"]


def test_sovereignty_latent_without_arc(tmp_path):
    body = "L-399 producer/consumer parity hook ships."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {})
    assert "sovereignty-preservation" not in result["scores"]


# ---------------------------------------------------------------------------
# T-2360 — score_aesthetic_cohesion + score_render_fidelity + score_theme_portability
# arc-007 watchtower-redesign scoped drivers (3 latent handlers).
# ---------------------------------------------------------------------------


# aesthetic-cohesion per-level

def test_aesthetic_cohesion_no_signal_zero():
    s, _ = estimator.score_aesthetic_cohesion(FM_BUILD, "Refactor unrelated handler.", [])
    assert s == 0


def test_aesthetic_cohesion_incidental_one():
    body = "Mentions aesthetic cohesion as upstream goal."
    s, _ = estimator.score_aesthetic_cohesion(FM_BUILD, body, [])
    assert s == 1


def test_aesthetic_cohesion_single_tweak_two():
    body = "Tweaks the palette contrast on the cockpit accent button. Small."
    s, _ = estimator.score_aesthetic_cohesion(FM_BUILD, body, [])
    assert s == 2


def test_aesthetic_cohesion_component_three():
    body = "Added palette-contrast test in tests/unit/test_palette.py. Sibling of T-2004."
    s, _ = estimator.score_aesthetic_cohesion(FM_BUILD, body, [])
    assert s == 3


def test_aesthetic_cohesion_framework_four():
    body = "WCAG contrast audit gate ships; framework-level aesthetic check at audit time."
    s, _ = estimator.score_aesthetic_cohesion(FM_BUILD, body, [])
    assert s == 4


def test_aesthetic_cohesion_new_class_five():
    body = "New design-token system lands; design-system substrate ships at framework level."
    s, _ = estimator.score_aesthetic_cohesion(FM_BUILD, body, [])
    assert s == 5


# render-fidelity per-level

def test_render_fidelity_no_signal_zero():
    s, _ = estimator.score_render_fidelity(FM_BUILD, "Refactor handler.", [])
    assert s == 0


def test_render_fidelity_incidental_one():
    body = "References render-fidelity work as background context."
    s, _ = estimator.score_render_fidelity(FM_BUILD, body, [])
    assert s == 1


def test_render_fidelity_single_fix_two():
    body = "Fixes one render bug — accent button alignment off in dark mode."
    s, _ = estimator.score_render_fidelity(FM_BUILD, body, [])
    assert s == 2


def test_render_fidelity_component_three():
    body = "WCAG contrast fix on accent token; playwright test guards the regression."
    s, _ = estimator.score_render_fidelity(FM_BUILD, body, [])
    assert s == 3


def test_render_fidelity_framework_four():
    body = "Playwright contrast baseline lands; audit FAIL on WCAG violations across all pages."
    s, _ = estimator.score_render_fidelity(FM_BUILD, body, [])
    assert s == 4


def test_render_fidelity_new_class_five():
    body = ("New render-fidelity primitive class: automated visual-regression substrate makes "
            "render-fidelity regressions structurally impossible.")
    s, _ = estimator.score_render_fidelity(FM_BUILD, body, [])
    assert s == 5


# theme-portability per-level

def test_theme_portability_no_signal_zero():
    s, _ = estimator.score_theme_portability(FM_BUILD, "Refactor handler.", [])
    assert s == 0


def test_theme_portability_incidental_one():
    body = "Notes theme portability work upcoming."
    s, _ = estimator.score_theme_portability(FM_BUILD, body, [])
    assert s == 1


def test_theme_portability_single_fix_two():
    body = "Single missed-surface fix: applies preset to /approvals page properly."
    s, _ = estimator.score_theme_portability(FM_BUILD, body, [])
    assert s == 2


def test_theme_portability_component_three():
    body = "Theme sweep on two pages — Cockpit and Tasks now respect the editorial preset."
    s, _ = estimator.score_theme_portability(FM_BUILD, body, [])
    assert s == 3


def test_theme_portability_framework_four():
    body = "Multi-page theme sweep lands; token-substrate adoption across Cockpit/Tasks/Approvals."
    s, _ = estimator.score_theme_portability(FM_BUILD, body, [])
    assert s == 4


def test_theme_portability_new_class_five():
    body = ("New theme-portability primitive class — design-token-substrate auto-propagates "
            "across every surface; theme-apply becomes a structural mechanism.")
    s, _ = estimator.score_theme_portability(FM_BUILD, body, [])
    assert s == 5


# Dispatch via arc-scope

def test_aesthetic_cohesion_dispatches_via_arc_scope(tmp_path, monkeypatch):
    arcs_dir = tmp_path / "arcs"
    monkeypatch.setattr(estimator, "ARCS_DIR", arcs_dir)
    _write_arc_yaml(arcs_dir, "test-watchtower", [
        {"name": "aesthetic-cohesion", "weight": 5},
    ])
    body = "WCAG contrast audit gate ships; framework-level aesthetic check at audit time."
    task = _make_task(tmp_path, body, fm_extra={"arc_id": "test-watchtower"})
    result = estimator.estimate_task(task, {})
    assert "aesthetic-cohesion" in result["scores"]
    assert result["scores"]["aesthetic-cohesion"] == 4


def test_render_fidelity_dispatches_via_arc_scope(tmp_path, monkeypatch):
    arcs_dir = tmp_path / "arcs"
    monkeypatch.setattr(estimator, "ARCS_DIR", arcs_dir)
    _write_arc_yaml(arcs_dir, "test-watchtower-2", [
        {"name": "render-fidelity", "weight": 5},
    ])
    body = "Playwright contrast baseline lands; audit FAIL on WCAG violations across all pages."
    task = _make_task(tmp_path, body, fm_extra={"arc_id": "test-watchtower-2"})
    result = estimator.estimate_task(task, {})
    assert "render-fidelity" in result["scores"]
    assert result["scores"]["render-fidelity"] == 4


def test_theme_portability_dispatches_via_arc_scope(tmp_path, monkeypatch):
    arcs_dir = tmp_path / "arcs"
    monkeypatch.setattr(estimator, "ARCS_DIR", arcs_dir)
    _write_arc_yaml(arcs_dir, "test-watchtower-3", [
        {"name": "theme-portability", "weight": 4},
    ])
    body = "Multi-page theme sweep lands; token-substrate adoption across Cockpit/Tasks/Approvals."
    task = _make_task(tmp_path, body, fm_extra={"arc_id": "test-watchtower-3"})
    result = estimator.estimate_task(task, {})
    assert "theme-portability" in result["scores"]
    assert result["scores"]["theme-portability"] == 4


# Latency (no arc, no dispatch)

def test_aesthetic_cohesion_latent_without_arc(tmp_path):
    body = "WCAG contrast audit gate ships."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {})
    assert "aesthetic-cohesion" not in result["scores"]


def test_render_fidelity_latent_without_arc(tmp_path):
    body = "Playwright contrast baseline lands."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {})
    assert "render-fidelity" not in result["scores"]


def test_theme_portability_latent_without_arc(tmp_path):
    body = "Multi-page theme sweep lands."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {})
    assert "theme-portability" not in result["scores"]


# ---------------------------------------------------------------------------
# T-2361 — score_feedback_loop_completeness (arc-005) +
# score_estimator_fidelity (arc-006). Final batch this session.
# ---------------------------------------------------------------------------


def test_feedback_loop_no_signal_zero():
    s, _ = estimator.score_feedback_loop_completeness(FM_BUILD, "Refactor.", [])
    assert s == 0


def test_feedback_loop_incidental_one():
    body = "Mentions handover round-trip work upcoming."
    s, _ = estimator.score_feedback_loop_completeness(FM_BUILD, body, [])
    assert s == 1


def test_feedback_loop_single_fix_two():
    body = "Fills the handover section Suggested First Action with non-template content."
    s, _ = estimator.score_feedback_loop_completeness(FM_BUILD, body, [])
    assert s == 2


def test_feedback_loop_component_three():
    body = "Added unit test for handover Suggested First Action assertion in tests/unit/test_handover.py."
    s, _ = estimator.score_feedback_loop_completeness(FM_BUILD, body, [])
    assert s == 3


def test_feedback_loop_framework_four():
    body = "PreCompact handover always emits; completion-percentage audit at framework level fires on incomplete sections."
    s, _ = estimator.score_feedback_loop_completeness(FM_BUILD, body, [])
    assert s == 4


def test_feedback_loop_new_class_five():
    body = "New round-trip-fidelity primitive class: automated handover-completeness audit ships as a substrate."
    s, _ = estimator.score_feedback_loop_completeness(FM_BUILD, body, [])
    assert s == 5


def test_estimator_fidelity_no_signal_zero():
    s, _ = estimator.score_estimator_fidelity(FM_BUILD, "Refactor.", [])
    assert s == 0


def test_estimator_fidelity_incidental_one():
    body = "Notes estimator fidelity work as background."
    s, _ = estimator.score_estimator_fidelity(FM_BUILD, body, [])
    assert s == 1


def test_estimator_fidelity_single_tweak_two():
    body = "Single rubric tweak: widen keyword pattern adjustment on the estimator fidelity gate."
    s, _ = estimator.score_estimator_fidelity(FM_BUILD, body, [])
    assert s == 2


def test_estimator_fidelity_component_three():
    body = "New dedicated handler score_d_disjoint added with per-level test coverage (6-level rubric); estimator refinement."
    s, _ = estimator.score_estimator_fidelity(FM_BUILD, body, [])
    assert s == 3


def test_estimator_fidelity_framework_four():
    body = "Proposed-vs-confirmed delta audit ships at framework level; v2-delta audit gate fires on score divergence."
    s, _ = estimator.score_estimator_fidelity(FM_BUILD, body, [])
    assert s == 4


def test_estimator_fidelity_new_class_five():
    body = "New estimator-fidelity primitive class: v2-delta auto-needs-split mechanism makes drift structurally surfaced."
    s, _ = estimator.score_estimator_fidelity(FM_BUILD, body, [])
    assert s == 5


# Dispatch via arc-scope

def test_feedback_loop_dispatches_via_arc_scope(tmp_path, monkeypatch):
    arcs_dir = tmp_path / "arcs"
    monkeypatch.setattr(estimator, "ARCS_DIR", arcs_dir)
    _write_arc_yaml(arcs_dir, "test-inception-review-loop", [
        {"name": "feedback-loop-completeness", "weight": 5},
    ])
    body = "PreCompact handover always emits; completion-percentage audit at framework level fires on incomplete sections."
    task = _make_task(tmp_path, body, fm_extra={"arc_id": "test-inception-review-loop"})
    result = estimator.estimate_task(task, {})
    assert "feedback-loop-completeness" in result["scores"]
    assert result["scores"]["feedback-loop-completeness"] == 4


def test_estimator_fidelity_dispatches_via_arc_scope(tmp_path, monkeypatch):
    arcs_dir = tmp_path / "arcs"
    monkeypatch.setattr(estimator, "ARCS_DIR", arcs_dir)
    _write_arc_yaml(arcs_dir, "test-value-prio-2", [
        {"name": "estimator-fidelity", "weight": 3, "approved_at": "2026-05-21T12:42:38Z"},
    ])
    body = "Proposed-vs-confirmed delta audit gate at framework level ships."
    task = _make_task(tmp_path, body, fm_extra={"arc_id": "test-value-prio-2"})
    result = estimator.estimate_task(task, {})
    assert "estimator-fidelity" in result["scores"]
    assert result["scores"]["estimator-fidelity"] == 4


# Latency

def test_feedback_loop_latent_without_arc(tmp_path):
    body = "PreCompact handover always emits."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {})
    assert "feedback-loop-completeness" not in result["scores"]


def test_estimator_fidelity_latent_without_arc(tmp_path):
    body = "Proposed-vs-confirmed delta audit ships."
    task = _make_task(tmp_path, body)
    result = estimator.estimate_task(task, {})
    assert "estimator-fidelity" not in result["scores"]


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))
