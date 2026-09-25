"""T-3486 — the BVP outcomes ledger and its cost join (slice 1 of T-3484).

The property under test throughout: **unmeasured cost must be distinguishable
from zero cost.** Everything else in this file supports that one assertion,
because the failure it prevents is silent and directional — an unattributable
task recorded as 0 tokens looks CHEAP, so a Q1-first selector would prefer
exactly the work nobody can measure.

No live corpus counts are pinned (T-3326) — every dispatch row here is a fixture.
"""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib import bvp_outcomes as bo  # noqa: E402


def _usage(i=100, o=200, cr=300, cc=400):
    return {"input_tokens": i, "output_tokens": o,
            "cache_read_input_tokens": cr, "cache_creation_input_tokens": cc}


@pytest.fixture()
def repo(tmp_path):
    (tmp_path / ".context").mkdir(parents=True)
    return tmp_path


def _write_dispatches(repo, rows):
    p = repo / ".context" / "dispatches.jsonl"
    with p.open("w", encoding="utf-8") as fh:
        for r in rows:
            fh.write(json.dumps(r) + "\n")
    return p


# ── the join ────────────────────────────────────────────────────────────────

def test_cost_sums_a_single_dispatch(repo):
    _write_dispatches(repo, [
        {"task_id": "T-1", "dispatch_id": "d1", "terminal_event": {"usage": _usage()}},
    ])
    c = bo.cost_for_task("T-1", root=repo)
    assert c["attributable"] is True
    assert (c["tokens_in"], c["tokens_out"], c["cache_read"], c["cache_create"]) == (100, 200, 300, 400)
    assert c["dispatch_rows"] == 1
    assert "dispatches.jsonl" in c["source"]


def test_two_dispatches_for_one_task_SUM(repo):
    """A task dispatched twice cost both. Overwriting would under-report."""
    _write_dispatches(repo, [
        {"task_id": "T-2", "dispatch_id": "d1", "terminal_event": {"usage": _usage(10, 20, 30, 40)}},
        {"task_id": "T-2", "dispatch_id": "d2", "terminal_event": {"usage": _usage(1, 2, 3, 4)}},
    ])
    c = bo.cost_for_task("T-2", root=repo)
    assert (c["tokens_in"], c["tokens_out"]) == (11, 22)
    assert c["dispatch_rows"] == 2


def test_other_tasks_rows_are_not_absorbed(repo):
    _write_dispatches(repo, [
        {"task_id": "T-3", "terminal_event": {"usage": _usage(5, 5, 5, 5)}},
        {"task_id": "T-4", "terminal_event": {"usage": _usage(99, 99, 99, 99)}},
    ])
    assert bo.cost_for_task("T-3", root=repo)["tokens_in"] == 5


def test_a_dispatch_row_with_no_usage_block_measures_nothing(repo):
    """Present-but-empty is not a measurement. 1458 of 2565 live rows are this."""
    _write_dispatches(repo, [{"task_id": "T-5", "dispatch_id": "d1"}])
    assert bo.cost_for_task("T-5", root=repo) is None


def test_missing_dispatches_file_is_unmeasured_not_zero(repo):
    assert bo.cost_for_task("T-6", root=repo) is None


# ── THE CONTROL LEG: unmeasured must not look like zero ─────────────────────

def test_unattributable_is_distinguishable_from_a_genuine_zero(repo):
    """The assertion this whole module exists for.

    A task with no attribution and a task that genuinely consumed zero tokens
    must not produce the same row. If they did, a Q1-first selector would treat
    unmeasurable work as the cheapest work available.
    """
    _write_dispatches(repo, [
        {"task_id": "T-ZERO", "terminal_event": {"usage": _usage(0, 0, 0, 0)}},
    ])
    measured_zero = bo.cost_for_task("T-ZERO", root=repo)
    unmeasured = bo.cost_for_task("T-ABSENT", root=repo)

    assert measured_zero is not None and measured_zero["attributable"] is True
    assert measured_zero["tokens_in"] == 0          # a real zero, recorded as zero
    assert unmeasured is None                        # absence, not zero

    row = bo.unattributable()
    assert row["attributable"] is False
    for key in ("tokens_in", "tokens_out", "cache_read", "cache_create"):
        assert key not in row, (
            f"{key} present on an unattributable row — it would average as 0 "
            "and make unmeasured work look cheap")


# ── the ledger ──────────────────────────────────────────────────────────────

def test_append_is_append_only(repo):
    bo.append({"task_id": "T-7", "phase": "realised", "ts": "t1"}, root=repo)
    bo.append({"task_id": "T-7", "phase": "revisit", "ts": "t2"}, root=repo)
    rows = bo.read_rows(root=repo)
    assert [r["phase"] for r in rows] == ["realised", "revisit"]
    assert len(rows) == 2, "a second record must add a row, never rewrite the first"


def test_append_refuses_an_unknown_phase(repo):
    with pytest.raises(bo.OutcomeError):
        bo.append({"task_id": "T-8", "phase": "made-up"}, root=repo)


def test_append_refuses_a_row_with_no_task(repo):
    with pytest.raises(bo.OutcomeError):
        bo.append({"phase": "realised"}, root=repo)


def test_record_realised_carries_rubric_and_prediction(repo):
    _write_dispatches(repo, [
        {"task_id": "T-9", "terminal_event": {"usage": _usage()}},
    ])
    row = bo.record_realised("T-9", ts="2026-09-26T00:00:00Z",
                             rubric_sha="abc123",
                             predicted={"D1": 4, "D2": 4}, root=repo)
    assert row["rubric_sha"] == "abc123"
    assert row["predicted"]["D1"] == 4
    assert row["cost"]["attributable"] is True
    assert bo.read_rows(root=repo)[0]["task_id"] == "T-9"


def test_record_realised_on_unmeasurable_work_says_so(repo):
    row = bo.record_realised("T-10", ts="t", root=repo)
    assert row["cost"]["attributable"] is False
    assert "tokens_in" not in row["cost"]


# ── the bias report ─────────────────────────────────────────────────────────

def test_attributable_fraction_reports_the_bias(repo):
    rows = [
        {"cost": {"attributable": True}},
        {"cost": {"attributable": False}},
        {"cost": {"attributable": False}},
    ]
    f = bo.attributable_fraction(rows)
    assert f == {"rows": 3, "attributable": 1, "unattributable": 2, "fraction": 1 / 3}


def test_attributable_fraction_of_nothing_is_None_not_zero(repo):
    """An empty set has no fraction. 0.0 would read as 'nothing is attributable',
    which is a measurement; None is the absence of one."""
    assert bo.attributable_fraction([])["fraction"] is None


# ── the fence ───────────────────────────────────────────────────────────────

def test_module_does_not_reach_into_the_scorer():
    """Slice 1 is deliberately decoupled from lib/bvp.sh.

    Both because a live worker owned that file when this was written, and
    because a ledger coupled to the thing it measures cannot be read while that
    thing is mid-change.
    """
    src = Path(bo.__file__).read_text(encoding="utf-8")
    assert "bvp.sh" not in src.replace("lib/bvp.sh`", "")  # prose reference only
    assert "value-drivers" not in src.replace("policy/value-drivers.yaml`", "")
