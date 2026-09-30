"""T-3581 round 3 — ledger integrity against git history (OpenAI re-review). Every test has a control."""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_t3579_verdict_ledger import (  # noqa: E402,F401
    RENDERED, TASK, TASTE, _commit_ledger, _dg, _dispatch, _edit, _lines, _produce,
    _rec, _task, _ticked, root,
)
from lib import verdict_ledger as vl  # noqa: E402


def _rewrite(root, fn):
    """Apply fn(rows)->rows to the working ledger, keeping canonical serialisation."""
    p = root / vl.VERDICTS
    rows = [json.loads(x) for x in p.read_text().splitlines() if x.strip()]
    p.write_text("".join(json.dumps(r, separators=(",", ":"), sort_keys=True) + "\n" for r in fn(rows)))


def _flip_green(rows):
    """Turn every non-green row green, keeping id and dispatch — the substitution the reviewer found."""
    for r in rows:
        if r["outcome"] != "green":
            r.update(outcome="green", verdict="green", evidence=["evidence.md"])
            r["judgement"].update(state="green")
    return rows


def _red_then_flip(root, *, commit):
    _task(root, TASTE)
    _rec(root, "red")
    _rewrite(root, _flip_green)
    if commit:
        _commit_ledger(root)


# ── finding 1: content substitution ──────────────────────────────────────────────

def test_control_honest_committed_green_ticks(root):
    _task(root, TASTE)
    _rec(root)
    assert vl.load_ledger(root).faults == []
    assert [t["ac"] for t in vl.apply(TASK, root)["ticked"]] == [1]
    assert vl.audit(root)[0] == 0


def test_committed_red_rewritten_to_green_is_refused_and_fails_audit(root):
    _red_then_flip(root, commit=True)
    assert "append-only" in vl.load_ledger(root).faults[0]
    assert vl.apply(TASK, root)["ticked"] == [] and not _ticked(root)
    code, out = vl.audit(root)
    assert code == 2 and any("append-only" in ln for ln in out)


def test_uncommitted_replacement_of_a_committed_row_is_refused(root):
    _red_then_flip(root, commit=False)
    assert "unchanged" in vl.load_ledger(root).faults[0]
    assert vl.apply(TASK, root)["ticked"] == []
    assert vl.audit(root)[0] == 2


def test_deleted_withdrawal_row_blocks_instead_of_resurrecting_the_green(root):
    _task(root, TASTE)
    _rec(root)
    vl.apply(TASK, root)
    _rec(root, "red", dispatch_id=_dispatch(root, "rv-9"))
    assert vl.apply(TASK, root)["withdrawn"]            # the red withdrew the tick
    _rewrite(root, lambda rows: rows[:1])               # ...then the red row is deleted
    assert vl.apply(TASK, root)["ticked"] == [] and not _ticked(root)
    assert vl.audit(root)[0] == 2
    _commit_ledger(root)                                # committing the deletion does not launder it
    assert "append-only" in vl.load_ledger(root).faults[0]
    assert vl.apply(TASK, root)["ticked"] == []


def test_control_a_later_red_alone_withdraws_without_any_integrity_fault(root):
    _task(root, TASTE)
    _rec(root)
    _rec(root, "red", dispatch_id=_dispatch(root, "rv-9"))
    assert vl.load_ledger(root).faults == [] and vl.apply(TASK, root)["ticked"] == []


def test_duplicate_row_id_is_refused(root):
    _task(root, TASTE)
    _rec(root)
    _rewrite(root, lambda rows: rows + [dict(rows[0], outcome="red", verdict="red",
                                             judgement=dict(rows[0]["judgement"], state="red"))])
    _commit_ledger(root)
    assert "duplicate" in vl.load_ledger(root).faults[0]
    assert vl.apply(TASK, root)["ticked"] == [] and vl.audit(root)[0] == 2


def test_record_refuses_to_append_to_a_ledger_whose_history_does_not_verify(root):
    _red_then_flip(root, commit=True)
    with pytest.raises(vl.VerdictRefused, match="history does not verify"):
        vl.record(TASK, 1, "amber", reviewer="openai/gpt-5", rung="x", guidance="g",
                  dispatch_id=_dispatch(root, "rv-5"), digest=_dg(root), root=root)


# ── finding 2: audit uses the apply validator; history is not eligibility ─────────

def test_audit_fails_a_green_whose_judgement_state_is_inconsistent(root):
    _task(root, TASTE)
    _rec(root, commit=False)
    _rewrite(root, lambda rows: [dict(r, judgement=dict(r["judgement"], state="unknown")) for r in rows])
    _commit_ledger(root)
    assert vl.apply(TASK, root)["ticked"] == []         # apply already refused this...
    code, out = vl.audit(root)                          # ...and now audit agrees
    assert code == 2 and any("schema" in ln for ln in out)


def test_audit_validates_non_green_rows_too(root):
    _task(root, TASTE)
    _rec(root, "amber", commit=False)
    _rewrite(root, lambda rows: [dict(r, evidence="not-a-list") for r in rows])
    _commit_ledger(root)
    code, out = vl.audit(root)
    assert code == 2 and any("evidence" in ln for ln in out)


def test_control_superseded_verdict_stays_auditable(root):
    _task(root, TASTE)
    _rec(root)
    _edit(root, "1. Read it", "1. Skim it")             # criterion edited: the verdict is superseded
    assert vl.apply(TASK, root)["ticked"] == []
    assert vl.audit(root)[0] == 0                       # historical integrity is unaffected


def test_audit_and_apply_share_the_row_validator():
    import inspect
    assert "_row_fault(" in inspect.getsource(vl.audit)
    assert "_row_fault(" in inspect.getsource(vl._fault)


# ── finding 3: validate before selecting ──────────────────────────────────────────

def _later_malformed(root, drop, **over):
    _rec(root)
    _rewrite(root, lambda rows: rows + [{**{k: v for k, v in rows[0].items() if k not in drop},
                                         "id": "V-malformed", **over}])
    _commit_ledger(root)


def test_malformed_later_row_without_a_digest_blocks_instead_of_resurrecting_the_green(root):
    _task(root, TASTE)
    _later_malformed(root, drop=("ac_digest",))
    assert vl.apply(TASK, root)["ticked"] == [] and not _ticked(root)
    ctx = vl._task_ctx(root, TASK)
    crit = vl.human_criteria(ctx.text)[0]
    assert "malformed row" in vl.satisfying_verdict(ctx, crit)[1]


def test_malformed_row_with_an_unreadable_ac_blocks_every_criterion_of_the_task(root):
    _task(root, TASTE + TASTE.replace("summary paragraph", "second paragraph"))
    _later_malformed(root, drop=(), ac="one")
    assert vl.apply(TASK, root)["ticked"] == []


def test_control_a_malformed_row_for_another_task_or_criterion_does_not_block(root):
    _task(root, TASTE + TASTE.replace("summary paragraph", "second paragraph"))
    _rec(root)
    _rewrite(root, lambda rows: rows + [{k: v for k, v in rows[0].items() if k != "ac_digest"}
                                        | {"id": "V-other-ac", "ac": 2}])
    _commit_ledger(root)
    assert [t["ac"] for t in vl.apply(TASK, root)["ticked"]] == [1]


def test_a_row_naming_no_legible_task_blocks(root):
    _task(root, TASTE)
    _later_malformed(root, drop=("task",))
    assert vl.apply(TASK, root)["ticked"] == []


def test_uncommitted_row_for_the_criterion_blocks_rather_than_being_skipped(root):
    _task(root, TASTE)
    _rec(root)
    _rec(root, "red", commit=False, dispatch_id=_dispatch(root, "rv-9"))
    assert "uncommitted" in vl.satisfying_verdict(vl._task_ctx(root, TASK),
                                                  vl.human_criteria(_task_text(root))[0])[1]


def _task_text(root):
    return next((root / ".tasks" / "active").glob(f"{TASK}-*.md")).read_text()


# ── finding 4: render criteria (negative controls live in test_t3579 too) ─────────

def test_unrelated_green_plus_render_amber_fails_check_render(root):
    from test_t3579_verdict_ledger import _produce_render
    _task(root, TASTE + RENDERED)
    _produce_render(root)
    _rec(root, ac=1)
    _rec(root, "amber", ac=2)
    assert vl._cli(["check-render", TASK]) == 1
