"""T-4214 (T-4202 leg C): `fw reviewer judge` puts the leg-A screenshots (every checklist state at
every configured width) and the leg-B checklist into the brief of a render criterion, and the
ledger refuses a render green whose run did not record them.

The author's own reading never satisfies this: the reviewer is an independent dispatch, and the
green is only recorded with the shots cited. Fakes only: FakeWorker plays the dispatched reviewer.
"""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
from _review_runtime import hermetic_review_env  # noqa: E402,F401  (T-4205: autouse)
from _review_runtime import register_run as _reg  # noqa: E402  (signed run registration)
from _visual_evidence import WIDTHS, add_checklist, write_shots  # noqa: E402
from t3580_judge_cli_test import (  # noqa: E402,F401  (fixtures + helpers from the judge suite)
    TID,
    FakeWorker,
    _judge,
    _mk_task,
    _produce,
    repo,
)

RENDER = ("- [ ] [REVIEW] The review page layout reads clearly when rendered at `/review`\n"
          "  **Steps:**\n  1. Open the page\n  **Expected:** the layout is tidy\n  **If not:** note it\n")


def _render_task(repo_path: Path) -> Path:
    (repo_path / "web/blueprints").mkdir(parents=True, exist_ok=True)
    (repo_path / "web/blueprints/review.py").write_text('@bp.route("/review")\ndef r(): pass\n')
    _mk_task(repo_path, RENDER, extra_fm="components:\n  - web/blueprints/review.py\n")
    _produce(repo_path)                                   # the review binds to a commit
    return next((repo_path / ".tasks" / "active").glob(f"{TID}-*.md"))


def _page_capture(url, pages, out):
    """A capture that sees every required page (so the page rule is satisfied in every test)."""
    out.mkdir(parents=True, exist_ok=True)
    shots = []
    for i, pg in enumerate(pages):
        f = out / judge_cli._shot_name(i, pg)
        f.write_bytes(pg.encode())
        shots.append(f)
    return shots, ""


def _verdict_rows(root):
    return [r for r in vl._read(vl.VERDICTS, root) if r.get("kind", "verdict") != "run"]


# ── what the judge gathers ────────────────────────────────────────────────

class TestGathering:
    def test_every_state_at_every_width_is_gathered_with_its_hash(self, repo):
        tf = _render_task(repo)
        add_checklist(tf, repo, TID)
        ev = judge_cli._gather_visual(repo, TID, judge_cli._load_task(TID, repo))
        assert ev["problems"] == []
        assert [(s["state"], s["width"]) for s in ev["shots"]] == [("page", w) for w in WIDTHS]
        assert all(s["sha256"] and s["path"].startswith(".context/visual/T-") for s in ev["shots"])

    def test_a_missing_width_is_reported_as_a_missing_shot(self, repo):
        tf = _render_task(repo)
        add_checklist(tf, repo, TID)
        (repo / ".context/visual" / TID / "page@1440.png").unlink()
        ev = judge_cli._gather_visual(repo, TID, judge_cli._load_task(TID, repo))
        missing = [s["width"] for s in ev["shots"] if not s["sha256"]]
        assert missing == [1440]
        assert any("need 3" in p and "missing [1440]" in p for p in ev["problems"])

    def test_no_checklist_is_a_problem(self, repo):
        _render_task(repo)
        ev = judge_cli._gather_visual(repo, TID, judge_cli._load_task(TID, repo))
        assert any("no `## Visual Verification` section" in p for p in ev["problems"])

    def test_configured_widths_drive_the_gather(self, repo, monkeypatch):
        tf = _render_task(repo)
        monkeypatch.setenv("FW_UX_SHOT_WIDTHS", "800,1280,1600")
        add_checklist(tf, repo, TID)                      # checklist + shots at 1024/1440/1920
        ev = judge_cli._gather_visual(repo, TID, judge_cli._load_task(TID, repo))
        assert ev["widths"] == [800, 1280, 1600]
        assert any("must equal UX_SHOT_WIDTHS" in p for p in ev["problems"])
        assert all(not s["sha256"] for s in ev["shots"])  # no shot exists at the configured widths

    def test_invalid_width_config_is_a_problem_not_a_pass(self, repo, monkeypatch):
        _render_task(repo)
        monkeypatch.setenv("FW_UX_SHOT_WIDTHS", "1024,1440")
        ev = judge_cli._gather_visual(repo, TID, judge_cli._load_task(TID, repo))
        assert ev["shots"] == [] and any("UX_SHOT_WIDTHS unreadable" in p for p in ev["problems"])


# ── what the reviewer is told ─────────────────────────────────────────────

class TestBrief:
    def test_brief_lists_every_shot_and_asks_for_a_read_of_each(self, repo):
        tf = _render_task(repo)
        add_checklist(tf, repo, TID)
        w = FakeWorker("green", cite_shots=False)
        _judge(repo, dispatcher=w, capture=_page_capture)
        brief = w.calls[0]["brief"]
        for width in WIDTHS:
            assert f"- `.context/visual/{TID}/page@{width}.png`" in brief
        assert "Read EVERY screenshot above" in brief
        assert "MUST NOT return green" not in brief

    def test_brief_forbids_green_when_a_shot_is_missing(self, repo):
        tf = _render_task(repo)
        add_checklist(tf, repo, TID)
        (repo / ".context/visual" / TID / "page@1920.png").unlink()
        w = FakeWorker("escalate", cite_shots=False)
        _judge(repo, dispatcher=w, capture=_page_capture)
        brief = w.calls[0]["brief"]
        assert f"MISSING: `.context/visual/{TID}/page@1920.png`" in brief
        assert "MUST NOT return green for a render criterion" in brief

    def test_brief_forbids_green_when_the_checklist_does_not_pass(self, repo):
        tf = _render_task(repo)
        add_checklist(tf, repo, TID)
        tf.write_text(tf.read_text().replace("| page | Load | ok | ok | ok | |",
                                             "| page | Load | ok |  | ok | |"))
        w = FakeWorker("escalate", cite_shots=False)
        _judge(repo, dispatcher=w, capture=_page_capture)
        brief = w.calls[0]["brief"]
        assert "does NOT pass" in brief and "blank cell" in brief


# ── what the ledger accepts ───────────────────────────────────────────────

class TestGreenNeedsTheEvidence:
    def test_green_with_checklist_and_every_shot_cited_is_recorded(self, repo):
        tf = _render_task(repo)
        add_checklist(tf, repo, TID)
        res = _judge(repo, dispatcher=FakeWorker("green"), capture=_page_capture)
        assert res["outcomes"] == {1: "green"}
        assert [t["ac"] for t in vl.apply(TID, repo)["ticked"]] == [1]

    def test_green_without_the_checklist_is_refused_at_record(self, repo):
        _render_task(repo)                                    # no checklist, no shots
        res = _judge(repo, dispatcher=FakeWorker("green"), capture=_page_capture)
        assert res["outcomes"] == {1: "unknown"}
        assert _verdict_rows(repo) == []

    def test_green_with_a_missing_shot_is_refused_at_record(self, repo):
        tf = _render_task(repo)
        add_checklist(tf, repo, TID)
        (repo / ".context/visual" / TID / "page@1024.png").unlink()
        res = _judge(repo, dispatcher=FakeWorker("green"), capture=_page_capture)
        assert res["outcomes"] == {1: "unknown"}
        assert _verdict_rows(repo) == []

    def test_green_that_does_not_cite_every_shot_is_refused_at_record(self, repo):
        tf = _render_task(repo)
        add_checklist(tf, repo, TID)
        res = _judge(repo, dispatcher=FakeWorker("green", cite_shots=False), capture=_page_capture)
        assert res["outcomes"] == {1: "unknown"}
        assert _verdict_rows(repo) == []

    def test_run_registration_records_the_visual_evidence_under_the_signature(self, repo):
        tf = _render_task(repo)
        add_checklist(tf, repo, TID)
        _judge(repo, dispatcher=FakeWorker("escalate", cite_shots=False), capture=_page_capture)
        run = next(r for r in vl._read(vl.RUNS, repo) if r.get("kind") == "run")
        assert run["visual"]["widths"] == list(WIDTHS)
        assert [s["width"] for s in run["visual"]["shots"]] == list(WIDTHS)
        assert all(len(s["sha256"]) == 64 for s in run["visual"]["shots"])
        assert run.get("sig")  # the visual record is inside the signed row

    def test_a_run_without_visual_cannot_back_a_render_green(self, repo):
        """The ledger's own rule, independent of the judge: a render run registered with no
        `visual` record refuses a green whose page screenshot is otherwise perfect."""
        _render_task(repo)
        shots = write_shots(repo, "plain", "page")
        _reg(f"run-{TID}-plain", TID, acs=[1], rung="rung-1-same-vendor-independent",
             seats=[{"seat": "claude", "vendor": "claude"}], required_vendors=1,
             pages={"1": ["/review"]},
             captures=[{"page": "/review", "ok": True, "sha256": shots[0]["sha256"], "error": ""}],
             visual=None, root=repo)
        run = next(r for r in vl._read(vl.RUNS, repo) if r.get("run_id") == f"run-{TID}-plain")
        assert "visual" not in run
        assert run["pages"] == {"1": ["/review"]}
