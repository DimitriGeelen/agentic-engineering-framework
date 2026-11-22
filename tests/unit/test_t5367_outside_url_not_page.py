"""T-5367: a criterion "names a page" only for a route of THIS project's Watchtower. Before, any
`https?://host/path` counted, so T-5301's read review (citing a GitHub PR link) planned a capture
of GitHub, the seats could not see it and the ledger refused every green ("no required page was
recorded"). One origin test in lib/evidence_need.py serves names_page, the judge's capture paths
(`_criterion_pages`) and the ledger (`_needs_view`).

Hermetic: a tmp project root with its own watchtower.url; capturer and visual gatherer are fakes."""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE.parent.parent))

from lib import evidence_need  # noqa: E402
from lib import verdict_ledger as vl  # noqa: E402
from lib.reviewer import judge_cli  # noqa: E402
from lib.delegation import human_criteria  # noqa: E402

WT = "http://192.0.2.7:3000"
PR = "https://github.com/DimitriGeelen/agentic-engineering-framework/pull/116"

# T-5301's Human criterion 1, shape preserved: an outside PR link plus local evidence files.
T5301_AC = f"""- [ ] [REVIEW] Outside PR #116 is fit to merge into bleeding-edge
  **Steps:**
  1. Read the PR's description `.context/working/judge-evidence/T-5301/pr116-description.md` and its full diff `.context/working/judge-evidence/T-5301/pr116.diff` (PR {PR}, head 0cc9951d8).
  2. Check the diff changes only `bin/fw` and `.agentic-framework/bin/fw`, and adds `tests/unit/issue68_doctor_watchtower_remedy.bats`.
  3. Read the test-host result `.context/working/judge-evidence/T-5301/pr116-testhost.log`.
  **Expected:** The change does exactly what #68 needs and nothing else.
  **If not:** Name each problem.
"""

# T-5350's shape: Watchtower URLs on this project's host.
T5350_BODY = f"Open {WT}/designer and {WT}/designer/app and check the canvas loads."


def _root(tmp_path: Path) -> Path:
    (tmp_path / ".context/working").mkdir(parents=True)
    (tmp_path / ".context/working/watchtower.url").write_text(WT + "\n")
    return tmp_path


def _origin(tmp_path):
    return evidence_need.own_origin(_root(tmp_path))


# ── the five cases of the task's second criterion ───────────────────────────────────────────

def test_1_github_pr_url_is_not_a_page(tmp_path):
    origin = _origin(tmp_path)
    assert not evidence_need.names_page(f"See {PR} for the change.", origin)
    assert not evidence_need.names_page(f"See {PR} for the change.")          # no origin either
    assert judge_cli._criterion_pages(tmp_path, f"See {PR}.") == []


def test_2_project_watchtower_url_with_path_is_a_page(tmp_path):
    origin = _origin(tmp_path)
    assert origin == ("192.0.2.7:3000", "3000")
    assert evidence_need.names_page(f"Open {WT}/config and check it.", origin)
    # the same host on another port is not this project's Watchtower
    assert not evidence_need.names_page("Open http://192.0.2.7:3999/config.", origin)


def test_3_localhost_url_is_a_page(tmp_path):
    origin = _origin(tmp_path)
    assert evidence_need.names_page("Open http://localhost:3000/x and look.", origin)
    assert evidence_need.names_page("Open http://127.0.0.1:3000/x and look.", origin)
    assert evidence_need.names_page("Open http://localhost:3000/x and look.")


def test_4_bare_route_is_a_page(tmp_path):
    assert evidence_need.names_page("The designer loads at /designer and works.", _origin(tmp_path))
    assert evidence_need.names_page("The designer loads at /designer and works.")


def test_5_outside_url_plus_evidence_paths_needs_no_screenshots(tmp_path, monkeypatch):
    root = _root(tmp_path)
    crit = human_criteria("## Acceptance Criteria\n\n### Human\n" + T5301_AC)[0]
    body = vl.criterion_body(crit)
    origin = evidence_need.own_origin(root)
    assert not evidence_need.names_page(f"{crit.title}\n{body}", origin)
    assert not evidence_need.needs_view(False, crit.title, body, origin)
    # the ledger asks the same question through its ctx's root
    monkeypatch.setattr(vl, "_is_render_review", lambda ctx, c: False)

    class Ctx:
        def __init__(self, r):
            self.root = r
    assert vl._needs_view(Ctx(root), crit) is False  # type: ignore[arg-type]
    # and the judge plans no capture for it
    monkeypatch.setattr(judge_cli, "_changed_web_files", lambda *a, **k: [])
    c = {"index": 1, "ac_index": 1, "text": crit.title, "body": body, "class": "unclassified",
         "render": False, "page": False, "image": False}
    assert not judge_cli.needs_screenshots(c)
    assert judge_cli._pages_for(root, "T-9", "", [c]) == []


# ── a Watchtower-URL criterion still plans both pages ──────────────────────────────────────

def test_t5350_shaped_criterion_still_plans_both_pages(tmp_path, monkeypatch):
    root = _root(tmp_path)
    origin = evidence_need.own_origin(root)
    assert evidence_need.names_page(T5350_BODY, origin)
    assert evidence_need.needs_view(False, "Designer re-pin", T5350_BODY, origin)
    monkeypatch.setattr(judge_cli, "_changed_web_files", lambda *a, **k: [])
    monkeypatch.setattr(judge_cli, "_gather_visual", lambda *a, **k: {"widths": [], "problems": [],
                                                                       "shots": []})
    monkeypatch.setattr(judge_cli, "_bare_get_refusals", lambda *a, **k: {})
    c = {"index": 1, "ac_index": 1, "text": T5350_BODY, "body": T5350_BODY,
         "class": "unclassified", "render": False, "page": True, "image": True}

    def never(*a, **k):
        raise AssertionError("dry run must not capture")
    ev = judge_cli._gather_evidence(root, "T-9", {"text": ""}, [c], never, dry_run=True)
    assert ev["needed"] and ev["pages"] == ["/designer", "/designer/app"]


def test_one_origin_test_for_names_page_and_capture_paths(tmp_path):
    # an outside URL is neither a page to names_page nor a capture path to the judge
    root = _root(tmp_path)
    body = f"See {PR} and open {WT}/cron."
    assert judge_cli._criterion_pages(root, body) == ["/cron"]
    assert evidence_need.names_page(body, evidence_need.own_origin(root))
    assert judge_cli.names_page is evidence_need.names_page
    assert judge_cli._LOCAL_HOSTS is evidence_need.LOCAL_HOSTS
