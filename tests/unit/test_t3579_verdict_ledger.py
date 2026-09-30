"""T-3579 — independent reviewer verdicts (T-3557 slice 2). One test per rule in the task."""
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from lib import review_policy  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.delegation import frontmatter, human_criteria  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
import _review_runtime as rt  # noqa: E402

TASK = "T-9100"
TASTE = ("- [ ] [REVIEW] The summary paragraph reads clearly\n"
         "  **Steps:**\n  1. Read it\n  **Expected:** reads as a peer briefing\n  **If not:** note it\n")
TIER0 = ("- [ ] [REVIEW] Approve the force push via `fw tier0 approve`\n"
         "  **Steps:**\n  1. Run it\n  **Expected:** approved\n  **If not:** ask\n")
RENDERED = ("- [ ] [REVIEW] The review page layout reads clearly when rendered\n"
            "  **Steps:**\n  1. Open the page\n  **Expected:** the layout is tidy\n  **If not:** note it\n")
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


def _dispatch(root, did="rv-1", task=TASK, task_type="review"):
    """Register a dispatch exactly as the dispatcher does (T-3581): with the runtime's worker
    directory and the revision under review (T-3580 round 3)."""
    return rt.dispatch(root, did, task, task_type=task_type)


def _dg(root, ac=1):
    f = next((root / ".tasks" / "active").glob(f"{TASK}-*.md"))
    return vl.criterion_digest(next(c for c in human_criteria(f.read_text()) if c.index == ac))


def _has_commit(root):
    return subprocess.run(["git", "rev-parse", "-q", "--verify", "HEAD"], cwd=root,
                          capture_output=True).returncode == 0


@pytest.fixture(autouse=True)
def _worker_attributed_reviewer(monkeypatch):
    """T-3580 round 2: a reviewer identity must be attributed to the worker session of its
    dispatch. The tests keep their model labels; the label is prefixed with the worker."""
    real = vl.record

    def rec(task_id, ac, outcome, *, reviewer, dispatch_id="", **kw):
        w = vl.worker_identity(dispatch_id) if dispatch_id else ""
        if w and vl._norm(w) not in vl._norm(reviewer):
            reviewer = f"{w}:{reviewer}"
        return real(task_id, ac, outcome, reviewer=reviewer, dispatch_id=dispatch_id, **kw)
    monkeypatch.setattr(vl, "record", rec)


def _last_worker(root):
    rows = _lines(root, vl.VERDICTS)
    return rows[-1]["worker"] if rows else "Reviewer Worker"


def _commit_ledger(root, author=None):
    """Commit .context/reviews as the reviewer worker (its own identity, not the producer's)."""
    author = author or _last_worker(root)
    _git(root, "add", ".context/reviews")
    _git(root, "commit", "-q", "-m", f"{TASK}: reviewer verdict",
         env={"GIT_AUTHOR_NAME": author, "GIT_AUTHOR_EMAIL": "reviewer@x.y",
              "GIT_COMMITTER_NAME": author, "GIT_COMMITTER_EMAIL": "reviewer@x.y"})


def _rec(root, outcome="green", ac=1, reviewer="openai/gpt-5", commit=True, render=False,
         finish=True, **kw):
    """A verdict as the shipped path produces it: producer commit exists, the reviewer
    submits the digest it read, names a registered review dispatch, and commits the row; then
    it exits and the dispatch runtime signs its completion (`finish=False`: it never does)."""
    if not _has_commit(root):
        _produce(root)
    kw.setdefault("evidence", ["evidence.md"] if outcome == "green" else [])
    if "dispatch_id" not in kw:
        did = f"rv-{len(_lines(root, vl.DISPATCHES)) + 1}"
        # T-3580 round 6: as `judge` does — a criterion IW-7 scores above rung 1 (or a render
        # criterion) is reviewed inside a signed run at the required rung, bound at registration.
        f = next((root / ".tasks" / "active").glob(f"{TASK}-*.md"))
        crit = next(c for c in human_criteria(f.read_text()) if c.index == ac)
        ctx = vl._Ctx(root, TASK, f, f.read_text())
        need, _why = vl.required_strength(ctx, crit)
        if (render and outcome == "green") or need > 1:
            kw.update(_render_run(root, ac, did, kw["evidence"], render=render and outcome == "green",
                                  rung=review_policy.rung_label(need)))
            kw["rung"] = review_policy.rung_label(need)
            rt.dispatch(root, did, TASK, run_id=kw["run_id"], seat="claude")
            kw["dispatch_id"] = did
        else:
            kw["dispatch_id"] = _dispatch(root, did)
    if "digest" not in kw:
        f = next((root / ".tasks" / "active").glob(f"{TASK}-*.md"))
        kw["digest"] = vl.criterion_digest(
            next(c for c in human_criteria(f.read_text()) if c.index == ac))
    kw.setdefault("rung", "cross-vendor")
    if outcome != "green":
        kw.setdefault("guidance", "tighten the second sentence")
    rec = vl.record(TASK, ac, outcome, reviewer=reviewer, root=root, **kw)
    if commit:
        _commit_ledger(root)
    if finish:
        rt.finish(root, kw["dispatch_id"])
    return rec


def _render_run(root, ac, did, evidence, pages=("/review",), ok=True, render=True,
                rung="rung-1-same-vendor-independent"):
    """The judge's side of a render review: a signed run naming the required pages with the
    capture result of each. Returns the extra kwargs `record` needs to cite the screenshots.
    `render=False`: a plain run at `rung` with no pages (round 6)."""
    shots, caps = [], []
    for i, pg in enumerate(pages if render else ()):
        f = root / f"shot-{did}-{i}.png"
        f.write_bytes(b"png-" + pg.encode())
        shots.append(f.name)
        caps.append({"page": pg, "ok": ok, "sha256": vl._hash_path(f) if ok else "",
                     "error": "" if ok else "browser down"})
    vl.register_run(f"run-{did}", TASK, acs=[ac], rung=rung,
                    seats=[{"seat": "claude", "vendor": "claude"}], required_vendors=1,
                    pages={str(ac): list(pages)} if render else {}, captures=caps, root=root)
    return {"run_id": f"run-{did}", "evidence": list(evidence) + shots}


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


def test_title_digest_is_the_t1985_digest():
    from lib.reviewer.static_scan import _compute_ac_text_digest
    t = "[REVIEW] The summary paragraph reads clearly"
    assert vl.title_digest(t) == _compute_ac_text_digest(t)


def test_nongreen_requires_guidance(root):
    _task(root, TASTE)
    with pytest.raises(vl.VerdictRefused, match="guidance"):
        _produce(root)
        vl.record(TASK, 1, "amber", reviewer="openai/gpt-5", rung="r", root=root,
                  dispatch_id=_dispatch(root), digest=_dg(root))
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
                             "ac_digest": vl.criterion_digest(c), "outcome": "green",
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


# ── T-3581 containment: only a verdict naming a registered review dispatch counts ──

def _forge(root, outcome="green", **over):
    """Append a ledger row BY HAND — no record(), no dispatch — the Z.ai sandbox attack."""
    _task_file = next((root / ".tasks" / "active").glob(f"{TASK}-*.md"))
    crit = human_criteria(_task_file.read_text())[0]
    row = {"id": "V-FORGED", "ts": "2026-09-30T00:00:00Z", "task": TASK, "ac": 1,
           "ac_digest": vl.criterion_digest(crit), "outcome": outcome, "verdict": outcome,
           "reviewer": "independent-reviewer-session-7", "rung": "cross-vendor",
           "evidence": ["evidence.md"]}
    row.update(over)
    p = root / vl.VERDICTS
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("a") as fh:
        fh.write(json.dumps(row) + "\n")


def test_hand_appended_green_row_is_refused(root):
    f = _task(root, TASTE)
    _produce(root)
    _forge(root)
    assert vl.render_verdicts(TASK, root) == []
    res = vl.apply(TASK, root)
    assert res["ticked"] == []
    assert "[ ]" in f.read_text() and "owner: human" in f.read_text()


def test_control_the_same_row_with_a_registered_review_dispatch_is_honoured(root):
    """Negative control for the test above: the refusal is about provenance, not the row shape."""
    f = _task(root, TASTE)
    _produce(root)
    rec = _rec(root)
    assert vl.apply(TASK, root)["ticked"][0]["verdict_id"] == rec["id"]


@pytest.mark.parametrize("did", ["", "no-such-dispatch"])
def test_record_refuses_missing_or_unknown_dispatch(root, did):
    _task(root, TASTE)
    with pytest.raises(vl.VerdictRefused, match="dispatch"):
        vl.record(TASK, 1, "green", reviewer="openai/gpt-5", rung="r",
                  evidence=["evidence.md"], dispatch_id=did, root=root)
    assert not (root / vl.VERDICTS).exists()


def test_record_refuses_a_non_review_dispatch(root):
    _task(root, TASTE)
    did = _dispatch(root, "bld-1", task_type="build")
    with pytest.raises(vl.VerdictRefused, match="not a review|task-type"):
        vl.record(TASK, 1, "green", reviewer="openai/gpt-5", rung="r",
                  evidence=["evidence.md"], dispatch_id=did, root=root)


def test_record_refuses_a_dispatch_issued_for_another_task(root):
    _task(root, TASTE)
    did = _dispatch(root, "rv-other", task="T-9999")
    with pytest.raises(vl.VerdictRefused, match="issued for"):
        vl.record(TASK, 1, "green", reviewer="openai/gpt-5", rung="r",
                  evidence=["evidence.md"], dispatch_id=did, root=root)


def test_a_forged_registry_row_without_the_signature_does_not_verify(root):
    _task(root, TASTE)
    p = root / vl.DISPATCHES
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps({"dispatch_id": "fake", "task": TASK, "task_type": "review",
                             "issuer_session": "", "issuer_identity": "", "ts": "x",
                             "sig": "0" * 64}) + "\n")
    vl._dispatch_key(root, create=True)
    with pytest.raises(vl.VerdictRefused, match="signature"):
        vl.record(TASK, 1, "green", reviewer="openai/gpt-5", rung="r",
                  evidence=["evidence.md"], dispatch_id="fake", root=root)


def test_tampering_with_a_registry_row_after_signing_invalidates_it(root):
    _task(root, TASTE)
    did = _dispatch(root, "rv-t", task_type="build")
    p = root / vl.DISPATCHES
    p.write_text(p.read_text().replace('"task_type":"build"', '"task_type":"review"'))
    with pytest.raises(vl.VerdictRefused, match="signature"):
        vl.record(TASK, 1, "green", reviewer="openai/gpt-5", rung="r",
                  evidence=["evidence.md"], dispatch_id=did, root=root)


# ═══ T-3581: adversarial tests, one per finding in the two cross-vendor reviews ═══════
# Each refusal test is paired with a control that shows the same setup passing when the
# one property under test is right — a refusal that also fires on good input proves nothing.

def _text(root):
    return next((root / ".tasks" / "active").glob(f"{TASK}-*.md")).read_text()


def _ticked(root, ac=1):
    return next(c for c in human_criteria(_text(root)) if c.index == ac).ticked


def _owner(root):
    return frontmatter(_text(root))["owner"]


def _edit(root, old, new):
    f = next((root / ".tasks" / "active").glob(f"{TASK}-*.md"))
    f.write_text(f.read_text().replace(old, new))


def _refusals(root, cls):
    return [r for r in _lines(root, vl.REFUSALS) if r.get("class") == cls]


RENDER_TASK_FILES = ("web/templates/fixture.html",)


def _produce_render(root):
    (root / "web" / "templates").mkdir(parents=True)
    (root / "web" / "templates" / "fixture.html").write_text("<p>x</p>\n")
    _produce(root)


# ── OpenAI H1 / Z.ai H1: independence was a self-asserted string ─────────────────

def test_pseudonym_without_a_review_dispatch_is_refused(root):
    """Z.ai sandbox repro #1: producer 'Claude Sonnet 5.5' records as 'independent-reviewer-session-7'."""
    _task(root, TASTE)
    _produce(root, author="Claude Sonnet 5.5")
    with pytest.raises(vl.VerdictRefused, match="dispatch"):
        vl.record(TASK, 1, "green", reviewer="independent-reviewer-session-7", rung="x",
                  evidence=["evidence.md"], digest=_dg(root), dispatch_id="", root=root)
    assert not (root / vl.VERDICTS).exists()


def test_control_same_pseudonym_with_a_registered_review_dispatch_passes_the_identity_check(root):
    _task(root, TASTE)
    _produce(root, author="Claude Sonnet 5.5")
    _rec(root, reviewer="independent-reviewer-session-7")
    assert vl.apply(TASK, root)["ticked"]


def test_record_before_any_commit_is_refused(root):
    """Z.ai repro #3, EMPTY repository: the dispatch could bind no revision, so the specific
    refusal is the missing reviewed revision (the no-producer case is the next test)."""
    _task(root, TASTE)
    assert not _has_commit(root)
    with pytest.raises(vl.VerdictRefused, match="names no reviewed revision — the repository had no commit"):
        vl.record(TASK, 1, "green", reviewer="openai/gpt-5", rung="x", evidence=["evidence.md"],
                  digest=_dg(root), dispatch_id=_dispatch(root), root=root)


def test_commit_without_the_task_id_leaves_no_producer_so_greens_are_refused(root):
    """Z.ai repro #4: `--no-verify` commit that never names the task — producers() sees nothing."""
    _task(root, TASTE)
    _git(root, "add", "-A")
    _git(root, "commit", "-q", "-m", "wip: sneaky",
         env={"GIT_AUTHOR_NAME": "Claude Sonnet 5.5", "GIT_AUTHOR_EMAIL": "c@x.y",
              "GIT_COMMITTER_NAME": "Claude Sonnet 5.5", "GIT_COMMITTER_EMAIL": "c@x.y"})
    with pytest.raises(vl.VerdictRefused, match="no commit references"):
        vl.record(TASK, 1, "green", reviewer="claude-sonnet-5-5", rung="x", evidence=["evidence.md"],
                  digest=_dg(root), dispatch_id=_dispatch(root), root=root)


def test_git_failure_refuses_rather_than_passing(root, monkeypatch):
    _task(root, TASTE)
    _produce(root)
    did = _dispatch(root)
    real = subprocess.run

    def broken(cmd, *a, **k):
        if cmd and cmd[0] == "git" and "log" in cmd:
            return subprocess.CompletedProcess(cmd, 128, "", "fatal: not a git repository")
        return real(cmd, *a, **k)

    monkeypatch.setattr(vl.subprocess, "run", broken)
    with pytest.raises(vl.VerdictRefused, match="producer provenance unavailable"):
        vl.record(TASK, 1, "green", reviewer="openai/gpt-5", rung="x", evidence=["evidence.md"],
                  digest=_dg(root), dispatch_id=did, root=root)
    monkeypatch.setattr(vl.subprocess, "run", real)      # control: same call passes when git answers
    vl.record(TASK, 1, "green", reviewer="openai/gpt-5", rung="x", evidence=["evidence.md"],
              digest=_dg(root), dispatch_id=did, root=root)


def test_worker_identity_that_committed_for_the_task_is_not_a_reviewer(root):
    _task(root, TASTE)
    _produce(root, author="Builder Bot")
    _git(root, "commit", "-q", "--allow-empty", "-m", f"{TASK}: more work",
         env={"GIT_AUTHOR_NAME": "w", "GIT_AUTHOR_EMAIL": "dispatch+rv-77@aef.local",
              "GIT_COMMITTER_NAME": "w", "GIT_COMMITTER_EMAIL": "dispatch+rv-77@aef.local"})
    did = _dispatch(root, "rv-77")
    with pytest.raises(vl.VerdictRefused, match="never the producer"):
        vl.record(TASK, 1, "green", reviewer="someone-else", rung="x", evidence=["evidence.md"],
                  digest=_dg(root), dispatch_id=did, root=root)


# ── introducing-commit check (Z.ai fix 2) ────────────────────────────────────────

def test_uncommitted_row_does_not_count(root):
    f = _task(root, TASTE)
    _rec(root, commit=False)
    assert vl.apply(TASK, root)["ticked"] == []
    assert not _ticked(root)


def test_row_introduced_by_a_producer_commit_does_not_count(root):
    _task(root, TASTE)
    _rec(root, commit=False)
    _produce(root, author="Builder Bot")            # the producer sweeps the row into its commit
    assert vl.apply(TASK, root)["ticked"] == []


def test_control_row_introduced_by_a_non_producer_counts(root):
    _task(root, TASTE)
    _rec(root)
    assert vl.apply(TASK, root)["ticked"]


# ── OpenAI H2 / Z.ai H2: hand-appended rows and row-shape validation ─────────────

def test_hand_appended_row_with_a_full_judgement_block_but_no_dispatch_is_refused(root):
    _task(root, TASTE)
    _produce(root)
    _forge(root, judgement={"contract": "judge_verdict/1", "judge": "x", "state": "green"},
           dispatch_id="")
    assert vl.apply(TASK, root)["ticked"] == []


def test_hand_appended_row_naming_an_unregistered_dispatch_is_refused(root):
    _task(root, TASTE)
    _produce(root)
    _forge(root, dispatch_id="rv-made-up",
           judgement={"contract": "judge_verdict/1", "judge": "independent-reviewer-session-7",
                      "state": "green"})
    assert vl.apply(TASK, root)["ticked"] == []


def test_green_with_unknown_verdict_or_missing_judgement_is_not_a_green(root):
    _task(root, TASTE)
    _rec(root, commit=False)
    p = root / vl.VERDICTS
    row = json.loads(p.read_text())
    row["verdict"] = "unknown"
    p.write_text(json.dumps(row) + "\n")
    _commit_ledger(root)
    assert vl.apply(TASK, root)["ticked"] == []
    row.pop("judgement")
    row["verdict"] = "green"
    p.write_text(json.dumps(row) + "\n")
    _commit_ledger(root)
    assert vl.apply(TASK, root)["ticked"] == []


def test_empty_evidence_green_is_not_honoured(root):
    _task(root, TASTE)
    _rec(root, commit=False)
    p = root / vl.VERDICTS
    row = json.loads(p.read_text())
    row["evidence"] = []
    p.write_text(json.dumps(row) + "\n")
    _commit_ledger(root)
    assert vl.apply(TASK, root)["ticked"] == []


def test_evidence_deleted_after_record_withdraws_the_tick(root):
    _task(root, TASTE)
    _rec(root)
    assert vl.apply(TASK, root)["ticked"]
    (root / "evidence.md").unlink()
    res = vl.apply(TASK, root)
    assert [w["ac"] for w in res["withdrawn"]] == [1] and not _ticked(root)


@pytest.mark.parametrize("ev,match", [("/etc/passwd", "absolute"), ("../outside.md", "outside")])
def test_evidence_must_be_relative_and_inside_the_repo(root, ev, match):
    _task(root, TASTE)
    _produce(root)
    with pytest.raises(vl.VerdictRefused, match=match):
        _rec(root, evidence=[ev])


# ── OpenAI H3: ticks were permanent ──────────────────────────────────────────────

def test_a_valid_tick_survives_repeated_close_attempts(root):
    """Control for the withdrawal tests."""
    _task(root, TASTE)
    _rec(root)
    vl.apply(TASK, root)
    for _ in range(3):
        assert vl.apply(TASK, root)["withdrawn"] == []
    assert _ticked(root) and _owner(root) == "agent"


def test_later_red_after_apply_withdraws_the_tick_and_restores_ownership(root):
    _task(root, TASTE)
    _rec(root)
    vl.apply(TASK, root)
    assert _ticked(root) and _owner(root) == "agent"
    _rec(root, "red", reviewer="zai/glm-5", guidance="the summary contradicts itself")
    res = vl.apply(TASK, root)
    assert [w["ac"] for w in res["withdrawn"]] == [1]
    assert not _ticked(root) and _owner(root) == "human"
    assert "Reviewer verdict:" not in _text(root)


def test_criterion_edit_after_apply_withdraws_the_tick(root):
    _task(root, TASTE)
    _rec(root)
    vl.apply(TASK, root)
    _edit(root, "reads as a peer briefing", "reads as a legal contract")
    assert [w["ac"] for w in vl.apply(TASK, root)["withdrawn"]] == [1]
    assert not _ticked(root) and _owner(root) == "human"


def test_reviewer_becoming_a_producer_after_apply_withdraws_the_tick(root):
    _task(root, TASTE)
    _rec(root, reviewer="Reviewer Worker")
    _git(root, "commit", "-q", "--allow-empty", "-m", f"{TASK}: reviewer now writes code",
         env={"GIT_AUTHOR_NAME": "Reviewer Worker", "GIT_AUTHOR_EMAIL": "r@x.y",
              "GIT_COMMITTER_NAME": "Reviewer Worker", "GIT_COMMITTER_EMAIL": "r@x.y"})
    assert vl.apply(TASK, root)["ticked"] == [] and not _ticked(root)


def test_a_fabricated_tick_annotation_with_no_ledger_row_is_withdrawn(root):
    _task(root, TASTE)
    _produce(root)
    _edit(root, "- [ ] [REVIEW] The summary", "- [x] [REVIEW] The summary")
    _edit(root, "  **Steps:**", "  **Reviewer verdict:** green V-FAKE — me (rung x), digest 0; evidence: e; ledger l\n  **Steps:**")
    res = vl.apply(TASK, root)
    assert [w["ac"] for w in res["withdrawn"]] == [1] and not _ticked(root)


def test_hand_ticked_criterion_without_annotation_is_left_alone(root):
    _task(root, TASTE)
    _produce(root)
    _edit(root, "- [ ] [REVIEW] The summary", "- [x] [REVIEW] The summary")
    assert vl.apply(TASK, root)["withdrawn"] == [] and _ticked(root)


# ── OpenAI H4: the render gate did not reclassify ────────────────────────────────

def _two_criteria(root):
    _task(root, TIER0 + RENDERED)
    _produce_render(root)


def test_green_on_an_operator_only_criterion_does_not_satisfy_the_render_gate(root):
    _two_criteria(root)
    _rec(root, ac=2, commit=False, render=True)       # a genuine green on AC2 (taste/render)
    p = root / vl.VERDICTS
    row = json.loads(p.read_text())
    row.update(ac=1, ac_digest=_dg(root, 1), id="V-tier0-forged")
    row["judgement"]["judged"] = f"{TASK}#AC1"
    p.write_text(json.dumps(row) + "\n")              # only the tier0 (operator-only) row remains
    _commit_ledger(root)
    assert vl.render_verdicts(TASK, root) == []


def test_control_green_on_the_render_surface_criterion_satisfies_the_gate(root):
    _two_criteria(root)
    rec = _rec(root, ac=2, render=True)
    assert [r["id"] for r in vl.render_verdicts(TASK, root)] == [rec["id"]]


def test_amber_on_the_render_criterion_is_not_rescued_by_a_green_on_another(root):
    _task(root, TASTE + RENDERED)
    _produce_render(root)
    _rec(root, ac=1)                                  # unrelated prose criterion: GREEN
    _rec(root, "amber", ac=2)                         # the render criterion: AMBER
    assert vl.render_verdicts(TASK, root) == []       # negative control (T-3581 round 3)
    assert vl.apply(TASK, root)["owner_after"] == "human"


def test_control_unrelated_green_plus_render_green_satisfies_the_gate(root):
    _task(root, TASTE + RENDERED)
    _produce_render(root)
    _rec(root, ac=1)
    r = _rec(root, ac=2, render=True)
    assert [x["id"] for x in vl.render_verdicts(TASK, root)] == [r["id"]]


def test_render_task_with_no_render_criterion_cannot_be_satisfied_by_a_verdict(root):
    _task(root, TASTE)                                # prose only — nothing asks about rendering
    _produce_render(root)
    _rec(root)
    assert vl.render_verdicts(TASK, root) == []


def test_continuation_edit_that_adds_risk_vocabulary_voids_the_render_verdict(root):
    _task(root, RENDERED)
    _produce_render(root)
    _rec(root, render=True)
    _edit(root, "**If not:** note it", "**If not:** publish the release to the public mirror")
    assert vl.render_verdicts(TASK, root) == []


# ── digest covers the body ───────────────────────────────────────────────────────

def test_editing_steps_or_expected_voids_the_verdict(root):
    _task(root, TASTE)
    _rec(root)
    _edit(root, "1. Read it", "1. Skim it")
    assert vl.apply(TASK, root)["ticked"] == []


def test_digest_ignores_generated_annotations_checkbox_state_and_trailing_space(root):
    f = _task(root, TASTE)
    before = vl.criterion_digest(_humans(f)[0])
    txt = f.read_text().replace("**Steps:**", "**Steps:**   ").replace(
        "  **If not:** note it\n",
        "  **If not:** note it\n  **Reviewer verdict:** green V-x — y\n  **Reviewer escalation (V-z):** because\n")
    f.write_text(txt.replace("- [ ] [REVIEW]", "- [x] [REVIEW]"))
    assert vl.criterion_digest(_humans(f)[0]) == before


def test_record_requires_the_digest_the_reviewer_read(root):
    _task(root, TASTE)
    _produce(root)
    with pytest.raises(vl.VerdictRefused, match="digest"):
        vl.record(TASK, 1, "green", reviewer="openai/gpt-5", rung="x", evidence=["evidence.md"],
                  dispatch_id=_dispatch(root), root=root)


# ── torn / malformed ledger lines fail closed ────────────────────────────────────

def test_torn_trailing_line_fails_closed_and_leaves_a_diagnostic(root):
    _task(root, TASTE)
    _rec(root)
    with (root / vl.VERDICTS).open("a") as fh:
        fh.write('{"id":"V-x","task":"' + TASK + '","ac":1,"outcome":"re')      # the torn RED
    res = vl.apply(TASK, root)
    assert res["ticked"] == [] and not _ticked(root)
    assert _refusals(root, "torn-ledger-line")
    vl.apply(TASK, root)
    assert len(_refusals(root, "torn-ledger-line")) == 1                        # deduplicated


def test_torn_line_naming_another_task_does_not_block_this_one(root):
    _task(root, TASTE)
    _rec(root)
    with (root / vl.VERDICTS).open("a") as fh:
        fh.write('{"id":"V-y","task":"T-4242","ac":1,"outcome":"re\n')
    assert vl.apply(TASK, root)["ticked"]


def test_non_object_json_line_counts_as_torn(root):
    _task(root, TASTE)
    _rec(root)
    with (root / vl.VERDICTS).open("a") as fh:
        fh.write('["not","an","object"]\n')
    assert vl.apply(TASK, root)["ticked"] == []


# ── fw audit ─────────────────────────────────────────────────────────────────────

def test_audit_is_clean_for_a_verified_ledger_and_empty_for_none(root):
    assert vl.audit(root)[0] == 0
    _task(root, TASTE)
    _rec(root)
    code, out = vl.audit(root)
    assert code == 0, out


def test_audit_fails_on_a_hand_appended_row(root):
    _task(root, TASTE)
    _produce(root)
    _forge(root)
    code, out = vl.audit(root)
    assert code == 2 and any("V-FORGED" in ln and "FAIL" in ln for ln in out)


def test_audit_fails_on_a_row_committed_by_someone_other_than_its_worker(root):
    """The producer commits the reviewer's row: exact-worker attribution refuses it."""
    _task(root, TASTE)
    _rec(root, commit=False)
    _produce(root)
    code, out = vl.audit(root)
    assert code == 2 and any("introduced by other" in ln for ln in out)


def test_audit_fails_on_a_row_introduced_by_a_producer(root):
    """Producer exclusion on its own: the commit IS made, author and committer, by exactly the
    worker (so exact-worker attribution passes), but it carries the producer as a co-author."""
    _task(root, TASTE)
    rec = _rec(root, commit=False)
    _git(root, "add", ".context/reviews")
    _git(root, "commit", "-q", "-m",
         f"{TASK}: reviewer verdict\n\nCo-Authored-By: Builder Bot <b@x.y>",
         env={"GIT_AUTHOR_NAME": rec["worker"], "GIT_AUTHOR_EMAIL": "reviewer@x.y",
              "GIT_COMMITTER_NAME": rec["worker"], "GIT_COMMITTER_EMAIL": "reviewer@x.y"})
    code, out = vl.audit(root)
    assert code == 2 and any("introduced by producer" in ln for ln in out), out
    assert vl.apply(TASK, root)["ticked"] == []


def test_audit_fails_on_a_torn_line(root):
    _task(root, TASTE)
    _rec(root)
    with (root / vl.VERDICTS).open("a") as fh:
        fh.write("{oops\n")
    assert vl.audit(root)[0] == 2
