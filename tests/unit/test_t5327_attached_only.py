"""T-5327 (risk R-040, T-5309 matrix risk 3): attached-at-launch is not proof a seat looked.

The review runtime attaches every cited screenshot to a codex seat at launch (T-5309), and the
checker counts such an image as viewed. That shows the image was in the prompt, not that the model
examined it. In a run that is NOT a rung-5 panel, a vote on a render criterion whose every cited
image is proven only by "attached" is therefore not checkable; the judge's existing not-checkable
path (T-5294) then reassigns the criterion to another seat kind. A seat whose own log shows a view
(claude Read, antigravity read_file, codex's image tool) counts in both modes; a rung-5 panel and a
non-render criterion are unchanged.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import review_seat_evidence as rse  # noqa: E402
from lib import verdict_format as vf  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib import vote_checker as vc  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
from test_t5309_seat_image_proof import (  # noqa: E402
    SHOT, TASK, _codex_commands_only, evidence)  # noqa: F401  (fixture)


# ── fixtures: a real verdict/1 vote checked against a real seat record ──────────────────────

def _rev(proj: Path) -> str:
    subprocess.run(["git", "init", "-q"], cwd=proj, check=True)
    subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q",
                    "--allow-empty", "-m", "base"], cwd=proj, check=True)
    return subprocess.run(["git", "rev-parse", "HEAD"], cwd=proj, check=True, capture_output=True,
                          text=True).stdout.strip()


def _vote() -> dict:
    lines = [vf.BEGIN, "format: verdict/1", f"task: {TASK}", "reviewer: seat", "round: 1",
             "vote: green", "failed: []", "", "## AC2 Settings icon visible on the page",
             "Vote: green", f"Evidence: image: {SHOT} region 0,0,10,10",
             f"Location: {SHOT} region 0,0,10,10", 'Rule: criterion: "icon visible"',
             "Conclusion: it holds.", "", "## Counter-search", "Searched: x", "Found: y", "",
             "## Change-my-mind", "z", vf.END]
    parsed, problems = vf.parse_vote("\n".join(lines), task=TASK, expected_acs=[2])
    assert problems == {}
    return vf.accepted(parsed, problems)[2]


def _codex_attached_seat(proj, brief, tree) -> Path:
    wdir = tree.parent / "judge-t-9309-r3-codex-000000000001"
    wdir.mkdir()
    _codex_commands_only(wdir, ["ls"])
    rse.write_manifest(wdir / rse.MANIFEST_NAME,
                       rse.image_manifest(rse.copy_cited(brief, proj, tree), tree))
    return wdir


def _claude_logged_seat(tmp: Path, path: str) -> Path:
    d = tmp / "judge-t-9309-r3-claude-000000000002"
    d.mkdir()
    ev = [{"type": "system", "subtype": "init"},
          {"type": "assistant", "message": {"content": [
              {"type": "tool_use", "name": "Read", "input": {"file_path": path}}]}},
          {"type": "result", "result": "done"}]
    (d / "result.jsonl").write_text("\n".join(json.dumps(e) for e in ev) + "\n")
    return d


def _row(check: dict, rung: str) -> dict:
    return {"id": "V-x", "format": vf.FORMAT, "outcome": "green", "check": check, "rung": rung}


SINGLE = "rung-3-termlink-single-reviewer"
PANEL = "rung-5-panel"


@pytest.fixture
def codex_check(evidence):
    proj, brief, tree, *_ = evidence
    wdir = _codex_attached_seat(proj, brief, tree)
    return vc.check_vote(_vote(), proj, _rev(proj), wdir, write_crops=False)


@pytest.fixture
def claude_check(evidence, tmp_path):
    proj, brief, tree, *_ = evidence
    d = _claude_logged_seat(tmp_path, str(proj / SHOT))
    return vc.check_vote(_vote(), proj, _rev(proj), d, write_crops=False)


# ── the proof kind is kept in the check ─────────────────────────────────────────────────────

def test_view_proof_is_recorded(codex_check, claude_check):
    assert codex_check["criteria"]["2"]["items"][0]["view_proof"] == "attached"
    assert claude_check["criteria"]["2"]["items"][0]["view_proof"] == "logged"


def test_attached_and_also_logged_is_logged(evidence):
    proj, brief, tree, *_ = evidence
    wdir = _codex_attached_seat(proj, brief, tree)
    ev = [{"type": "item.completed", "item": {"type": "view_image", "path": SHOT}}]
    with (wdir / "result.jsonl").open("a") as fh:
        fh.write("\n".join(json.dumps(e) for e in ev) + "\n")
    chk = vc.check_vote(_vote(), proj, _rev(proj), wdir, write_crops=False)
    assert chk["criteria"]["2"]["items"][0]["view_proof"] == "logged"
    assert vc.checkable(_row(chk, SINGLE), render=True) == (True, [])


# ── the rule ────────────────────────────────────────────────────────────────────────────────

def test_single_seat_codex_render_vote_attached_only_is_not_checkable(codex_check):
    ok, why = vc.checkable(_row(codex_check, SINGLE), render=True)
    assert not ok
    assert why == [f"AC2: {vc.ATTACHED_ONLY}"]
    assert "attached-only proof: a render vote in a single-seat run needs a seat that logged a view (T-5327)" in why[0]


def test_same_vote_in_a_rung5_panel_is_checkable(codex_check):
    assert vc.checkable(_row(codex_check, PANEL), render=True) == (True, [])


def test_claude_logged_view_is_checkable_in_single_seat_and_panel(claude_check):
    assert vc.checkable(_row(claude_check, SINGLE), render=True) == (True, [])
    assert vc.checkable(_row(claude_check, PANEL), render=True) == (True, [])


def test_non_render_criterion_is_unaffected(codex_check):
    assert vc.checkable(_row(codex_check, SINGLE), render=False) == (True, [])
    assert vc.checkable(_row(codex_check, SINGLE)) == (True, [])


def test_pre_t5327_check_without_view_proof_reads_attached_from_seat_viewed_how():
    att = {"kind": "image", "seat_viewed": True, "seat_viewed_how": "attached at launch (T-5309)"}
    log = {"kind": "image", "seat_viewed": True}
    assert vc.view_proof(att) == "attached" and vc.view_proof(log) == "logged"
    assert vc.view_proof({"kind": "image", "seat_viewed": None}) is None


# ── the ledger applies it where it knows the criterion ──────────────────────────────────────

def test_ledger_reasons_apply_the_render_rule_from_the_criterion(codex_check, monkeypatch):
    row = _row(codex_check, SINGLE)
    monkeypatch.setattr(vl, "_is_render_review", lambda ctx, crit: True)
    assert vl.not_checkable_reasons(row, object(), object()) == [f"AC2: {vc.ATTACHED_ONLY}"]
    assert not vl._counts(row, object(), object())
    monkeypatch.setattr(vl, "_is_render_review", lambda ctx, crit: False)
    assert vl.not_checkable_reasons(row, object(), object()) == []
    assert vl._counts(row, object(), object())


# ── the judge reassigns to another kind ─────────────────────────────────────────────────────

def test_attached_only_codex_render_vote_is_reassigned_to_another_kind(monkeypatch):
    calls = []
    reason = f"AC1: {vc.ATTACHED_ONLY}"

    def judge(task_id, root, **kw):
        calls.append(kw)
        if "exclude_kinds" not in kw:
            return {"outcomes": {1: vl.NOT_EVALUATED},
                    "why": {1: f"{vl.NOT_CHECKABLE}: {reason}"},
                    "dispatches": [{"kind": "codex", "dispatch_id": "d-cx", "results": [
                        {"ac": 1, "outcome": vl.NOT_CHECKABLE, "vote": "green",
                         "not_checkable": [reason], "source": "ledger"}]}]}
        return {"outcomes": {1: vl.GREEN}, "why": {}, "run_id": "R-2",
                "dispatches": [{"kind": "claude", "dispatch_id": "d-cl", "results": [
                    {"ac": 1, "outcome": "green", "source": "ledger"}]}]}
    monkeypatch.setattr(judge_cli, "judge", judge)
    res = judge_cli.judge_with_reassign(TASK, Path("."))
    assert calls[1]["exclude_kinds"] == {"codex"} and calls[1]["criterion_n"] == 1
    assert res["reassigned"][0]["excluded"] == ["codex"]
    assert res["outcomes"][1] == vl.GREEN
