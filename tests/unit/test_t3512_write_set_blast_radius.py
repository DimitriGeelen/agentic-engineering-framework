"""T-3512: blast_radius falls back to the DECLARED write_set before close.

`components:` is resolved from real git history at the `work-completed` transition,
and `fw bvp` excludes work-completed by default — so the 0.6-weighted cost term is
unavailable for exactly the open tasks the ranking exists to order. Measured
2026-09-27: 30 of 200 rankable tasks (15%) had any cost at all.

Two properties matter more than the arithmetic, and both are controls here:

  1. PRECEDENCE. `components:` is a measurement, `write_set:` a prediction.
     Measurement wins, which means no task that already scores can change its
     score. If that leg breaks, this change silently rewrites existing history.

  2. ABSENCE IS NOT ZERO. T-3068 exists because absence-as-0 is the cheapest value
     on the heaviest cost term, so it reads as *attractiveness* and an HV/LC filter
     promotes on it. This arc already had to reject 93 tasks' worth of pre-T-3068
     fabricated zeros whose evidence read "blast_radius=0 (no-signal)". A declared
     empty set is genuinely 0 — and must carry a DIFFERENT token so the two can
     never be confused in the record.

Anchored to a temp tree, never the live corpus: `lib/*.py` expands to 68 files
today and a different number next week, and a test pinned to that is the
mutable-corpus-anchor defect (T-3326) this repo has already paid for twice.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "agents" / "termlink" / "bvp-estimator"))
import estimator as E  # noqa: E402


@pytest.fixture()
def tree(tmp_path, monkeypatch):
    """A tiny project tree with a known file count, so the ladder is deterministic."""
    (tmp_path / "lib").mkdir()
    for i in range(4):
        (tmp_path / "lib" / f"f{i}.py").write_text("x\n", encoding="utf-8")
    (tmp_path / "one.txt").write_text("x\n", encoding="utf-8")
    monkeypatch.setattr(E, "PROJECT_ROOT", tmp_path)
    return tmp_path


def score(fm):
    return E.score_blast_radius(fm, "", [])


# ── absence stays unknown ────────────────────────────────────────────────────


def test_no_write_set_and_no_components_is_unknown(tree):
    v, ev = score({})
    assert v is None
    assert "UNMEASURED-not-zero" in ev[0]


def test_null_write_set_is_absence_not_an_empty_declaration(tree):
    # `write_set:` with nothing after it parses as None, which is how a commented
    # template field reads once uncommented and left blank. That is absence.
    v, _ = score({"write_set": None})
    assert v is None


def test_malformed_write_set_is_unknown_not_a_guess(tree):
    v, ev = score({"write_set": "lib/f0.py"})  # a string, not a list
    assert v is None
    assert "write_set-malformed" in ev[0]


# ── a declaration produces a score ──────────────────────────────────────────


def test_single_declared_path_scores_one(tree):
    v, ev = score({"write_set": ["one.txt"]})
    assert v == 1
    assert "write-set" in ev[0]


def test_glob_expands_and_climbs_the_ladder(tree):
    v, ev = score({"write_set": ["lib/*.py"]})
    assert v == 5          # 4 files → the 4..6 rung
    assert "4-write-set-paths" in ev[0]


def test_the_evidence_token_names_write_set_as_the_source(tree):
    # A reader of cost_estimate_proposed must be able to tell which source produced
    # the number — components, write_set, or an inception's target_blast_radius.
    _, ev = score({"write_set": ["one.txt"]})
    assert "write-set" in ev[0]
    assert "component" not in ev[0]


def test_a_declared_path_that_does_not_exist_yet_still_counts(tree):
    # expand_globs keeps a non-matching pattern as-is, on purpose, so two tasks
    # declaring the same unborn file overlap correctly. A task about to CREATE
    # three files has a blast radius of three; "not on disk yet" is a fact about
    # the clock, not missing information.
    v, _ = score({"write_set": ["lib/not_created_yet.py"]})
    assert v == 1


# ── the two controls ────────────────────────────────────────────────────────


def test_components_outrank_write_set(tree):
    # THE precedence control. components: is measured from git history; write_set:
    # is declared. If this inverts, the change rewrites scores that already exist
    # instead of only filling gaps.
    v, ev = score({"components": ["c1"], "write_set": ["lib/*.py"]})
    assert v == 1                      # single-component, NOT the 4-file write set
    assert "single-component" in ev[0]


def test_write_set_is_only_reachable_where_components_is_empty(tree):
    with_ws = score({"components": ["c1", "c2"], "write_set": ["lib/*.py"]})
    without_ws = score({"components": ["c1", "c2"]})
    assert with_ws == without_ws       # adding a write_set changes nothing


# ── the zero that is allowed, and the one that is not ───────────────────────


def test_explicitly_empty_write_set_scores_zero(tree):
    v, _ = score({"write_set": []})
    assert v == 0


def test_the_declared_zero_is_labelled_differently_from_a_fabricated_one(tree):
    # The 93 pre-T-3068 zeros in the live corpus carry "no-signal". A declared zero
    # must never be able to read as one of those, because the whole reason this arc
    # refused to recover them was that they were indistinguishable from measurements.
    _, ev = score({"write_set": []})
    assert "DECLARED" in ev[0]
    assert "no-signal" not in ev[0]
    assert "UNMEASURED" not in ev[0]


def test_empty_list_and_missing_field_do_not_score_the_same(tree):
    declared_empty, _ = score({"write_set": []})
    absent, _ = score({})
    assert declared_empty == 0
    assert absent is None
    assert declared_empty != absent


# ── the delegation that keeps one reader ────────────────────────────────────


def test_expansion_delegates_to_lib_write_set(tree, monkeypatch):
    # `fw write-set check` and the estimator must agree about what a pattern
    # covers. Two readers of one field that disagree is the arc-membership defect
    # (five readers, three verdicts) this repo spent a day removing.
    called = {}

    real = E._expand_write_set

    def spy(patterns):
        called["patterns"] = list(patterns)
        return real(patterns)

    monkeypatch.setattr(E, "_expand_write_set", spy)
    score({"write_set": ["lib/*.py"]})
    assert called["patterns"] == ["lib/*.py"]


def test_expansion_failure_degrades_to_pattern_count_and_says_so(tree, monkeypatch):
    # If the shared lib cannot be loaded, fall back to counting patterns — but the
    # evidence must record that a weaker signal was used, not imply a file count.
    monkeypatch.setattr(E, "_expand_write_set", lambda patterns: None)
    v, ev = score({"write_set": ["lib/*.py", "one.txt"]})
    assert v == 3                       # 2 patterns → the 2..3 rung
    assert "unexpanded" in ev[0]
