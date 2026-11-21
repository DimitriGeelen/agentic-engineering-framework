"""T-5353: one decision point for "this criterion's evidence needs a proven view of screenshots".

T-5352 made a page-naming non-render criterion (a designer re-pin naming /designer) get
screenshots, but the ledger (`_run_fault`) and the vote checker (`checkable`, T-5327
ATTACHED_ONLY) still asked `render` only, so a single-seat green whose every image was proven
only "attached at launch" counted on it. `lib/evidence_need.py` now holds the test; the judge
and the ledger import it.

Hermetic: real verdict/1 votes checked against fake seat records (the T-5327 fixtures), task
criteria parsed from text, the render classifier and the run lookup monkeypatched. No git
history, no server, no browser.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent.parent))
sys.path.insert(0, str(_HERE))

from lib import evidence_need  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib import vote_checker as vc  # noqa: E402
from lib.delegation import human_criteria  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
from test_t5309_seat_image_proof import evidence  # noqa: E402,F401  (fixture)
from test_t5327_attached_only import (  # noqa: E402,F401  (fixtures)
    PANEL, SINGLE, _row, claude_check, codex_check)

PAGE_AC = ("- [ ] [REVIEW] The starter map opens on `/designer` with the 832 layout\n"
           "  **Steps:** 1. open the page\n  **Expected:** the starter map shows\n"
           "  **If not:** note it\n")
PLAIN_AC = ("- [ ] [REVIEW] The release notes read clearly to a consumer\n"
            "  **Steps:** 1. read docs/releases/v1.md\n  **Expected:** plain language\n"
            "  **If not:** note it\n")


def _crit(ac: str):
    return human_criteria("## Acceptance Criteria\n\n### Human\n" + ac)[0]


@pytest.fixture
def render_is(monkeypatch):
    def set_(flag: bool):
        monkeypatch.setattr(vl, "_is_render_review", lambda ctx, crit: flag)
    return set_


# ── one decision point ──────────────────────────────────────────────────────────────────────

def test_judge_and_ledger_share_one_predicate():
    assert judge_cli.needs_screenshots is evidence_need.needs_screenshots
    assert judge_cli.names_page is evidence_need.names_page


def test_ledger_predicate_matches_the_judge_partition(render_is):
    for ac in (PAGE_AC, PLAIN_AC):
        crit = _crit(ac)
        body = vl.criterion_body(crit)
        for render in (False, True):
            render_is(render)
            item = {"render": render,
                    "page": render or judge_cli.names_page(f"{crit.title}\n{body}")}
            assert vl._needs_view(object(), crit) == judge_cli.needs_screenshots(item)


# ── the four cases of the task's second criterion ───────────────────────────────────────────

def test_1_page_criterion_attached_only_single_seat_is_not_checkable(codex_check, render_is):
    render_is(False)
    row, crit = _row(codex_check, SINGLE), _crit(PAGE_AC)
    assert vl.not_checkable_reasons(row, object(), crit) == [f"AC2: {vc.ATTACHED_ONLY}"]
    assert not vl._counts(row, object(), crit)
    # a rung-5 panel seat is unchanged (T-5327)
    assert vl.not_checkable_reasons(_row(codex_check, PANEL), object(), crit) == []


def test_2_page_criterion_with_logged_view_is_checkable(claude_check, render_is):
    render_is(False)
    row, crit = _row(claude_check, SINGLE), _crit(PAGE_AC)
    assert vl.not_checkable_reasons(row, object(), crit) == []
    assert vl._counts(row, object(), crit)


def test_3_render_criterion_unchanged(codex_check, claude_check, render_is):
    render_is(True)
    for ac in (PAGE_AC, PLAIN_AC):
        crit = _crit(ac)
        assert vl.not_checkable_reasons(_row(codex_check, SINGLE), object(), crit) == \
            [f"AC2: {vc.ATTACHED_ONLY}"]
        assert vl.not_checkable_reasons(_row(claude_check, SINGLE), object(), crit) == []
        assert vl.not_checkable_reasons(_row(codex_check, PANEL), object(), crit) == []


def test_4_criterion_naming_no_page_and_no_image_unchanged(codex_check, render_is):
    render_is(False)
    crit = _crit(PLAIN_AC)
    assert not evidence_need.names_page(vl.criterion_body(crit))
    assert not judge_cli.names_image(vl.criterion_body(crit))
    assert vl.not_checkable_reasons(_row(codex_check, SINGLE), object(), crit) == []


# ── _run_fault: captures required as for render; the visual checklist stays render-only ─────

class _Ctx:
    root = Path(".")
    task_id = "T-9353"


def _green(ac=1, run_id="", cited=()):
    return {"dispatch_id": "D-1", "run_id": run_id, "rung": "rung-3-termlink-single-reviewer",
            "ac": ac, "evidence_sha256": {f"e{i}": s for i, s in enumerate(cited)}}


def test_run_fault_page_criterion_needs_a_run(monkeypatch, render_is):
    render_is(False)
    monkeypatch.setattr(vl, "run_for_dispatch", lambda root, d: (None, None, ""))
    f = vl._run_fault(_Ctx(), _green(), _crit(PAGE_AC), recording=False)
    assert f and f[0] == "render-needs-run" and "names a page" in f[1]
    assert vl._run_fault(_Ctx(), _green(), _crit(PLAIN_AC), recording=False) is None


def test_run_fault_page_criterion_needs_cited_captures_not_the_visual_checklist(monkeypatch, render_is):
    render_is(False)
    run = {"run_id": "R-1", "task": "T-9353", "acs": [1], "pages": {"1": ["/designer"]},
           "captures": [{"page": "/designer", "ok": True, "sha256": "aa" * 32}], "visual": None}
    monkeypatch.setattr(vl, "run_for_dispatch", lambda root, d: (run, None, ""))
    crit = _crit(PAGE_AC)
    f = vl._run_fault(_Ctx(), _green(run_id="R-1"), crit, recording=False)
    assert f and f[0] == "unseen-page"
    assert vl._run_fault(_Ctx(), _green(run_id="R-1", cited=["aa" * 32]), crit,
                         recording=False) is None
    # a render criterion with the same run still needs the T-4202 visual record
    render_is(True)
    f = vl._run_fault(_Ctx(), _green(run_id="R-1", cited=["aa" * 32]), crit, recording=False)
    assert f and f[0] == "visual-needs-run"
