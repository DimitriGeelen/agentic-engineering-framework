"""Tests for lib/arc_driver_judge.py — the arc-scoped-driver judge (T-3527,
D-662 slice 3 of 3).

Coverage mapped to T-3527's Agent ACs:
  (1) imports lib.judge_verdict, defines no second vocabulary
  (2) WRAPS lib/arc-driver-review.sh (real subprocess calls, not reimplemented)
  (3) judges against the arc's own goal/objective (self-admission + level-match)
  (5) OBS-559: a genuinely-unimportable estimator comes back UNKNOWN, never a
      driver-quality fail — pinned against a REAL unimportable state, not a mock
  (6) non-green always carries guidance (enforced by the imported contract)
  (7) a mutant that always returns green is killed; a judgeable driver does NOT
      come back UNKNOWN (control leg)
  (8) out of scope confirmed by diff — this suite touches no estimator detector
      code and no `fw arc close`/`fw arc abandon` code path
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

import lib.arc_driver_judge as adj
from lib.judge_verdict import AMBER, GREEN, RED, UNKNOWN, may_proceed


# ───────────────────────── fixtures ─────────────────────────────────────────


def _arc(*, status="in-progress", description="", headline_mechanic="",
         proposed=None, scoped=None) -> dict:
    d = {"id": "arc-999", "slug": "test-arc", "status": status,
         "description": description, "headline_mechanic": headline_mechanic}
    if proposed is not None:
        d["proposed_scoped_drivers"] = proposed
    if scoped is not None:
        d["scoped_drivers"] = scoped
    return d


PASS_CHECKS = {
    "a": {"check": "scorable", "verdict": "pass", "reason": "handler exists for 'x'"},
    "b": {"check": "distinct", "verdict": "pass", "reason": "no collision"},
    "c": {"check": "distinguishes", "verdict": "pass",
          "reason": "80 chars, distinguishes from D2, Reliability"},
}


def _static_review(*, a="pass", a_reason="handler exists for 'x'",
                    b="pass", b_reason="no collision",
                    c="pass", c_reason="80 chars, distinguishes from D2, Reliability",
                    name="my-driver") -> dict:
    return {
        "arc": "arc-999", "verdict": "pass" if a == b == c == "pass" else "fail",
        "reviewer_id": "static-v1", "dry_run": True,
        "reviewed": [{
            "name": name, "id": None, "where": "proposed_scoped_drivers",
            "verdict": "pass" if a == b == c == "pass" else "fail",
            "checks": {
                "a": {"check": "scorable", "verdict": a, "reason": a_reason},
                "b": {"check": "distinct", "verdict": b, "reason": b_reason},
                "c": {"check": "distinguishes", "verdict": c, "reason": c_reason},
            },
            "ts": "2026-09-27T00:00:00Z", "reviewer_id": "static-v1",
        }],
    }


@pytest.fixture(autouse=True)
def _isolated_project_root(tmp_path, monkeypatch):
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
    monkeypatch.setattr(adj, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(adj, "POLICY_PATH", tmp_path / "policy" / "value-drivers.yaml")
    monkeypatch.setattr(adj, "ARCS_DIR", tmp_path / ".context" / "arcs")
    monkeypatch.setattr(adj, "_PROJECT_DIRECTIVES_CACHE", None)
    yield tmp_path


# ───────────────────────── (1) imports the contract, defines no second one ──


def test_no_local_verdict_state_constants():
    src = inspect.getsource(adj)
    for banned in ('GREEN = "', "GREEN = '", 'AMBER = "', "AMBER = '",
                   'RED = "', "RED = '", 'UNKNOWN = "', "UNKNOWN = '"):
        assert banned not in src, f"found a local re-definition: {banned!r}"


def test_no_local_reviewable_or_verdict_function():
    names = {name for name, _ in inspect.getmembers(adj, inspect.isfunction)
              if inspect.getmodule(_) is adj}
    assert "reviewable" not in names
    assert "verdict" not in names
    assert "may_proceed" not in names


def test_module_imports_from_judge_verdict():
    src = inspect.getsource(adj)
    assert "from lib.judge_verdict import" in src


# ───────────────────────── (2) WRAPS arc-driver-review.sh, doesn't replace ──


def test_arc_driver_review_sh_is_not_reimplemented():
    """A diff shows lib/arc-driver-review.sh untouched by T-3527 — this test
    pins that this module contains no re-implementation of check_a/b/c logic
    (the FUNCTION DEFINITIONS, not this module's own prose about them), only a
    subprocess call to the real thing."""
    src = inspect.getsource(adj)
    # No local def check_a/check_b/check_c and no direct estimator import — the
    # actual check bodies live only in arc-driver-review.sh.
    assert "def check_a(" not in src
    assert "def check_b(" not in src
    assert "def check_c(" not in src
    assert "bvp_estimator_review" not in src
    assert "_arc_driver_review_run" in src  # it is INVOKED, not reimplemented


def test_run_static_review_control_real_handler_passes():
    """Real subprocess call against the REAL repo's estimator, using a known
    handler id ('D-DISJOINT', confirmed live on arc parallel-execution-aef) —
    proves check (a) CAN genuinely pass through this wrap, not just fail."""
    arc_file = ROOT / ".context" / "arcs" / "parallel-execution-aef.yaml"
    if not arc_file.is_file():
        pytest.skip("fixture arc not present in this checkout")
    review = adj.run_static_review(arc_file, "D-DISJOINT", root=ROOT, framework_root=ROOT)
    assert not review.get("error"), review
    checks = review["reviewed"][0]["checks"]
    assert checks["a"]["verdict"] == "pass"


# ───────── (5) OBS-559: genuinely-unimportable estimator -> UNKNOWN, never RED ──


def _write_tooling_broken_fixture(tmp_path) -> tuple[Path, Path]:
    """A PROJECT_ROOT/FRAMEWORK_ROOT with NO agents/termlink/bvp-estimator/ at
    all — a REAL unimportable state (est_path resolves to a path whose parent
    directory does not exist), not a mock that returns an error."""
    broken_root = tmp_path / "broken-fw"
    (broken_root / "policy").mkdir(parents=True)
    (broken_root / "policy" / "value-drivers.yaml").write_text(
        "protected_drivers: []\nfree_drivers: []\n")
    arc_file = broken_root / "test-arc.yaml"
    arc_file.write_text(yaml.safe_dump({
        "id": "arc-999", "slug": "test-arc", "status": "in-progress",
        "proposed_scoped_drivers": [{
            "name": "my-driver",
            "rationale": "x" * 70 + " distinguishes clearly from D2 (Reliability).",
        }],
    }))
    return broken_root, arc_file


def test_run_static_review_genuinely_unimportable_estimator_is_detected(tmp_path):
    broken_root, arc_file = _write_tooling_broken_fixture(tmp_path)
    review = adj.run_static_review(arc_file, "my-driver", root=broken_root,
                                    framework_root=broken_root)
    assert not review.get("error"), review
    reason_a = review["reviewed"][0]["checks"]["a"]["reason"]
    assert adj._is_tooling_failure(reason_a), (
        f"expected a tooling-failure signature, got: {reason_a!r}")


def test_is_tooling_failure_recognises_both_known_signatures():
    assert adj._is_tooling_failure(
        "handler table unreadable (AttributeError: module 'x' has no attribute '_handler_table')")
    assert adj._is_tooling_failure(
        "estimator unimportable, cannot validate a scoring spec (ImportError: nope)")


def test_is_tooling_failure_does_not_match_genuine_absence():
    """The REAL quality failure ('no handler, no inline scoring: block, no
    scoring_file:') must NOT be swept into UNKNOWN — that would hide a genuine
    finding behind the tooling exemption."""
    assert not adj._is_tooling_failure(
        "no handler, no inline scoring: block, no scoring_file: (T-3428)")


def test_judge_driver_end_to_end_tooling_failure_is_unknown_not_red(tmp_path):
    """Full pipeline (judge_driver, real subprocess via run_static_review, no
    injection) against the genuinely-broken fixture: UNKNOWN with guidance,
    never RED. This is the OBS-559 regression pin at the level a live call
    would actually exercise it."""
    broken_root, arc_file = _write_tooling_broken_fixture(tmp_path)
    arc_data = yaml.safe_load(arc_file.read_text())
    v, reason = adj.judge_driver("test-arc", arc_file, arc_data, "my-driver",
                                  static_review=adj.run_static_review(
                                      arc_file, "my-driver", root=broken_root,
                                      framework_root=broken_root))
    assert v is not None
    assert v["state"] == UNKNOWN, f"tooling failure must not read as RED: {v}"
    assert v["guidance"]
    assert may_proceed(v) is False
    assert reason == "scorability check unavailable (tooling)"


def test_genuine_scorability_absence_is_still_red_not_swallowed():
    """The control this pin needs: a driver that genuinely has no handler/spec
    (not a tooling problem) must still be RED — OBS-559's fix must not become
    'nothing about check (a) ever fails'."""
    arc_data = _arc(status="in-progress", description="x", headline_mechanic="y",
                     proposed=[{"name": "my-driver", "rationale": "x" * 70}])
    static_review = _static_review(
        a="fail", a_reason="no handler, no inline scoring: block, no scoring_file: (T-3428)")
    v, reason = adj.judge_driver("test-arc", Path("/dev/null"), arc_data, "my-driver",
                                  static_review=static_review)
    assert v is not None
    assert v["state"] == RED
    assert reason == "static check failed"


# ───────────────────────── (3) the arc-goal yardstick ───────────────────────


def test_check_self_admission_catches_calibrated_live_examples():
    """The two real, calibrated hits from the live corpus (see module docstring)."""
    r1 = ("(WEAK candidate per R5 — flagged for operator decision.) ... operator may "
          "prefer to keep this folded into D3 and approve --none on this candidate. "
          "See OQ-2 in artefact for the open question.")
    r2 = ("if F-AUTONOMY captures this dimension at global scope, this scoped driver "
          "becomes redundant. R2: weight 3 — propose only if operator wants the "
          "arc-scoped axis. Likely to be withdrawn after F-AUTONOMY activation settles.")
    assert adj.check_self_admission(r1)
    assert adj.check_self_admission(r2)


def test_check_self_admission_does_not_fire_on_ordinary_rationale():
    ordinary = ("Distinguishes from D2 (Reliability) by measuring how well the "
                "estimator's scores agree with human-confirmed scores over time.")
    assert adj.check_self_admission(ordinary) == []


def test_judge_driver_amber_on_self_admission():
    """AMBER, not RED: the static checks already passed, and this is the
    candidate's OWN text expressing doubt, not a structural defect — amber's
    contract meaning ("proceed, and record the guidance") fits, matching how
    the sibling BVP judge treats a thin-but-present case."""
    arc_data = _arc(description="x", headline_mechanic="y", proposed=[{
        "name": "weak-one",
        "rationale": ("Distinguishes from D2. (WEAK candidate per R5 — flagged for "
                      "operator decision.) Operator may prefer to keep this folded."),
    }])
    v, reason = adj.judge_driver("test-arc", Path("/dev/null"), arc_data, "weak-one",
                                  static_review=_static_review(name="weak-one"))
    assert v is not None
    assert v["state"] == AMBER
    assert reason == "self-admitted weak candidate"
    assert "weak candidate" in v["guidance"] or "distinguish" in v["guidance"].lower()
    assert may_proceed(v) is True


def test_resolve_arc_goal_arc_level():
    data = _arc(description="A real objective.", headline_mechanic="")
    level, goal, _notes = adj.resolve_arc_goal(data)
    assert level == "arc"
    assert "A real objective." in goal


def test_resolve_arc_goal_falls_back_to_project_level():
    data = _arc(description="", headline_mechanic="")
    level, goal, _notes = adj.resolve_arc_goal(data)
    assert level == "project"
    assert "D1" in goal


def test_resolve_arc_goal_unknown_when_nothing_resolves(tmp_path):
    (tmp_path / "policy" / "value-drivers.yaml").write_text("protected_drivers: []\n")
    adj._PROJECT_DIRECTIVES_CACHE = None
    data = _arc(description="", headline_mechanic="")
    level, _goal, _notes = adj.resolve_arc_goal(data)
    assert level == ""


def test_judge_driver_high_weight_on_project_fallback_only_is_red(tmp_path):
    (tmp_path / "policy" / "value-drivers.yaml").write_text("protected_drivers: []\n")
    adj._PROJECT_DIRECTIVES_CACHE = None
    (tmp_path / "policy" / "value-drivers.yaml").write_text(textwrap.dedent("""\
        protected_drivers:
          - id: D1
            name: Antifragility
            note: "some note"
        """))
    adj._PROJECT_DIRECTIVES_CACHE = None
    arc_data = _arc(description="", headline_mechanic="", proposed=[{
        "name": "big-claim", "weight_suggestion": 6,
        "rationale": "Distinguishes clearly from D2 (Reliability) at real length here for sure.",
    }])
    v, reason = adj.judge_driver("test-arc", Path("/dev/null"), arc_data, "big-claim",
                                  static_review=_static_review(name="big-claim"))
    assert v["state"] == RED
    assert reason == "high weight rests on project fallback only"


def test_judge_driver_modest_weight_on_project_fallback_is_green(tmp_path):
    """The SAME project-only fallback is fine for a modest weight — mirrors
    bvp_judge's 'same high claim is fine with a task-level objective' control,
    inverted: a LOW claim is fine even without an arc-level objective."""
    arc_data = _arc(description="", headline_mechanic="", proposed=[{
        "name": "modest-claim", "weight_suggestion": 2,
        "rationale": "Distinguishes clearly from D2 (Reliability) at real length here for sure.",
    }])
    v, reason = adj.judge_driver("test-arc", Path("/dev/null"), arc_data, "modest-claim",
                                  static_review=_static_review(name="modest-claim"))
    assert v["state"] == GREEN


# ───────────────────────── population: closed arcs, missing drivers ─────────


def test_closed_arc_is_skipped_not_judged(tmp_path):
    arc_data = _arc(status="closed", description="x", headline_mechanic="y",
                     proposed=[{"name": "d", "rationale": "x" * 70}])
    v, reason = adj.judge_driver("test-arc", Path("/dev/null"), arc_data, "d")
    assert v is None
    assert "closed" in reason


def test_abandoned_arc_is_skipped_not_judged(tmp_path):
    arc_data = _arc(status="abandoned", description="x", headline_mechanic="y",
                     proposed=[{"name": "d", "rationale": "x" * 70}])
    v, reason = adj.judge_driver("test-arc", Path("/dev/null"), arc_data, "d")
    assert v is None
    assert "closed" in reason


def test_unknown_driver_name_is_skipped_not_judged(tmp_path):
    arc_data = _arc(description="x", headline_mechanic="y",
                     proposed=[{"name": "d", "rationale": "x" * 70}])
    v, reason = adj.judge_driver("test-arc", Path("/dev/null"), arc_data, "nonexistent")
    assert v is None
    assert "nonexistent" in reason


def test_already_approved_driver_is_judgeable_too(tmp_path):
    """Mirrors arc-driver-review.sh's own selection fallback — an already
    approved (scoped_drivers:) entry is judgeable read-only, which is how the
    six live drivers the T-3428 audit names get a verdict at all."""
    arc_data = _arc(description="x", headline_mechanic="y", scoped=[{
        "name": "approved-one",
        "rationale": "Distinguishes clearly from D2 (Reliability) at real length here.",
        "weight": 3,
    }])
    v, reason = adj.judge_driver("test-arc", Path("/dev/null"), arc_data, "approved-one",
                                  static_review=_static_review(name="approved-one"))
    assert v is not None
    assert v["state"] == GREEN


# ───────────────────────── UNKNOWN never green; judgeable != UNKNOWN ────────


def test_unknown_is_never_falsely_favourable():
    from lib.judge_verdict import verdict as make_verdict
    v = make_verdict(UNKNOWN, guidance="cannot tell")
    assert bool(v) is True
    assert may_proceed(v) is False


def test_judgeable_driver_does_not_come_back_unknown(tmp_path):
    """Control leg (explicitly required by the AC): a normal, well-formed
    driver on a normal arc must NOT come back UNKNOWN."""
    arc_data = _arc(description="A real arc objective.", headline_mechanic="agent does X",
                     proposed=[{
                         "name": "clean-driver", "weight_suggestion": 3,
                         "rationale": ("Distinguishes clearly from D2 (Reliability) by "
                                       "measuring something D2 does not, at real length."),
                     }])
    v, reason = adj.judge_driver("test-arc", Path("/dev/null"), arc_data, "clean-driver",
                                  static_review=_static_review(name="clean-driver"))
    assert v is not None
    assert v["state"] != UNKNOWN, f"a judgeable driver must not fail safe into UNKNOWN: {v}"
    assert v["state"] == GREEN


# ───────────────────────── (7) mutant that always returns green is killed ──


def test_always_green_mutant_is_killed_by_static_failure_test(monkeypatch, tmp_path):
    from lib.judge_verdict import verdict as make_verdict

    def _always_green(arc_id, arc_file, arc_data, name, *, judge_id=adj.JUDGE_ID,
                       static_review=None):
        return make_verdict(GREEN, judged=f"{arc_id}/{name}", judge=judge_id), "mutant: always green"

    monkeypatch.setattr(adj, "judge_driver", _always_green)

    arc_data = _arc(description="x", headline_mechanic="y",
                     proposed=[{"name": "d", "rationale": "x" * 70}])
    v, reason = adj.judge_driver("test-arc", Path("/dev/null"), arc_data, "d",
                                  static_review=_static_review(
                                      b="fail", b_reason="duplicates D1"))
    assert v["state"] == GREEN  # the mutant IS active

    monkeypatch.undo()
    v_real, _ = adj.judge_driver("test-arc", Path("/dev/null"), arc_data, "d",
                                  static_review=_static_review(
                                      b="fail", b_reason="duplicates D1"))
    assert v_real["state"] == RED, "mutant would have been undetected if this held"


# ───────────────────────── helpers: _norm / find_driver_entry / list_names ──


def test_norm_folds_case_whitespace_punctuation():
    assert adj._norm("Loop closure (conditional)") == adj._norm("loop-closure-conditional")


def test_find_driver_entry_prefers_proposed_then_scoped():
    data = _arc(proposed=[{"name": "p1"}], scoped=[{"name": "s1"}])
    e, where = adj.find_driver_entry(data, "p1")
    assert where == "proposed_scoped_drivers"
    e, where = adj.find_driver_entry(data, "s1")
    assert where == "scoped_drivers"
    e, where = adj.find_driver_entry(data, "nope")
    assert e is None


def test_list_driver_names_dedupes_across_both_fields():
    data = _arc(proposed=[{"name": "A"}, {"name": "B"}],
                scoped=[{"name": "a"}])  # same as A, case/fold-insensitive
    names = adj.list_driver_names(data)
    assert names == ["A", "B"]
