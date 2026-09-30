#!/usr/bin/env python3
"""T-3580 round 2 - the LEDGER enforces, not the judge CLI.

The independent OpenAI review (docs/reports/T-3580-code-review-openai.md) found three high
gaps: worker attribution, unseen pages, panel completeness. Every negative control here goes
through the ledger's shared validator (`satisfying_verdict` via `apply`, `render_verdicts` /
`check-render`, `audit`), never through the judge's display. Fixture repos and fake dispatchers
only: no real task, no `.context/reviews/` in this repo.
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

_HERE = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
import _review_runtime as rt  # noqa: E402
from t3580_judge_cli_test import (  # noqa: E402,F401
    ALL_KINDS, NOCAP, RENDER, TASTE, TID, FakeWorker, _cli, _git, _ident, _judge, _mk_task, _produce, repo,
)


def _task_file(root):
    return next((root / ".tasks" / "active").glob(f"{TID}-*.md"))


def _crit(root, ac=1):
    return next(c for c in vl.human_criteria(_task_file(root).read_text()) if c.index == ac)


def _ctx(root):
    return vl._task_ctx(root, TID)


def _why(root, ac=1):
    """The ledger's reason, without the round-3 `unknown: the latest verdict … is invalid — `
    wrapper (pinned on its own in t3580_round3_test.py), so the fault class leads."""
    import re
    why = vl.satisfying_verdict(_ctx(root), _crit(root, ac))[1]
    return re.sub(r"^unknown: the latest verdict \S+ is invalid — ", "", why)


def _commit_as(root, who):
    _git(root, "add", ".context/reviews")
    _git(root, "commit", "-q", "-m", f"{TID}: reviewer verdict", env=_ident(who))


def _dispatch(root, did, issuer_identity="dispatcher", revision="", vendor="anthropic"):
    return rt.dispatch(root, did, TID, issuer_session="S-x", issuer_identity=issuer_identity,
                       revision=revision, vendor=vendor)


def _green(root, did="rv-1", ac=1, commit=True, outcome="green", issuer_identity="dispatcher",
           extra_evidence=(), rung="rung-1-same-vendor-independent", run_id="", reviewer=None,
           report=True, finish=True, vendor="anthropic"):
    """A verdict exactly as the worker's `record` writes it; `finish` = the worker then exits and
    the runtime signs its completion."""
    _dispatch(root, did, issuer_identity, vendor=vendor)
    rep = root / f".context/reviews/evidence/{TID}/AC{ac}-{did}.md"
    rep.parent.mkdir(parents=True, exist_ok=True)
    rep.write_text(f"checked {did}\n")
    evidence = ([str(rep.relative_to(root))] if report else []) + list(extra_evidence)
    kw = {"guidance": "needs work"} if outcome != "green" else {}
    rec = vl.record(TID, ac, outcome, reviewer=reviewer or f"reviewer-{did}:claude", rung=rung,
                    dispatch_id=did, digest=vl.criterion_digest(_crit(root, ac)),
                    evidence=evidence, run_id=run_id, root=root, **kw)
    if commit:
        _commit_as(root, f"reviewer-{did}")
    if finish:
        rt.finish(root, did)
    return rec


def _green_bypassing_run_checks(root, mp, **kw):
    """Get a row past `record`'s own run check, to show the SHARED validator refuses it later."""
    with mp.context() as m:
        m.setattr(vl, "_run_fault", lambda *a, **k: None)
        return _green(root, **kw)


def _forge(root, mutate_row=None, mutate_comp=None, did="rv-1", commit_as=None, **kw):
    """Record a valid green, then rewrite it as an attacker who holds the dispatch key would:
    `mutate_row` edits the row BEFORE the runtime signs (so the completion agrees with it and only
    the binding under test can fail); `mutate_comp` then edits the completion and re-signs it."""
    _green(root, did=did, commit=False, finish=False, **kw)
    rows = vl._read(vl.VERDICTS, root)
    row = rows[-1]
    if mutate_row:
        mutate_row(row)
    (root / vl.VERDICTS).write_text("".join(json.dumps(r, separators=(",", ":"), sort_keys=True) + "\n"
                                           for r in rows))
    _commit_as(root, commit_as or f"reviewer-{did}")
    comp = rt.finish(root, did)
    if mutate_comp:
        mutate_comp(comp)
        comp.pop("sig")
        comp["sig"] = vl._sign_row(vl._dispatch_key(root), comp)
        (root / vl.COMPLETIONS).write_text(json.dumps(comp, separators=(",", ":"), sort_keys=True) + "\n")
    return row


def _closed(root, ac=1):
    """apply ticks nothing AND the ledger's own answer is 'no'."""
    assert vl.apply(TID, root)["ticked"] == []
    return _why(root, ac)


@pytest.fixture()
def prod(repo):
    _mk_task(repo, TASTE)
    (repo / "notes.md").write_text("notes v1\n")
    _produce(repo)
    return repo


# ── 1. worker attribution: six bindings, each with a negative control ────────────────────────

class TestWorkerAttribution:
    def test_control_a_genuine_worker_row_ticks_and_audits_clean(self, prod):
        _green(prod)
        assert [t["ac"] for t in vl.apply(TID, prod)["ticked"]] == [1]
        assert vl.audit(prod)[0] == 0

    def test_control_forge_helper_with_no_mutation_is_valid(self, prod):
        _forge(prod)
        assert [t["ac"] for t in vl.apply(TID, prod)["ticked"]] == [1]

    def test_row_without_a_signed_completion_fails(self, prod):
        """FakeWorker-shaped row, completion removed: a registration is not a completion."""
        _green(prod, finish=False)                  # the worker never exited / runtime never signed
        assert not (prod / vl.COMPLETIONS).exists()  # record wrote none
        assert _closed(prod).startswith("no-completion")
        assert vl.audit(prod)[0] == 2

    def test_completion_with_a_bad_signature_fails(self, prod):
        _green(prod)
        comp = json.loads((prod / vl.COMPLETIONS).read_text())
        comp["sig"] = "0" * 64
        (prod / vl.COMPLETIONS).write_text(json.dumps(comp) + "\n")
        assert _closed(prod).startswith("bad-completion")

    def test_exact_verdict_contents_a_changed_row_is_refused(self, prod):
        """5. The row's bytes differ from what the worker reported."""
        _green(prod, commit=False)                  # the runtime has signed the row as left
        rows = vl._read(vl.VERDICTS, prod)
        rows[-1]["guidance"] = "edited after the worker exited"
        (prod / vl.VERDICTS).write_text(json.dumps(rows[-1]) + "\n")
        _commit_as(prod, "reviewer-rv-1")
        assert _closed(prod).startswith("verdict-tampered")
        assert vl.audit(prod)[0] == 2

    def test_fresh_session_worker_must_be_the_dispatch_identity(self, prod):
        """1. A worker string that is not the identity of this dispatch."""
        _forge(prod, mutate_row=lambda r: r.update(worker="reviewer-somebody-else"))
        assert _closed(prod).startswith("worker-not-fresh")

    def test_fresh_session_worker_is_not_the_dispatch_issuer(self, prod, monkeypatch):
        """1. record refuses it; and if record is bypassed the shared validator still does."""
        with pytest.raises(vl.VerdictRefused, match="dispatch issuer"):
            _green(prod, issuer_identity="reviewer-rv-1")
        real = vl.dispatch_record

        def blind(root, did):
            rec, why = real(root, did)
            return (dict(rec, issuer_identity="", issuer_session="") if rec else rec), why
        with monkeypatch.context() as m:
            m.setattr(vl, "dispatch_record", blind)
            _green(prod, did="rv-2", issuer_identity="reviewer-rv-2")
        assert _closed(prod).startswith("worker-not-fresh")

    def test_row_reviewer_must_be_attributed_to_the_worker(self, prod):
        """1. reviewer and worker are one identity."""
        _forge(prod, mutate_row=lambda r: (r.update(reviewer="openai/gpt-5"),
                                            r["judgement"].update(judge="openai/gpt-5")))
        assert _closed(prod).startswith("reviewer-worker-mismatch")

    def test_record_refuses_a_reviewer_not_attributed_to_its_worker(self, prod):
        _dispatch(prod, "rv-1")
        with pytest.raises(vl.VerdictRefused, match="not attributed to worker"):
            vl.record(TID, 1, "green", reviewer="openai/gpt-5", rung="r", dispatch_id="rv-1",
                      digest=vl.criterion_digest(_crit(prod)), evidence=["notes.md"], root=prod)

    def test_reviewed_revision_unknown_commit(self, prod):
        _forge(prod, mutate_row=lambda r: r.update(revision="0" * 40))
        assert _closed(prod).startswith("revision: the row names revision 000000000")

    def test_reviewed_revision_where_the_criterion_was_different(self, prod, monkeypatch):
        """2. The dispatch was issued for a revision holding another version of the criterion:
        record refuses, and if record is bypassed the shared validator still does."""
        early = subprocess.run(["git", "rev-parse", "HEAD"], cwd=prod, capture_output=True,
                               text=True).stdout.strip()
        f = _task_file(prod)
        f.write_text(f.read_text().replace("reads as a peer briefing", "reads as an executive briefing"))
        _git(prod, "add", "-A")
        _git(prod, "commit", "-q", "-m", f"{TID}: reword the criterion", env=_ident("Builder Bot"))
        _dispatch(prod, "rv-1", revision=early)
        with pytest.raises(vl.VerdictRefused, match="at reviewed revision"):
            vl.record(TID, 1, "green", reviewer="reviewer-rv-1:x", rung="r", dispatch_id="rv-1",
                      digest=vl.criterion_digest(_crit(prod)), evidence=["notes.md"], root=prod)
        real = vl._criterion_at
        with monkeypatch.context() as m:
            m.setattr(vl, "_criterion_at", lambda root, rev, t, ac: vl.criterion_digest(_crit(prod)))
            vl.record(TID, 1, "green", reviewer="reviewer-rv-1:x", rung="r", dispatch_id="rv-1",
                      digest=vl.criterion_digest(_crit(prod)), evidence=["notes.md"], root=prod)
        assert vl._criterion_at is real
        _commit_as(prod, "reviewer-rv-1")
        rt.finish(prod, "rv-1")
        assert "not the text the worker digested" in _closed(prod)

    def test_record_refuses_a_criterion_edited_since_the_revision(self, prod):
        f = _task_file(prod)
        f.write_text(f.read_text().replace("reads as a peer briefing", "reads as an executive briefing"))
        _dispatch(prod, "rv-1")
        with pytest.raises(vl.VerdictRefused, match="revision"):
            vl.record(TID, 1, "green", reviewer="reviewer-rv-1:x", rung="r", dispatch_id="rv-1",
                      digest=vl.criterion_digest(_crit(prod)), evidence=["notes.md"], root=prod)

    def test_evidence_at_the_revision_must_match_what_the_worker_hashed(self, prod):
        """2/4. `notes.md` at the reviewed revision is v1; the worker hashed a v2."""
        (prod / "notes.md").write_text("notes v2, not committed\n")
        _dispatch(prod, "rv-1")
        with pytest.raises(vl.VerdictRefused, match="reviewed revision"):
            vl.record(TID, 1, "green", reviewer="reviewer-rv-1:x", rung="r", dispatch_id="rv-1",
                      digest=vl.criterion_digest(_crit(prod)), evidence=["notes.md"], root=prod)

    def test_criterion_digest_in_the_completion_must_equal_the_rows(self, prod):
        """3."""
        _forge(prod, mutate_comp=lambda c: c["verdicts"][0].update(ac_digest="deadbeef0000"))
        assert "completion-mismatch" in _closed(prod)

    def test_evidence_hashes_in_the_completion_must_equal_the_rows(self, prod):
        """4."""
        _forge(prod, mutate_comp=lambda c: c["verdicts"][0].update(evidence_sha256={}))
        assert "evidence hashes" in _closed(prod)

    def test_verdict_hash_in_the_completion_must_equal_the_rows(self, prod):
        _forge(prod, mutate_comp=lambda c: c["verdicts"][0].update(verdict_sha256="0" * 64))
        assert "verdict-tampered" in _closed(prod)

    def test_completion_for_another_dispatch_is_refused(self, prod):
        _forge(prod, mutate_comp=lambda c: c.update(dispatch_id="rv-2"))
        assert "no-completion" in _closed(prod)

    def test_introducing_commit_must_be_by_exactly_the_worker(self, prod):
        """6. Any non-producer identity is no longer enough."""
        _forge(prod, commit_as="Some Other Reviewer")
        why = _closed(prod)
        assert "introduced-by-other" in why and "not by its worker" in why
        assert vl.audit(prod)[0] == 2

    def test_committer_and_author_must_both_be_the_worker(self, prod):
        _green(prod, commit=False)
        _git(prod, "add", ".context/reviews")
        env = {**_ident("reviewer-rv-1"), "GIT_COMMITTER_NAME": "Committer Elsewhere",
               "GIT_COMMITTER_EMAIL": "c@x.y"}
        _git(prod, "commit", "-q", "-m", f"{TID}: reviewer verdict", env=env)
        assert "introduced-by-other" in _closed(prod)

    def test_a_producer_identity_is_never_a_worker(self, prod):
        _forge(prod, commit_as="Builder Bot")
        assert "introduced-by-other" in _closed(prod)


# ── 2. unseen pages: the shared validator, not the display ──────────────────────────────────

RENDER2 = ("- [ ] [REVIEW] The review and list layout reads clearly when rendered at `/review` and `/list`\n"
           "  **Steps:**\n  1. Open the pages\n  **Expected:** the layout is tidy\n  **If not:** note it\n")


@pytest.fixture()
def rprod(repo):
    (repo / "web/blueprints").mkdir(parents=True)
    (repo / "web/blueprints/review.py").write_text('@bp.route("/review")\ndef r(): pass\n')
    _mk_task(repo, RENDER2, extra_fm="components:\n  - web/blueprints/review.py\n")
    _produce(repo)
    return repo


def _shot(root, name, data=b"png"):
    f = root / name
    f.write_bytes(data)
    return f


def _render_green(root, mp, *, pages, caps, cite, did="rv-1", bypass=True):
    """A render green whose run records `pages` required and `caps` as the capture results.
    `bypass` skips record's own render check so the SHARED validator can be shown to refuse the
    row when apply / check-render / audit meet it."""
    files = {}
    for name, ok in caps.items():
        files[name] = _shot(root, f"{did}-{name.strip('/')}.png", name.encode())
    captures = [{"page": p, "ok": bool(ok), "sha256": vl._hash_path(files[p]) if ok else "",
                 "error": "" if ok else "HTTP 500"} for p, ok in caps.items()]
    vl.register_run(f"run-{did}", TID, acs=[1], rung="rung-1-same-vendor-independent",
                    seats=[{"seat": "claude", "vendor": "claude"}], required_vendors=1,
                    pages={"1": list(pages)}, captures=captures, root=root)
    cited = [files[p].name for p in cite]
    with mp.context() as m:
        if bypass:
            m.setattr(vl, "_run_fault", lambda *a, **k: None)
        _dispatch(root, did)
        rep = root / f".context/reviews/evidence/{TID}/AC1-{did}.md"
        rep.parent.mkdir(parents=True, exist_ok=True)
        rep.write_text("looked\n")
        vl.record(TID, 1, "green", reviewer=f"reviewer-{did}:claude", rung="rung-1-same-vendor-independent",
                  dispatch_id=did, digest=vl.criterion_digest(_crit(root)),
                  evidence=[str(rep.relative_to(root))] + cited, run_id=f"run-{did}", root=root)
    vl.bind_dispatch(f"run-{did}", "claude", did, "claude", root=root)
    _commit_as(root, f"reviewer-{did}")
    rt.finish(root, did)


class TestUnseenPages:
    def test_control_every_required_page_seen_and_cited(self, rprod, monkeypatch):
        _render_green(rprod, monkeypatch, pages=["/review", "/list"],
                      caps={"/review": True, "/list": True}, cite=["/review", "/list"], bypass=False)
        assert [t["ac"] for t in vl.apply(TID, rprod)["ticked"]] == [1]
        assert vl.render_verdicts(TID, rprod)

    @pytest.mark.parametrize("pages,caps,cite,needle", [
        (["/review"], {"/review": False}, [], "no verified screenshot"),
        (["/review", "/list"], {"/review": True, "/list": False}, ["/review"], "'/list'"),
        ([], {}, [], "no required page"),
        (["/review"], {"/review": True}, [], "not cited"),
    ], ids=["failed-capture", "partial-capture", "no-pages-recorded", "screenshot-not-cited"])
    def test_render_green_without_verified_screenshots_is_refused_by_apply_and_check_render(
            self, rprod, monkeypatch, pages, caps, cite, needle):
        _render_green(rprod, monkeypatch, pages=pages, caps=caps, cite=cite)
        assert needle in _closed(rprod)                       # apply
        assert vl.render_verdicts(TID, rprod) == []           # check-render (P-013 read side)
        assert _cli(rprod, "check-render", TID).returncode == 1

    def test_record_itself_refuses_a_render_green_on_an_unseen_page(self, rprod, monkeypatch):
        with pytest.raises(vl.VerdictRefused, match="no verified screenshot"):
            _render_green(rprod, monkeypatch, pages=["/review"], caps={"/review": False}, cite=[],
                          bypass=False)

    def test_render_green_with_no_run_is_refused(self, rprod, monkeypatch):
        with pytest.raises(vl.VerdictRefused, match="needs a review run"):
            _green(rprod)
        _green_bypassing_run_checks(rprod, monkeypatch, did="rv-2")
        assert _closed(rprod).startswith("render-needs-run")
        assert vl.render_verdicts(TID, rprod) == []

    def test_a_row_claiming_a_run_its_dispatch_is_not_bound_to(self, rprod, monkeypatch):
        vl.register_run("run-x", TID, acs=[1], rung="r", seats=[{"seat": "claude", "vendor": "claude"}],
                        pages={"1": ["/review"]}, captures=[], root=rprod)
        _green_bypassing_run_checks(rprod, monkeypatch, run_id="run-x")   # never bound
        assert _closed(rprod).startswith("run-unbound")

    def test_judge_persists_partial_capture_results_in_the_run(self, rprod):
        f = _task_file(rprod)
        def cap(url, pages, out):
            out.mkdir(parents=True, exist_ok=True)
            p = out / judge_cli._shot_name(0, pages[0])
            p.write_bytes(b"png")
            return [p], "partial: /list: HTTP 500"
        w = FakeWorker("green")
        res = _judge(rprod, dispatcher=w, capture=cap)
        run = next(r for r in vl._read(vl.RUNS, rprod) if r.get("kind") == "run")
        by_page = {c["page"]: c for c in run["captures"]}
        assert by_page["/review"]["ok"] and by_page["/review"]["sha256"]
        assert not by_page["/list"]["ok"] and "500" in by_page["/list"]["error"]
        assert run["pages"] == {"1": ["/review", "/list"]}
        assert res["evidence"]["partial"] == ["/list"]
        assert "did NOT see: `/list`" in w.calls[0]["brief"]
        # the worker's green is refused by record: nothing reaches the ledger
        assert not vl._read(vl.VERDICTS, rprod) and res["outcomes"] == {1: "unknown"}
        assert f.exists()

    def test_judge_with_every_page_captured_reaches_green_through_apply(self, rprod):
        def cap(url, pages, out):
            out.mkdir(parents=True, exist_ok=True)
            ps = []
            for i, pg in enumerate(pages):
                p = out / judge_cli._shot_name(i, pg)
                p.write_bytes(pg.encode())
                ps.append(p)
            return ps, ""
        res = _judge(rprod, dispatcher=FakeWorker("green"), capture=cap)
        assert res["outcomes"] == {1: "green"}
        assert [t["ac"] for t in vl.apply(TID, rprod)["ticked"]] == [1]


# ── 3. panels: every required seat, every required vendor ──────────────────────────────────

SEATS = [{"seat": "claude", "vendor": "claude"}, {"seat": "codex", "vendor": "codex"},
         {"seat": "opencode", "vendor": "opencode"}]


def _panel(root, outcomes, vendors=("claude", "codex", "opencode"), required=3):
    """Register a 3-seat run and let each seat record `outcomes[seat]` (None = seat never records)."""
    vl.register_run("run-p", TID, acs=[1], rung="rung-5-panel", seats=SEATS,
                    required_vendors=required, root=root)
    for s, v in zip(SEATS, vendors):
        oc = outcomes.get(s["seat"])
        did = f"rv-{s['seat']}"
        if oc is None:
            _dispatch(root, did, vendor=v)
        else:
            _green(root, did=did, outcome=oc, rung=f"rung-5-panel:{s['seat']}", run_id="run-p",
                   vendor=v)
        vl.bind_dispatch("run-p", s["seat"], did, v, root=root)


class TestPanels:
    def test_control_all_seats_green_across_three_vendors(self, prod):
        _panel(prod, {"claude": "green", "codex": "green", "opencode": "green"})
        assert [t["ac"] for t in vl.apply(TID, prod)["ticked"]] == [1]

    def test_seat_one_green_seat_two_missing_leaves_the_criterion_open_through_apply(self, prod):
        _panel(prod, {"claude": "green", "codex": None, "opencode": None})
        why = _closed(prod)
        assert why.startswith("panel-incomplete") and "'codex'" in why
        assert vl.render_verdicts(TID, prod) == []

    def test_a_missing_last_seat_leaves_it_open(self, prod):
        _panel(prod, {"claude": "green", "codex": "green", "opencode": None})
        assert "'opencode'" in _closed(prod)

    def test_a_non_green_seat_leaves_it_open(self, prod):
        _panel(prod, {"claude": "green", "codex": "red", "opencode": "green"})
        assert _closed(prod).startswith(("latest verdict is", "panel-incomplete"))

    def test_three_seats_but_one_vendor_cannot_satisfy_a_three_vendor_requirement(self, prod):
        _panel(prod, {"claude": "green", "codex": "green", "opencode": "green"},
               vendors=("claude", "claude", "claude"))
        why = _closed(prod)
        assert why.startswith("degraded") and "single-vendor panel" in why

    def test_control_the_same_single_vendor_seats_satisfy_a_one_vendor_requirement(self, prod):
        _panel(prod, {"claude": "green", "codex": "green", "opencode": "green"},
               vendors=("claude", "claude", "claude"), required=1)
        assert [t["ac"] for t in vl.apply(TID, prod)["ticked"]] == [1]

    def test_a_rung_5_claim_with_no_run_is_refused(self, prod, monkeypatch):
        with pytest.raises(vl.VerdictRefused, match="registered review run"):
            _green(prod, rung="rung-5-panel:claude")
        _green_bypassing_run_checks(prod, monkeypatch, did="rv-2", rung="rung-5-panel:claude")
        assert _closed(prod).startswith("panel-needs-run")


class TestJudgePanels:
    HI = "cost_estimate:\n  blast_radius: 9\n"

    def test_full_panel_dispatches_each_vendor_and_the_ledger_accepts_it(self, repo, monkeypatch):
        monkeypatch.setattr(judge_cli, "_dispatchable_kinds", lambda root: ALL_KINDS)
        monkeypatch.setattr(judge_cli, "_kind_vendors", lambda root: {k: k for k in ALL_KINDS})
        _mk_task(repo, TASTE, extra_fm=self.HI)
        _produce(repo)
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w)
        assert [c["vendor"] for c in w.calls] == ["claude", "codex", "opencode"]
        assert res["outcomes"] == {1: "green"}
        assert [t["ac"] for t in vl.apply(TID, repo)["ticked"]] == [1]

    def test_single_vendor_panel_is_reported_degraded_and_cannot_satisfy(self, repo, capsys):
        """Until T-3582 builds real codex/opencode seats."""
        _mk_task(repo, TASTE, extra_fm=self.HI)
        _produce(repo)
        w = FakeWorker("green")
        res = _judge(repo, dispatcher=w)
        assert res["rung"] == 5 and res["degraded"] == "degraded: single-vendor panel"
        assert [c["vendor"] for c in w.calls] == ["claude"]
        assert res["outcomes"] == {1: "unknown"} and "panel-incomplete" in res["why"][1]
        run = next(r for r in vl._read(vl.RUNS, repo) if r.get("kind") == "run")
        assert run["required_vendors"] == 3 and run["degraded"]
        assert [s["seat"] for s in run["seats"]] == ["claude-code", "codex", "opencode"]
        assert vl._read(vl.VERDICTS, repo)                      # the verdict itself is recorded
        assert _closed(repo).startswith("panel-incomplete")     # ... and applies to nothing
        judge_cli._print_result(res)
        assert "degraded: single-vendor panel" in capsys.readouterr().out

    def test_the_brief_of_a_degraded_run_says_so(self, repo):
        _mk_task(repo, TASTE, extra_fm=self.HI)
        _produce(repo)
        w = FakeWorker("green")
        _judge(repo, dispatcher=w)
        assert "degraded: single-vendor panel" in w.calls[0]["brief"]


# ── 4. IW-7 impact-risk tiers ───────────────────────────────────────────────────────────────

def _td(fm=None, name="a change"):
    return {"frontmatter": {"name": name, **(fm or {})}, "body": "", "path": Path(".")}


class TestImpactTiers:
    def test_low(self):
        assert judge_cli._calculate_rung(_td()) == (1, "default")

    @pytest.mark.parametrize("fm,needle", [
        ({"components": ["lib/foo.py"]}, "consumer-facing"),
        ({"cost_estimate": {"blast_radius": 4}}, "blast_radius=4"),
        ({"workflow_type": "inception"}, "inception GO"),
        ({"components": ["a", "b", "c"]}, "components=3"),
    ])
    def test_medium(self, fm, needle):
        rung, why = judge_cli._calculate_rung(_td(fm))
        assert rung == 3 and needle in why

    @pytest.mark.parametrize("fm,name,needle", [
        ({"cost_estimate": {"blast_radius": 6}}, "x", "blast_radius=6"),
        ({"voi_score": 0.7}, "x", "voi_score"),
        ({}, "advance the project objectives", "project objective"),
        ({"tags": ["security"]}, "x", "security"),
        ({"iw_confidence": 1}, "x", "confidence=1"),
        ({}, "deploy to production", "not undone by git revert"),
        ({}, "cross-project rollout", "cross-project audience"),
        ({"components": list("abcde")}, "x", "components=5"),
    ])
    def test_high(self, fm, name, needle):
        rung, why = judge_cli._calculate_rung(_td(fm, name))
        assert rung == 5 and needle in why

    def test_high_outranks_medium(self):
        rung, why = judge_cli._calculate_rung(_td({"components": ["lib/x.py"], "voi_score": 0.9}))
        assert rung == 5 and "voi_score" in why

    def test_ceiling_steps_high_to_medium_to_low(self):
        assert judge_cli._apply_ceiling(5, "r", 99, 10)[0] == 3
        assert judge_cli._apply_ceiling(3, "r", 99, 10)[0] == 1
        assert "not skipped" in judge_cli._apply_ceiling(1, "r", 99, 10)[2]

    def test_inputs_and_reason_are_recorded_in_the_run(self, repo):
        _mk_task(repo, TASTE, extra_fm="components:\n  - lib/verdict_ledger.py\n")
        _produce(repo)
        res = _judge(repo, dispatcher=FakeWorker("green"))
        assert res["rung"] == 3 and "consumer-facing" in res["rung_reason"]
        run = next(r for r in vl._read(vl.RUNS, repo) if r.get("kind") == "run")
        assert run["inputs"]["audience"] == "consumers"
        assert run["inputs"]["consumer_paths"] == ["lib/verdict_ledger.py"]
        assert run["inputs"]["reversibility"] == "git-only"
        assert "consumer-facing" in run["reason"] and run["rung"] == "rung-3-termlink-single-reviewer"


# ── 6. every outcome is validated before it is reported ─────────────────────────────────────

class TestNonGreenValidation:
    def _hand_row(self, outcome):
        w = FakeWorker(write=False)

        def d(**kw):
            did = w(**kw)
            (kw["root"] / ".context/reviews").mkdir(parents=True, exist_ok=True)
            (kw["root"] / vl.VERDICTS).write_text(json.dumps(
                {"task": TID, "ac": 1, "dispatch_id": did, "outcome": outcome}) + "\n")
            return did
        return d

    @pytest.mark.parametrize("outcome", ["amber", "red", "escalate"])
    def test_a_malformed_non_green_row_is_unknown_not_its_claimed_outcome(self, repo, outcome):
        _mk_task(repo, TASTE)
        _produce(repo)
        res = _judge(repo, dispatcher=self._hand_row(outcome))
        r = res["dispatches"][0]["results"][0]
        assert r["outcome"] == "unknown" and r["source"] == "ledger-row-invalid"
        assert res["outcomes"] == {1: "unknown"}

    def test_a_well_formed_non_green_without_a_completion_is_unknown(self, repo):
        _mk_task(repo, TASTE)
        _produce(repo)
        w = FakeWorker("amber")

        def d(**kw):
            did = w(**kw)
            (kw["root"] / vl.COMPLETIONS).write_text("")
            return did
        res = _judge(repo, dispatcher=d)
        r = res["dispatches"][0]["results"][0]
        assert r["outcome"] == "unknown" and "no-completion" in r["why"]

    def test_control_a_valid_amber_is_reported_amber(self, repo):
        _mk_task(repo, TASTE)
        _produce(repo)
        assert _judge(repo, dispatcher=FakeWorker("amber"))["outcomes"] == {1: "amber"}


# ── 7. real dispatcher arguments ────────────────────────────────────────────────────────────

class TestRealDispatcherArguments:
    @pytest.mark.parametrize("vendor", ["claude", "codex", "opencode"])
    def test_vendor_reaches_the_dispatch_argv(self, repo, monkeypatch, vendor):
        calls = []

        def fake_run(cmd, **kw):
            calls.append(cmd)

            class R:
                returncode, stderr = 0, ""
                stdout = "Worker spawned: judge-x-abc123 (wdir: /x)"
            return R()
        monkeypatch.setattr(judge_cli.subprocess, "run", fake_run)
        judge_cli._dispatch_real(task_id=TID, brief="b", root=repo, name="judge-x", vendor=vendor)
        d = calls[0]
        assert d[d.index("--worker-kind") + 1] == vendor
        assert d[d.index("--task-type") + 1] == "review"
        assert "--project-dir" not in d and d[d.index("--project") + 1] == str(repo)

    def test_the_wrapper_accepts_every_flag_the_judge_passes(self):
        """`--project-dir` was an unknown option to termlink.sh: pin the flag set it parses."""
        sh = (_HERE / "agents/termlink/termlink.sh").read_text()
        argv = judge_cli._dispatch_argv(Path("fw"), task_id=TID, name="n", prompt_file=Path("p"),
                                        root=Path("/r"), vendor="claude", timeout=1)
        for flag in (a for a in argv if a.startswith("--")):
            assert f"{flag})" in sh, f"termlink.sh dispatch does not parse {flag}"

    def test_judge_hands_each_seat_its_vendor(self, repo, monkeypatch):
        monkeypatch.setattr(judge_cli, "_dispatchable_kinds", lambda root: ALL_KINDS)
        monkeypatch.setattr(judge_cli, "_kind_vendors", lambda root: {k: k for k in ALL_KINDS})
        _mk_task(repo, TASTE, extra_fm="cost_estimate:\n  blast_radius: 9\n")
        _produce(repo)
        seen = []
        w = FakeWorker("green")

        def d(**kw):
            seen.append(kw["vendor"])
            return w(**kw)
        _judge(repo, dispatcher=d)
        assert seen == ["claude", "codex", "opencode"]
