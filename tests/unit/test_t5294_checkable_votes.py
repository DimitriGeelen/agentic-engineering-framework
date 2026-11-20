"""T-5294 (T-5290 GO, G-136): a verdict/1 vote that fails its own mechanical check does not count.

One rule (`vote_checker.checkable`) decides from a row's recorded `check` whether its vote holds up:
quotes found, locations exist, image regions inside their image, the seat opened every image it
cites ("cannot tell" is not "opened"), rule present, vote consistent. A not-checkable row counts
neither green nor red (close gate, panel, audit); the judge treats it like not-evaluated and seats
another kind; when none is left the criterion goes to the OPERATOR with the reasons. Old free-text
rows are counted exactly as before.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest
from PIL import Image

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_format as vf  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib import vote_checker as vc  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (autouse)
from t3580_judge_cli_test import (  # noqa: E402,F401
    TASTE, TID, FakeWorker, _judge, _mk_task, _produce, repo)

SHOT = f".context/working/judge-evidence/{TID}/02-page.png"
REAL_EXAMPLE = vf.example_vote


# ── the rule, on recorded checks ─────────────────────────────────────────────

def _quote(result="found-at-location", exists=True, normalised=None):
    return {"kind": "quote", "quote": "x", "location": "a.css:3", "path": "a.css",
            "location_exists": exists, "result": result, "normalised": normalised or result}


def _image(viewed: bool | None = True, inside=True, exists=True, agrees=True):
    return {"kind": "image", "image": SHOT, "image_exists": exists, "region": [895, 45, 65, 25],
            "region_inside": inside if exists else None, "location_agrees": agrees,
            "seat_viewed": viewed, "location": f"{SHOT} region 895,45,65,25"}


def _row(items, outcome="green", rule=True, consistent=True, **extra):
    check = {"checker": vc.CHECKER, "complete": True, "consistent": consistent,
             "criteria": {"1": {"vote": outcome, "items": items, "rule": {"present": rule}}}}
    return {"id": "V-x", "format": vf.FORMAT, "outcome": outcome, "check": check, **extra}


def test_a_fully_checked_vote_is_checkable():
    assert vc.checkable(_row([_quote(), _quote("found-elsewhere"), _image(True)])) == (True, [])


def test_whitespace_normalised_quote_counts_as_found():
    assert vc.checkable(_row([_quote("not-found", normalised="found-at-location")]))[0]


def test_t5262_red_on_an_image_the_seat_never_opened_is_not_checkable():
    ok, why = vc.checkable(_row([_image(viewed=False)], outcome="red"))
    assert not ok and any("did not open image" in w for w in why)


def test_cannot_tell_whether_opened_is_not_opened():
    ok, why = vc.checkable(_row([_image(viewed=None)]))
    assert not ok and any("cannot tell whether the seat opened" in w for w in why)


def test_green_quoting_a_line_that_does_not_exist_is_not_checkable():
    ok, why = vc.checkable(_row([_quote("not-found", exists=False)]))
    assert not ok
    assert any("does not exist" in w for w in why) and any("not found" in w for w in why)


@pytest.mark.parametrize("row,needle", [
    (_row([_image(inside=False)]), "outside"),
    (_row([_image(exists=False)]), "missing"),
    (_row([_image(agrees=False)]), "does not name image"),
    (_row([_quote()], rule=False), "rule missing"),
    (_row([_quote()], consistent=False), "inconsistent"),
    ({"format": vf.FORMAT, "outcome": "green", "check": {"error": "boom"}}, "errored"),
    ({"format": vf.FORMAT, "outcome": "green"}, "no check recorded"),
    (_row([{"kind": "error", "error": "x"}]), "errored"),
])
def test_every_other_reason_is_named(row, needle):
    ok, why = vc.checkable(row)
    assert not ok and any(needle in w for w in why), why


def test_a_command_location_alone_does_not_make_a_vote_not_checkable():
    it = {"kind": "quote", "quote": "x", "location": "command: ls", "result": "not-checkable",
          "location_exists": None}
    assert vc.checkable(_row([it])) == (True, [])


def test_an_old_free_text_row_counts_as_before():
    old = {"id": "V-old", "outcome": "red", "guidance": "g", "evidence": ["e"]}
    assert vc.checkable(old) == (True, [])
    assert vl._counts(old) and vl.not_checkable_reasons(old) == []
    assert vl._counts({**old, "outcome": "green"})
    assert not vl._counts({**old, "outcome": vl.NOT_EVALUATED})


# ── the ledger: recorded rows that fail their check never count ──────────────

def _vote(task, ac, outcome, evidence, location, reviewer):
    out = [vf.BEGIN, f"format: {vf.FORMAT}", f"task: {task}", f"reviewer: {reviewer}", "round: 1",
           f"vote: {outcome}", f"failed: [{'' if outcome == 'green' else ac}]", "",
           f"## AC{ac} criterion", f"Vote: {outcome}", f"Evidence: {evidence}",
           f"Location: {location}", "Rule: the criterion as written", "Conclusion: so."]
    if outcome != "green":
        out.append("Guidance: fix it")
    out += ["", "## Counter-search", "Searched: x", "Found: y", "", "## Change-my-mind", "z",
            vf.END, ""]
    return "\n".join(out)


def _patch_votes(monkeypatch, bad_dids):
    """FakeWorker writes its report from vf.example_vote: a dispatch in `bad_dids` (by number)
    votes citing a line that does not exist; any other votes the checkable placeholder."""
    n = {"i": 0}

    def fake(task, votes, *, reviewer="reviewer", **kw):
        n["i"] += 1
        (ac, outcome), = votes.items()
        if n["i"] in bad_dids:
            return _vote(task, ac, outcome, '"no such text"', "README.md:1", reviewer)
        return REAL_EXAMPLE(task, votes, reviewer=reviewer, **kw)
    monkeypatch.setattr(vf, "example_vote", fake)


def _crit(root):
    ctx = vl._task_ctx(root, TID)
    return ctx, next(c for c in vl.human_criteria(ctx.text) if c.index == 1)


def _rows(root):
    return [r for r in vl._read(vl.VERDICTS, root) if r.get("task") == TID]


def test_green_citing_a_missing_line_is_recorded_but_never_ticks(repo, monkeypatch):
    _mk_task(repo, TASTE)
    _produce(repo)
    _patch_votes(monkeypatch, {1})
    res = _judge(repo, dispatcher=FakeWorker("green"))
    rows = _rows(repo)
    assert len(rows) == 1 and rows[0]["outcome"] == "green"          # recorded as the seat said
    ok, why = vc.checkable(rows[0])
    assert not ok and any("not found" in w for w in why)
    r = res["dispatches"][0]["results"][0]
    assert r["outcome"] == vl.NOT_CHECKABLE and r["vote"] == "green" and r["not_checkable"]
    assert res["outcomes"][1] == vl.NOT_EVALUATED                    # not green, not red
    ctx, crit = _crit(repo)
    good, why_s = vl.satisfying_verdict(ctx, crit)
    assert good is None and why_s.startswith(vl.NOT_CHECKABLE), why_s
    applied = vl.apply(TID, repo)
    assert applied["ticked"] == [] and applied["not_applied"][0]["why"].startswith(vl.NOT_CHECKABLE)
    code, lines = vl.audit(repo)
    assert code <= vl.AUDIT_WARN, lines
    assert any(ln.startswith(f"WARN {vl.NOT_CHECKABLE}:") and rows[0]["id"] in ln for ln in lines)


def test_a_fully_checked_vote_counts(repo, monkeypatch):
    _mk_task(repo, TASTE)
    _produce(repo)
    _patch_votes(monkeypatch, set())
    res = _judge(repo, dispatcher=FakeWorker("green"))
    assert res["outcomes"] == {1: "green"}
    assert vc.checkable(_rows(repo)[0]) == (True, [])
    assert [t["ac"] for t in vl.apply(TID, repo)["ticked"]] == [1]


def test_a_not_checkable_red_does_not_withdraw_an_earlier_green(repo, monkeypatch):
    """Neither green nor red: a later unchecked red is passed over like a not-evaluated row."""
    _mk_task(repo, TASTE)
    _produce(repo)
    _patch_votes(monkeypatch, {2})
    w = FakeWorker(["green", "red"])
    _judge(repo, dispatcher=w)                 # dispatch 1: a checked green
    _judge(repo, dispatcher=w)                 # dispatch 2: a red citing a line that does not exist
    rows = _rows(repo)
    assert [r["outcome"] for r in rows] == ["green", "red"] and not vc.checkable(rows[-1])[0]
    ctx, crit = _crit(repo)
    good, why = vl.satisfying_verdict(ctx, crit)
    assert good is not None and good["id"] == rows[0]["id"], why
    assert [t["ac"] for t in vl.apply(TID, repo)["ticked"]] == [1]


# ── reassignment: like not-evaluated, then the operator ─────────────────────

def _nc_result(kind, reasons):
    return {"kind": kind, "dispatch_id": f"d-{kind}", "results": [
        {"ac": 1, "outcome": vl.NOT_CHECKABLE, "vote": "red", "not_checkable": reasons,
         "source": "ledger", "why": f"{vl.NOT_CHECKABLE}: {'; '.join(reasons)}"}]}


def test_t5262_unchecked_red_is_reassigned_to_another_kind(monkeypatch):
    calls = []

    def judge(task_id, root, **kw):
        calls.append(kw)
        if "exclude_kinds" not in kw:
            return {"outcomes": {1: vl.NOT_EVALUATED},
                    "why": {1: f"{vl.NOT_CHECKABLE}: AC1: seat did not open image 02-page.png"},
                    "dispatches": [_nc_result("codex", ["AC1: seat did not open image 02-page.png"])]}
        return {"outcomes": {1: vl.GREEN}, "why": {}, "run_id": "R-2",
                "dispatches": [{"kind": "claude", "dispatch_id": "d-cl", "results": [
                    {"ac": 1, "outcome": "green", "source": "ledger"}]}]}
    monkeypatch.setattr(judge_cli, "judge", judge)
    res = judge_cli.judge_with_reassign(TID, Path("."))
    assert calls[1]["exclude_kinds"] == {"codex"} and calls[1]["criterion_n"] == 1
    assert res["outcomes"][1] == vl.GREEN
    assert res["reassigned"][0]["excluded"] == ["codex"]


def test_all_seats_not_checkable_goes_to_the_operator_with_the_reasons(monkeypatch):
    order = ["codex", "claude", "opencode"]

    def judge(task_id, root, **kw):
        ex = kw.get("exclude_kinds") or set()
        left = [k for k in order if k not in ex]
        if not left:
            return {"error": "no seat kind left", "outcomes": {}, "dispatches": []}
        k = left[0]
        return {"outcomes": {1: vl.NOT_EVALUATED}, "run_id": f"R-{k}",
                "why": {1: f"{vl.NOT_CHECKABLE}: AC1: quote 'x' not found in a.css"},
                "dispatches": [_nc_result(k, [f"AC1: quote {k!r} not found in a.css"])]}
    monkeypatch.setattr(judge_cli, "judge", judge)
    res = judge_cli.judge_with_reassign(TID, Path("."))
    why = res["why"][1]
    assert why.startswith("OPERATOR:"), why
    assert vl.NOT_CHECKABLE in why and all(f"quote {k!r} not found" in why for k in order), why
    assert res["outcomes"][1] in (vl.NOT_EVALUATED, judge_cli.UNKNOWN)


def test_printed_summary_names_not_checkable_votes_and_reasons(capsys):
    res = {"task_id": TID, "criteria": [1], "operator_only": [], "rung": 1, "rung_reason": "low",
           "dry_run": False, "outcomes": {1: vl.NOT_EVALUATED}, "why": {},
           "dispatches": [_nc_result("codex", ["AC1: seat did not open image 02-page.png"])],
           "reassigned": [{"ac": 1, "excluded": ["codex"], "outcome": "not-evaluated", "why": "",
                           "unavailable": {},
                           "not_checkable": {"claude": "AC1: quote 'x' not found in a.css"}}]}
    judge_cli._print_result(res)
    out = capsys.readouterr().out
    assert "not-checkable (AC1: seat did not open image 02-page.png), voted red" in out
    assert "[not-checkable claude: AC1: quote 'x' not found in a.css]" in out


# ── a panel: an unchecked seat neither blocks nor counts (the T-5262 case) ──

def test_t5262_panel_unchecked_red_from_a_seat_that_never_opened_the_image(repo, monkeypatch):
    """Rung-5 panel. The codex seat votes red on a region of a screenshot that is really there,
    but its run record shows it never opened the image. Its red is recorded, does not stop the
    panel and does not count: the two checked greens of distinct vendors close the criterion."""
    from t3580_judge_cli_test import _all_kinds
    _all_kinds(monkeypatch, repo)
    _mk_task(repo, TASTE, extra_fm="cost_estimate:\n  blast_radius: 9\n")
    _produce(repo)
    shot = repo / SHOT
    shot.parent.mkdir(parents=True, exist_ok=True)
    Image.new("RGB", (1280, 200), "white").save(shot)
    n = {"i": 0}

    def fake(task, votes, *, reviewer="reviewer", **kw):
        n["i"] += 1
        (ac, outcome), = votes.items()
        if n["i"] == 2:                                           # the codex seat
            return _vote(task, ac, outcome, f"image: {SHOT} region 895,45,65,25",
                         f"{SHOT} region 895,45,65,25", reviewer)
        return REAL_EXAMPLE(task, votes, reviewer=reviewer, **kw)
    monkeypatch.setattr(vf, "example_vote", fake)
    w = FakeWorker(["green", "red", "green"])
    res = _judge(repo, dispatcher=w)
    assert [c["vendor"] for c in w.calls] == ["claude", "codex", "opencode"]   # not stopped
    codex = next(r for r in _rows(repo) if r["dispatch_id"] == w.calls[1]["did"])
    assert codex["outcome"] == "red"                                         # recorded as voted
    ok, why = vc.checkable(codex)
    assert not ok and any("did not open image" in x for x in why), why
    item = codex["check"]["criteria"]["1"]["items"][0]
    assert item["region_inside"] is True and item["seat_viewed"] is False
    cx = next(d for d in res["dispatches"] if d.get("kind") == "codex")["results"][0]
    assert cx["outcome"] == vl.NOT_CHECKABLE and cx["vote"] == "red"
    assert res["outcomes"] == {1: "green"}, res.get("why")
    assert [t["ac"] for t in vl.apply(TID, repo)["ticked"]] == [1]
