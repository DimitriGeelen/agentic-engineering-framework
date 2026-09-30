"""T-3579 — independent reviewer verdicts (T-3557 slice 2). One test per rule in the task."""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import verdict_ledger as vl  # noqa: E402
from lib.delegation import frontmatter, human_criteria  # noqa: E402

TASK = "T-9100"
TASTE = ("- [ ] [REVIEW] The summary paragraph reads clearly\n"
         "  **Steps:**\n  1. Read it\n  **Expected:** reads as a peer briefing\n  **If not:** note it\n")
TIER0 = ("- [ ] [REVIEW] Approve the force push via `fw tier0 approve`\n"
         "  **Steps:**\n  1. Run it\n  **Expected:** approved\n  **If not:** ask\n")
WORLD = ("- [ ] [REVIEW] Publish the release to the public mirror and confirm consumers pick it up\n"
         "  **Steps:**\n  1. Publish\n  **Expected:** consumers upgrade\n  **If not:** roll back\n")


def _git(root, *a, env=None):
    subprocess.run(["git", "-c", "core.hooksPath=/dev/null", *a], cwd=root, check=True,
                   capture_output=True, env={**os.environ, **(env or {})})


def _task(root, criteria, owner="human", workflow="build"):
    d = root / ".tasks" / "active"
    d.mkdir(parents=True, exist_ok=True)
    f = d / f"{TASK}-fixture.md"
    f.write_text(
        f"---\nid: {TASK}\nname: \"fixture\"\nstatus: started-work\nworkflow_type: {workflow}\n"
        f"owner: {owner}\nhorizon: now\ncreated: 2026-09-30T00:00:00Z\nlast_update: 2026-09-30T00:00:00Z\n"
        f"---\n\n## Acceptance Criteria\n\n### Agent\n- [x] built\n\n### Human\n{criteria}\n"
        f"## Verification\n\n## Updates\n")
    return f


@pytest.fixture()
def root(tmp_path, monkeypatch):
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    monkeypatch.setenv("FRAMEWORK_ROOT", str(ROOT))
    _git(tmp_path, "init", "-q")
    (tmp_path / "evidence.md").write_text("screenshot notes\n")
    return tmp_path


def _produce(root, author="Builder Bot", trailer=""):
    _git(root, "add", "-A")
    msg = f"{TASK}: build the thing" + (f"\n\nCo-Authored-By: {trailer}" if trailer else "")
    _git(root, "commit", "-q", "-m", msg,
         env={"GIT_AUTHOR_NAME": author, "GIT_AUTHOR_EMAIL": "b@x.y",
              "GIT_COMMITTER_NAME": author, "GIT_COMMITTER_EMAIL": "b@x.y"})


def _rec(root, outcome="green", ac=1, reviewer="openai/gpt-5", **kw):
    kw.setdefault("rung", "cross-vendor")
    kw.setdefault("evidence", ["evidence.md"] if outcome == "green" else [])
    if outcome != "green":
        kw.setdefault("guidance", "tighten the second sentence")
    return vl.record(TASK, ac, outcome, reviewer=reviewer, root=root, **kw)


def _lines(root, rel):
    p = root / rel
    return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []


def _humans(f):
    return human_criteria(f.read_text())


# ── AC 1: format, ledger, digest ─────────────────────────────────────────────

def test_record_shape_and_ledger(root):
    _task(root, TASTE)
    rec = _rec(root)
    row = _lines(root, vl.VERDICTS)[0]
    for k in ("id", "ts", "task", "ac", "ac_digest", "outcome", "verdict", "guidance",
              "reviewer", "rung", "evidence"):
        assert k in row, k
    assert row["task"] == TASK and row["outcome"] == "green" and row["verdict"] == "green"
    assert row["judgement"]["contract"] == "judge_verdict/1"
    assert rec["id"] == row["id"]


def test_digest_is_the_t1985_digest():
    from lib.reviewer.static_scan import _compute_ac_text_digest
    t = "[REVIEW] The summary paragraph reads clearly"
    assert vl.criterion_digest(t) == _compute_ac_text_digest(t)


def test_nongreen_requires_guidance(root):
    _task(root, TASTE)
    with pytest.raises(vl.VerdictRefused, match="guidance"):
        vl.record(TASK, 1, "amber", reviewer="openai/gpt-5", rung="r", root=root)
    assert not (root / vl.VERDICTS).exists()


# ── AC 2: green ticks, ownership moves, logged ───────────────────────────────

def test_green_ticks_cites_and_hands_ownership_to_agent(root):
    f = _task(root, TASTE)
    rec = _rec(root)
    res = vl.apply(TASK, root)
    assert [t["verdict_id"] for t in res["ticked"]] == [rec["id"]]
    text = f.read_text()
    assert frontmatter(text)["owner"] == "agent"
    assert _humans(f)[0].ticked
    assert f"Reviewer verdict:** green {rec['id']}" in text
    log = _lines(root, vl.APPLIED)[-1]
    assert log["kind"] == "verdict-apply" and log["owner_after"] == "agent"


def test_apply_is_idempotent(root):
    f = _task(root, TASTE)
    _rec(root)
    vl.apply(TASK, root)
    once = f.read_text()
    assert vl.apply(TASK, root)["ticked"] == []
    assert f.read_text() == once


def test_owner_stays_human_while_another_criterion_is_open(root):
    f = _task(root, TASTE + TIER0)
    _rec(root, ac=1)
    res = vl.apply(TASK, root)
    assert len(res["ticked"]) == 1
    assert frontmatter(f.read_text())["owner"] == "human"
    assert [c.ticked for c in _humans(f)] == [True, False]


# ── AC 4: amber / red / escalate keep it open + refusal ledger ───────────────

@pytest.mark.parametrize("outcome", ["amber", "red", "escalate"])
def test_nongreen_keeps_open_and_lands_on_refusal_ledger(root, outcome):
    f = _task(root, TASTE)
    rec = _rec(root, outcome)
    res = vl.apply(TASK, root)
    assert res["ticked"] == []
    assert not _humans(f)[0].ticked
    rows = _lines(root, vl.REFUSALS)
    assert rows[-1]["class"] == f"verdict-{outcome}"
    assert rows[-1]["verdict_id"] == rec["id"] and rows[-1]["gate"] == "reviewer-verdict"
    assert rows[-1]["reason"] == "tighten the second sentence"


def test_escalate_reroutes_to_operator_with_reason_visible(root):
    f = _task(root, TASTE, owner="agent")
    _rec(root, "escalate", guidance="needs the operator's eye on the mobile layout")
    text = f.read_text()
    assert frontmatter(text)["owner"] == "human"
    assert "Reviewer escalation" in text and "mobile layout" in text
    assert _lines(root, vl.VERDICTS)[-1]["verdict"] == "unknown"   # contract state, not a 5th colour


def test_later_red_withdraws_earlier_green(root):
    f = _task(root, TASTE)
    _rec(root)
    _rec(root, "red", guidance="broken on narrow screens")
    assert vl.apply(TASK, root)["ticked"] == []
    assert not _humans(f)[0].ticked


# ── AC 5: only REVIEWER-JUDGES ───────────────────────────────────────────────

@pytest.mark.parametrize("crit", [TIER0, WORLD])
@pytest.mark.parametrize("outcome", ["green", "escalate"])
def test_operator_only_criteria_refuse_any_verdict(root, crit, outcome):
    f = _task(root, crit)
    before = f.read_text()
    with pytest.raises(vl.VerdictRefused, match="only the operator"):
        _rec(root, outcome)
    assert not (root / vl.VERDICTS).exists()
    assert _lines(root, vl.REFUSALS)[-1]["class"] == "not-reviewer-judged"
    assert f.read_text() == before


def test_forged_green_for_operator_only_criterion_never_applies(root):
    """A row written straight into the ledger (bypassing record) is still not honoured."""
    f = _task(root, TIER0)
    c = _humans(f)[0]
    vl._append(vl.VERDICTS, {"id": "V-forged", "task": TASK, "ac": 1,
                             "ac_digest": vl.criterion_digest(c.title), "outcome": "green",
                             "reviewer": "openai/gpt-5", "rung": "x", "evidence": ["evidence.md"]}, root)
    assert vl.apply(TASK, root)["ticked"] == []
    assert not _humans(f)[0].ticked


# ── AC 6: reviewer is never the producer ─────────────────────────────────────

@pytest.mark.parametrize("reviewer", ["Builder Bot", "builder-bot", "vendor/Builder Bot",
                                      "Claude Sonnet 5.5", "claude-sonnet-5-5", "b@x.y"])
def test_reviewer_equal_to_producer_is_refused(root, reviewer):
    _task(root, TASTE)
    _produce(root, trailer="Claude Sonnet 5.5 <noreply@anthropic.com>")
    with pytest.raises(vl.VerdictRefused, match="never the producer"):
        _rec(root, reviewer=reviewer)
    assert _lines(root, vl.REFUSALS)[-1]["class"] == "reviewer-is-producer"
    assert not (root / vl.VERDICTS).exists()


def test_independent_reviewer_passes_when_producer_exists(root):
    _task(root, TASTE)
    _produce(root)
    assert _rec(root, reviewer="openai/gpt-5")["outcome"] == "green"


def test_reviewer_who_later_becomes_producer_stops_counting(root):
    f = _task(root, TASTE)
    _rec(root, reviewer="openai/gpt-5")
    (root / "more.txt").write_text("x")
    _produce(root, author="GPT-5")
    assert vl.apply(TASK, root)["ticked"] == []
    assert not _humans(f)[0].ticked


def test_producer_frontmatter_field_counts(root):
    f = _task(root, TASTE)
    f.write_text(f.read_text().replace("horizon: now", "horizon: now\nproducer: Session-42"))
    with pytest.raises(vl.VerdictRefused, match="never the producer"):
        _rec(root, reviewer="session-42")


# ── AC 7: digest ─────────────────────────────────────────────────────────────

def test_edited_criterion_voids_the_verdict(root):
    f = _task(root, TASTE)
    _rec(root)
    f.write_text(f.read_text().replace("reads clearly", "reads very clearly"))
    assert vl.apply(TASK, root)["ticked"] == []
    assert not _humans(f)[0].ticked


def test_reviewer_asserting_a_stale_digest_is_refused(root):
    _task(root, TASTE)
    with pytest.raises(vl.VerdictRefused, match="changed after"):
        _rec(root, digest="000000000000")


def test_green_needs_existing_evidence(root):
    _task(root, TASTE)
    with pytest.raises(vl.VerdictRefused, match="evidence"):
        _rec(root, evidence=["nope/missing.png"])


def test_inception_is_not_ticked_by_apply(root):
    f = _task(root, TASTE, workflow="inception")
    _rec(root)
    res = vl.apply(TASK, root)
    assert res["ticked"] == [] and "inception" in res["skipped"]
    assert not _humans(f)[0].ticked
