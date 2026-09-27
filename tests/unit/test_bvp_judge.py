"""Tests for lib/bvp_judge.py — the BVP score judge (T-3526, D-662 slice 2 of 3).

Coverage mapped to T-3526's Agent ACs:
  (1) imports lib.judge_verdict, defines no second vocabulary
  (2) judges bvp_scores_proposed:, never touches bvp_scores:
  (3) presence / sufficiency / goal-hierarchy, each independently demonstrable
  (4) population: open tasks only (reviewable())
  (5) UNKNOWN never green when it cannot judge; a judgeable task does NOT come
      back UNKNOWN (the control leg)
  (8) a mutant that always returns green is killed
"""

from __future__ import annotations

import inspect
import sys
import textwrap
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT))

import lib.bvp_judge as bj
from lib.judge_verdict import GREEN, AMBER, RED, UNKNOWN, may_proceed


# ───────────────────────── fixtures ─────────────────────────────────────────


GOOD_ACS = textwrap.dedent("""\
    ## Acceptance Criteria

    ### Agent
    - [ ] The endpoint returns HTTP 200 and the expected JSON payload shape.
    - [ ] A regression test pins the fix so the bug cannot silently return.
    """)

PLACEHOLDER_ACS = textwrap.dedent("""\
    ## Acceptance Criteria

    ### Agent
    - [ ] TBD
    - [ ] fix it
    """)

NO_ACS = "## Acceptance Criteria\n\n### Agent\n<!-- none yet -->\n"


def _write_task(tmp_path: Path, *, task_id="T-1", status="started-work",
                 description="Fix the flaky retry loop in the dispatcher.",
                 ac_body=GOOD_ACS, scores=None, rationale="", arc_id=None,
                 include_proposed=True) -> Path:
    scores = scores if scores is not None else {"D1": 3, "D2": 2}
    fm = {
        "id": task_id,
        "status": status,
        "description": description,
    }
    if arc_id:
        fm["arc_id"] = arc_id
    if include_proposed:
        fm["bvp_scores_proposed"] = [{
            "ts": "2026-09-27T00:00:00Z",
            "estimator": "bvp-estimator-v1-heuristic",
            "scores": scores,
            "rationale": rationale,
        }]
    text = "---\n" + yaml.safe_dump(fm, sort_keys=False) + "---\n\n" + ac_body
    path = tmp_path / f"{task_id}.md"
    path.write_text(text)
    return path


@pytest.fixture(autouse=True)
def _isolated_project_root(tmp_path, monkeypatch):
    """Every test gets its own PROJECT_ROOT with a real policy/value-drivers.yaml
    so the project-level goal-hierarchy fallback is exercised deterministically,
    not against whatever the real repo currently has on disk."""
    (tmp_path / "policy").mkdir()
    (tmp_path / ".context" / "arcs").mkdir(parents=True)
    (tmp_path / "policy" / "value-drivers.yaml").write_text(textwrap.dedent("""\
        protected_drivers:
          - id: D1
            name: Antifragility
            weight: 9
            note: "System strengthens under stress; failures are learning events."
          - id: D2
            name: Reliability
            weight: 7
            note: "Predictable, observable, auditable execution; no silent failures."
        """))
    monkeypatch.setattr(bj, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(bj, "POLICY_PATH", tmp_path / "policy" / "value-drivers.yaml")
    monkeypatch.setattr(bj, "ARCS_DIR", tmp_path / ".context" / "arcs")
    monkeypatch.setattr(bj, "_PROJECT_DIRECTIVES_CACHE", None)
    yield tmp_path


# ───────────────────────── (1) imports the contract, defines no second one ──


def test_no_local_verdict_state_constants():
    """The module must not shadow judge_verdict's GREEN/AMBER/RED/UNKNOWN with
    its own definitions — it may only reference the imported names."""
    src = inspect.getsource(bj)
    for banned in ('GREEN = "', "GREEN = '", 'AMBER = "', "AMBER = '",
                   'RED = "', "RED = '", 'UNKNOWN = "', "UNKNOWN = '"):
        assert banned not in src, f"found a local re-definition: {banned!r}"


def test_no_local_reviewable_or_verdict_function():
    """No local `def reviewable(` or `def verdict(` — those live in judge_verdict."""
    names = {name for name, _ in inspect.getmembers(bj, inspect.isfunction)
              if inspect.getmodule(_) is bj}
    assert "reviewable" not in names
    assert "verdict" not in names
    assert "may_proceed" not in names


def test_module_imports_from_judge_verdict():
    src = inspect.getsource(bj)
    assert "from lib.judge_verdict import" in src


# ───────────────────────── (2) judges proposed, never writes confirmed ──────


def test_judges_bvp_scores_proposed_field(tmp_path):
    p = _write_task(tmp_path, scores={"D1": 3, "D2": 2}, rationale="D1=3 (body:x); D2=2 (body:y)")
    v, reason = bj.judge_task(p)
    assert v is not None
    assert v["judged"] == "T-1"


def test_never_writes_bvp_scores_field(tmp_path):
    """A test that pins the judge leaves bvp_scores: untouched — it never
    exists in the file before OR after, and the file's bytes are unchanged."""
    p = _write_task(tmp_path, scores={"D1": 3, "D2": 2}, rationale="D1=3 (body:x); D2=2 (body:y)")
    before = p.read_text()
    fm_before, _ = bj.parse_task_file(p)
    assert "bvp_scores" not in fm_before  # only bvp_scores_proposed present

    bj.judge_task(p)

    after = p.read_text()
    assert after == before, "judge_task must not mutate the task file at all"
    fm_after, _ = bj.parse_task_file(p)
    assert "bvp_scores" not in fm_after


def test_module_has_no_write_function():
    """No function anywhere in this module opens a file for writing."""
    src = inspect.getsource(bj)
    assert ".write_text(" not in src
    assert "open(" not in src or "'w'" not in src


# ───────────────────────── (3) presence / sufficiency / goal-hierarchy ──────


def test_presence_fails_with_no_acceptance_criteria(tmp_path):
    p = _write_task(tmp_path, ac_body=NO_ACS)
    v, reason = bj.judge_task(p)
    assert v["state"] == RED
    assert "no acceptance" in v["guidance"].lower() or "acceptance" in v["guidance"].lower()
    assert reason == "presence check failed"


def test_presence_passes_with_real_criteria():
    present, items, reason = bj.check_presence(GOOD_ACS)
    assert present is True
    assert len(items) == 2


def test_presence_independent_of_sufficiency():
    """Presence only asks IF criteria exist, not whether they're good."""
    present, items, _ = bj.check_presence(PLACEHOLDER_ACS)
    assert present is True  # criteria ARE present
    sufficient, _ = bj.check_sufficiency(items, {"D1": 5})
    assert sufficient is False  # but not substantive enough for a high claim


def test_sufficiency_fails_on_placeholder_criteria(tmp_path):
    p = _write_task(tmp_path, ac_body=PLACEHOLDER_ACS, scores={"D1": 3},
                     rationale="D1=3 (body:x)")
    v, reason = bj.judge_task(p)
    assert v["state"] == AMBER
    assert reason == "sufficiency check failed"


def test_sufficiency_high_claim_needs_two_substantive_acs():
    single_good = "## Acceptance Criteria\n\n- [ ] " + "x" * 20 + "\n"
    items = bj._extract_ac_items(bj.extract_section(single_good, "Acceptance Criteria"))
    ok_low_claim, _ = bj.check_sufficiency(items, {"D1": 2})
    ok_high_claim, _ = bj.check_sufficiency(items, {"D1": 5})
    assert ok_low_claim is True
    assert ok_high_claim is False


def test_goal_hierarchy_resolves_task_level_from_description(tmp_path):
    p = _write_task(tmp_path, description="A real, specific goal statement.")
    fm, body = bj.parse_task_file(p)
    level, goal, _ = bj.resolve_goal_hierarchy(fm, body)
    assert level == "task"
    assert goal == "A real, specific goal statement."


def test_goal_hierarchy_resolves_arc_level_when_no_description(tmp_path):
    arc_path = bj.ARCS_DIR / "my-arc.yaml"
    arc_path.write_text(yaml.safe_dump({
        "id": "arc-999", "slug": "my-arc",
        "description": "The arc's own stated objective.",
    }))
    p = _write_task(tmp_path, description="", arc_id="my-arc")
    fm, body = bj.parse_task_file(p)
    level, goal, _ = bj.resolve_goal_hierarchy(fm, body)
    assert level == "arc"
    assert goal == "The arc's own stated objective."


def test_goal_hierarchy_falls_back_to_project_level(tmp_path):
    p = _write_task(tmp_path, description="")
    fm, body = bj.parse_task_file(p)
    level, goal, notes = bj.resolve_goal_hierarchy(fm, body)
    assert level == "project"
    assert "D1" in goal


def test_goal_hierarchy_catches_no_signal_contradiction(tmp_path):
    """The case D-662 names explicitly: a score claiming value where the
    proposal's own evidence admits there is none."""
    p = _write_task(tmp_path, scores={"D1": 3}, rationale="D1=3 (no-signal)")
    v, reason = bj.judge_task(p)
    assert v["state"] == RED
    assert reason == "goal hierarchy check failed"
    assert "no-signal" in v["guidance"] or any("no-signal" in e for e in v["evidence"])


def test_goal_hierarchy_flags_high_claim_on_project_fallback_only(tmp_path):
    """A framework-level (>=4) claim resting only on the project fallback (no
    task description, no arc) has nothing narrower to check it against."""
    p = _write_task(tmp_path, description="", scores={"D1": 5},
                     rationale="D1=5 (body:new-mechanism)")
    v, reason = bj.judge_task(p)
    assert v["state"] == RED
    assert reason == "goal hierarchy check failed"


def test_goal_hierarchy_passes_task_level_high_claim(tmp_path):
    """The SAME high claim is fine when it has a task-level objective behind it."""
    p = _write_task(tmp_path, description="A concrete, specific task objective.",
                     scores={"D1": 5}, rationale="D1=5 (body:new-mechanism)")
    v, reason = bj.judge_task(p)
    assert v["state"] == GREEN


# ───────────────────────── (4) population: open tasks only ──────────────────


def test_closed_task_is_skipped_not_judged(tmp_path):
    p = _write_task(tmp_path, status="work-completed")
    v, reason = bj.judge_task(p)
    assert v is None
    assert "closed" in reason


def test_open_task_is_judged(tmp_path):
    for status in ("captured", "started-work", "issues"):
        p = _write_task(tmp_path, task_id=f"T-{status}", status=status)
        v, reason = bj.judge_task(p)
        assert v is not None, f"status={status} should be reviewable"


def test_no_proposal_is_skipped(tmp_path):
    p = _write_task(tmp_path, include_proposed=False)
    v, reason = bj.judge_task(p)
    assert v is None
    assert "no bvp_scores_proposed" in reason


# ───────────────────────── (5) UNKNOWN never green; judgeable != UNKNOWN ────


def test_unknown_when_no_objective_anywhere(tmp_path):
    """Break the project-level fallback too (empty policy file) — now NO level
    resolves, which must yield UNKNOWN, never green."""
    (tmp_path / "policy" / "value-drivers.yaml").write_text("protected_drivers: []\n")
    import importlib
    p = _write_task(tmp_path, description="")
    v, reason = bj.judge_task(p)
    assert v["state"] == UNKNOWN
    assert v["guidance"]  # UNKNOWN must carry guidance too
    assert may_proceed(v) is False


def test_unknown_is_never_falsely_favourable():
    """`if verdict:` truthiness must not stand in for may_proceed()."""
    from lib.judge_verdict import verdict as make_verdict
    v = make_verdict(UNKNOWN, guidance="cannot tell")
    assert bool(v) is True  # dict is truthy
    assert may_proceed(v) is False  # but must not proceed


def test_judgeable_task_does_not_come_back_unknown(tmp_path):
    """Control leg (explicitly required by the AC): a normal, well-formed task
    with real ACs and a normal score must NOT come back UNKNOWN — a judge that
    defaults everything to UNKNOWN would pass the negative tests above while
    being useless."""
    p = _write_task(tmp_path, description="A real objective.", scores={"D1": 2, "D2": 1},
                     rationale="D1=2 (body:local-fix); D2=1 (body:incidental)")
    v, reason = bj.judge_task(p)
    assert v is not None
    assert v["state"] != UNKNOWN, f"a judgeable task must not fail safe into UNKNOWN: {v}"
    assert v["state"] == GREEN


def test_read_error_yields_unknown_not_green(tmp_path):
    missing = tmp_path / "T-does-not-exist.md"
    v, reason = bj.judge_task(missing)
    assert v["state"] == UNKNOWN


# ───────────────────────── (8) mutant that always returns green is killed ──


def test_always_green_mutant_is_killed_by_presence_test(tmp_path, monkeypatch):
    """Simulates the L-576 mutant: force judge_task to always report GREEN
    regardless of input, and confirm at least one existing test fails against
    it — i.e. the suite actually exercises non-green paths and would catch a
    real regression that flattens the judge into a rubber stamp."""
    from lib.judge_verdict import verdict as make_verdict

    def _always_green(task_path, *, judge_id=bj.JUDGE_ID):
        return make_verdict(GREEN, judged=str(task_path), judge=judge_id), "mutant: always green"

    monkeypatch.setattr(bj, "judge_task", _always_green)

    p = _write_task(tmp_path, ac_body=NO_ACS)  # should be RED under the real judge
    v, reason = bj.judge_task(p)
    assert v["state"] == GREEN  # the mutant IS active

    # The real assertion this test protects: under the true implementation,
    # the same input is RED. Restore and prove the mutant would have been
    # caught by test_presence_fails_with_no_acceptance_criteria.
    monkeypatch.undo()
    v_real, _ = bj.judge_task(p)
    assert v_real["state"] == RED, "mutant would have been undetected if this held"
