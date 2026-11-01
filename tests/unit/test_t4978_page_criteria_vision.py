"""T-4978 (ring20, be.15): opencode (`vision: false`) still sat [REVIEW] criteria about app pages.

ring20's criteria ("[REVIEW] /classic SSL Certificates widget shows 4 tiles ...") classify taste
or unclassified, because their tasks do not touch AEF's own web/ layout, so `render` stayed False
and the T-4944 vision exclusion never fired. The judge now also asks whether a criterion names an
app route (`page`), and excludes blind kinds for those too. The ledger's render rules are not
touched: they still key on `render`.
"""
from __future__ import annotations

import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent.parent))
sys.path.insert(0, str(_HERE))

from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402


@pytest.mark.parametrize("text", [
    "[REVIEW] /classic SSL Certificates widget shows 4 tiles, bar green above 30d",
    "On /cicd the Builds table lists the last 15 runs",
    "`/review/T-4607` shows the Recommendation card",
    "open http://<watchtower>:3000/approvals and check the Arc Closure section",
    "/cicd/builds has a status column",
])
def test_names_page_true(text):
    assert judge_cli.names_page(text)


@pytest.mark.parametrize("text", [
    "see /tmp/out.log and /opt/project",
    "POST /api/validate returns 200",
    "docs/reports/T-4978.md exists",
    "the hook edits /etc/hosts",
    "and/or the 24/7 job, w/o a retry",
    "run /x.py",
    "the operator decides",
])
def test_names_page_false(text):
    assert not judge_cli.names_page(text)


def test_partition_marks_a_taste_criterion_that_names_a_page(monkeypatch, tmp_path):
    """ring20's T-878 case: class unclassified, render False, page True."""
    text = ("---\nid: T-9\n---\n## Acceptance Criteria\n\n### Human\n"
            "- [ ] [REVIEW] /classic SSL Certificates widget shows 4 tiles\n"
            "  **Steps:** open it\n  **Expected:** 4 tiles\n  **If not:** note it\n"
            "- [ ] [REVIEW] The tone of the release notes suits consumers\n"
            "  **Steps:** read them\n  **Expected:** plain\n  **If not:** note it\n")

    class Ctx:
        def __init__(self, *a):
            pass

        def classify(self, crit):
            return SimpleNamespace(cls="unclassified", delegation_class=judge_cli.REVIEWER_JUDGES,
                                   reason="")
    monkeypatch.setattr(vl, "_Ctx", Ctx)
    judged, _ = judge_cli._partition({"text": text, "path": tmp_path / "t.md"}, tmp_path, "T-9")
    assert [(c["render"], c["page"]) for c in judged] == [(False, True), (False, False)]


def _judge_excludes(monkeypatch, tmp_path, crit) -> set:
    seen = {}

    def plan(root, rung, kinds, kv=None, exclude_kinds=frozenset()):
        seen["exclude"] = set(exclude_kinds)
        raise RuntimeError("stop after planning")
    monkeypatch.setattr(judge_cli, "_plan_seats", plan)
    monkeypatch.setattr(vl, "kind_vision", lambda root, revision="": {"codex": True, "opencode": False})
    monkeypatch.setattr(vl, "_head_sha", lambda root: "0" * 40)
    monkeypatch.setattr(vl, "task_required_strength", lambda *a, **k: (3, "test"))
    monkeypatch.setattr(judge_cli.review_policy, "ceiling_decision",
                        lambda *a, **k: {"granted": 3, "note": "", "spent": 0, "ceiling": 0})
    monkeypatch.setattr(judge_cli, "_partition", lambda *a, **k: ([crit], []))
    monkeypatch.setattr(judge_cli, "_load_task", lambda *a, **k: {"text": "", "path": tmp_path / "t.md"},
                        raising=False)
    try:
        judge_cli.judge("T-9", tmp_path, dry_run=True, worker_kinds={"codex", "opencode"},
                        kind_vendors={"codex": "openai", "opencode": "zai"}, model_preflight=False)
    except Exception:  # noqa: BLE001 - anything before planning is not under test here
        pass
    assert "exclude" in seen, "judge stopped before seat planning"
    return seen["exclude"]


@pytest.mark.parametrize("page,excluded", [(True, True), (False, False)])
def test_judge_excludes_blind_kinds_for_page_criteria(monkeypatch, tmp_path, page, excluded):
    crit = {"ac_index": 1, "text": "t", "class": "unclassified", "render": False, "page": page,
            "body": "b", "index": 1}
    assert ("opencode" in _judge_excludes(monkeypatch, tmp_path, crit)) is excluded
