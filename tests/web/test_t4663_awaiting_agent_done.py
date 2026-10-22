"""T-4663 (GitHub #92 follow-up): the "Awaiting review" column also admits partial-complete
tasks (work-completed, still in active/, owner human, every Agent criterion ticked) with no
independent-reviewer verdict, so projects that keep reviews human-only see the tasks waiting
on them. Reviewer-ready admission is unchanged; a task that qualifies both ways is listed
once, as "reviewer: ready". The arc page's overview uses the same predicate.
"""

import re
import subprocess
import sys

import pytest

sys.path.insert(0, ".")

from web import shared  # noqa: E402

# [RUBBER-STAMP] is not reviewer-judged: readiness needs only the Agent boxes.
RUBBER = """- [ ] [RUBBER-STAMP] Run it
  **Steps:**
  1. Run `ls /tmp`
  **Expected:** output contains `tmp`
  **If not:** fix it
"""
# [REVIEW] is reviewer-judged: readiness waits for a green verdict that never comes when
# the project keeps reviews human-only.
REVIEW = """- [ ] [REVIEW] The page reads clearly
  **Steps:**
  1. Open http://localhost:3000/tasks
  **Expected:** the layout reads clean
  **If not:** note what is off
"""

# id: (status, owner, agent box, human block) -> expected reason
CASES = {
    "T-9301": ("started-work", "agent", "x", RUBBER),     # reviewer-ready only
    "T-9302": ("work-completed", "human", "x", REVIEW),   # partial-complete only
    "T-9303": ("work-completed", "human", "x", RUBBER),   # both
    "T-9304": ("started-work", "agent", " ", REVIEW),     # neither
    "T-9305": ("work-completed", "human", " ", REVIEW),   # agent box open: not done
}
EXPECTED = {"T-9301": "reviewer: ready", "T-9302": "agent done", "T-9303": "reviewer: ready",
            "T-9304": None, "T-9305": None}


def _task(tid, status, owner, box, human):
    return f"""---
id: {tid}
name: "fixture {tid}"
status: {status}
workflow_type: build
owner: {owner}
horizon: now
last_update: 2026-10-11T10:00:00Z
---

## Acceptance Criteria

### Agent
- [{box}] agent work
### Human
{human}
## Verification
true
"""


@pytest.fixture
def board(tmp_path, monkeypatch):
    act = tmp_path / ".tasks" / "active"
    act.mkdir(parents=True)
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "-c", "user.name=t", "-c", "user.email=t@t",
                    "commit", "-q", "--allow-empty", "-m", "init"], check=True)
    monkeypatch.setattr(shared, "PROJECT_ROOT", tmp_path)
    shared._READINESS_CACHE.clear()
    shared._LEDGER_CACHE.clear()
    metas = []
    for tid, (status, owner, box, human) in CASES.items():
        p = act / f"{tid}-fixture.md"
        p.write_text(_task(tid, status, owner, box, human))
        metas.append({"id": tid, "name": f"fixture {tid}", "status": status,
                      "workflow_type": "build", "horizon": "now", "owner": owner,
                      "last_update": "2026-10-11T10:00:00Z", "_location": "active",
                      "_path": str(p), "tags": []})
    from web.blueprints import tasks as tb
    monkeypatch.setattr(tb, "get_all_task_metadata", lambda: metas)
    monkeypatch.setattr(tb, "get_episodic_tags", lambda: {})
    from web.app import app
    return app.test_client(), metas


def _column(html, key):
    m = re.search(r'<div class="kanban-column" data-(?:status|column)="%s">(.*?)(?=<div class="kanban-column"|<!-- Inline editing)' % key,
                  html, re.S)
    assert m, f"column {key} not rendered"
    return m.group(1)


def _card(col, tid):
    m = re.search(r'<article class="kanban-card"[^>]*data-task-id="%s">(.*?)</article>' % tid, col, re.S)
    return m.group(1) if m else None


def test_predicate_reasons(board):
    _, metas = board
    got = {m["id"]: shared.board_awaiting_reason(m) for m in metas}
    assert got == EXPECTED


def test_completed_or_agent_owned_work_completed_is_not_agent_done(board):
    _, metas = board
    m = dict(next(x for x in metas if x["id"] == "T-9302"))
    assert shared.board_awaiting_reason(dict(m, _location="completed")) is None
    assert shared.board_awaiting_reason(dict(m, owner="agent")) is None


def test_column_admits_both_kinds_once_with_reason(board):
    client, _ = board
    html = client.get("/tasks?view=board").get_data(as_text=True)
    awaiting = _column(html, "awaiting-review")
    for tid, reason in EXPECTED.items():
        card = _card(awaiting, tid)
        if reason:
            assert card is not None, f"{tid} missing from Awaiting review"
            assert f'<span class="kanban-await-reason">{reason}</span>' in card
            # listed once on the whole board
            assert html.count(f'data-task-id="{tid}"') == 1
        else:
            assert card is None, f"{tid} must not be in Awaiting review"
    assert re.search(r'Awaiting review <span class="count">\(3\)', html)


def test_arc_overview_uses_same_predicate(board):
    _, metas = board
    from web.blueprints import arcs
    constituents = [dict(m, completed=False, missing=False) for m in metas]
    ov = arcs._task_overview(constituents)
    assert sorted(c["id"] for c in ov["awaiting_review"]) == ["T-9301", "T-9302", "T-9303"]
    assert sorted(c["id"] for c in ov["open_tasks"]) == ["T-9304", "T-9305"]
