"""T-3175: decided-but-unclosed inceptions must reach a queue.

WHY THE CONTROL LEGS MATTER MORE THAN THE POSITIVE ONES HERE.
The bug being fixed is a selector whose candidate set was empty by construction —
the same shape as T-3099's GO-scope detector, which printed PASS for months while
selecting nothing. A selector that returned EVERYTHING would satisfy every
"is it found?" assertion in this file and would be just as wrong: it would bury
the real closures under 150 pending ones, which is a different way of showing the
operator nothing.

So each positive case is paired with a negative that must come back empty:
pending (belongs to the other section), work-completed (already carried by the
Human-ACs section), non-inception, and completed/. If a mutation makes the
predicate always-true, the negatives go red; always-false, the positives go red.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lib"))

import decided_unclosed  # noqa: E402


def _fm(task_id, *, wf="inception", loc="active", status="started-work", owner="human"):
    return {
        "id": task_id,
        "name": f"{task_id} name",
        "workflow_type": wf,
        "_location": loc,
        "status": status,
        "owner": owner,
        "_path": f"/fake/{task_id}.md",
    }


def _reader(bodies):
    return lambda p: bodies.get(p, "")


# --- extract_decision ------------------------------------------------------

def test_extracts_each_verdict():
    for verdict in ("GO", "NO-GO", "DEFER"):
        assert decided_unclosed.extract_decision(f"**Decision**: {verdict}\n") == verdict


def test_no_decision_returns_none():
    assert decided_unclosed.extract_decision("nothing here") is None
    assert decided_unclosed.extract_decision("") is None
    assert decided_unclosed.extract_decision(None) is None


def test_first_verdict_wins_when_two_conflict():
    """T-3142 found exactly one task in 3126 carrying two verdicts.

    First-match is chosen to agree with update-task.sh's grep-based gate. A queue
    that disagreed with the gate would route the operator to a task the gate then
    refuses to close.
    """
    body = "**Decision**: GO\n\nlater stub\n\n**Decision**: DEFER\n"
    assert decided_unclosed.extract_decision(body) == "GO"


# --- the predicate: positives ---------------------------------------------

def test_decided_go_still_open_is_selected():
    assert decided_unclosed.is_decided_unclosed(_fm("T-1"), "**Decision**: GO\n")


def test_decided_nogo_still_open_is_selected():
    assert decided_unclosed.is_decided_unclosed(_fm("T-1"), "**Decision**: NO-GO\n")


def test_agent_owned_is_selected_too():
    """Ownership is what makes the gate refuse, but it is not the operator-visible
    fact. An agent-owned decided inception is equally stuck and equally invisible;
    filtering on owner would reproduce the defect one bucket over."""
    assert decided_unclosed.is_decided_unclosed(_fm("T-1", owner="agent"), "**Decision**: GO\n")


# --- the control legs: these MUST come back false -------------------------

def test_control_pending_is_not_selected():
    """Belongs to the existing Decisions section. Claiming it here double-counts."""
    assert not decided_unclosed.is_decided_unclosed(_fm("T-1"), "no decision yet")


def test_control_defer_is_not_selected():
    """A DEFER is a park awaiting a date, not an action — it has revisit_at and the
    G-053 scan. Listing it as 'awaiting closure' would misdescribe it."""
    assert not decided_unclosed.is_decided_unclosed(_fm("T-1"), "**Decision**: DEFER\n")


def test_control_work_completed_is_not_selected():
    """Partial-complete is already carried by the Human-ACs section."""
    fm = _fm("T-1", status="work-completed")
    assert not decided_unclosed.is_decided_unclosed(fm, "**Decision**: GO\n")


def test_control_non_inception_is_not_selected():
    assert not decided_unclosed.is_decided_unclosed(_fm("T-1", wf="build"), "**Decision**: GO\n")


def test_control_completed_location_is_not_selected():
    """Already closed. It moved to completed/, which is the whole point."""
    fm = _fm("T-1", loc="completed")
    assert not decided_unclosed.is_decided_unclosed(fm, "**Decision**: GO\n")


# --- scan ------------------------------------------------------------------

def test_scan_selects_only_the_decided_open_ones():
    metas = [
        _fm("T-1"),                          # GO, open      -> in
        _fm("T-2"),                          # pending       -> out
        _fm("T-3", status="work-completed"),  # partial       -> out
        _fm("T-4", wf="build"),              # not inception -> out
    ]
    bodies = {
        "/fake/T-1.md": "**Decision**: GO\n",
        "/fake/T-2.md": "still exploring",
        "/fake/T-3.md": "**Decision**: GO\n",
        "/fake/T-4.md": "**Decision**: GO\n",
    }
    got = decided_unclosed.scan(metas, _reader(bodies))
    assert [r["task_id"] for r in got] == ["T-1"]
    assert got[0]["decision"] == "GO"


def test_scan_is_sorted_and_survives_empty_input():
    assert decided_unclosed.scan([], _reader({})) == []
    metas = [_fm("T-9"), _fm("T-2")]
    bodies = {"/fake/T-9.md": "**Decision**: GO\n", "/fake/T-2.md": "**Decision**: NO-GO\n"}
    got = decided_unclosed.scan(metas, _reader(bodies))
    assert [r["task_id"] for r in got] == ["T-2", "T-9"]


def test_scan_skips_a_meta_with_no_path():
    got = decided_unclosed.scan([{"workflow_type": "inception", "_location": "active"}], _reader({}))
    assert got == []
