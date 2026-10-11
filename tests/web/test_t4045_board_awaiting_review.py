"""T-4045 (GitHub #92): the task board has a derived "Awaiting review" column holding
the tasks T-4053's readiness predicate calls `ready`; waiting tasks stay in In Progress
with their open-Human count. No new status is stored.
"""

import re
import subprocess
import sys

import pytest

sys.path.insert(0, ".")

from web import shared  # noqa: E402

HUMAN = """- [ ] [RUBBER-STAMP] Run it
  **Steps:**
  1. Run `ls /tmp`
  **Expected:** output contains `tmp`
  **If not:** fix it
"""


def _task(tid, agent_box):
    return f"""---
id: {tid}
name: "fixture {tid}"
status: started-work
workflow_type: build
owner: agent
horizon: now
last_update: 2026-10-11T10:00:00Z
---

## Acceptance Criteria

### Agent
- [{agent_box}] agent work
### Human
{HUMAN}
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
    for tid, box in (("T-9201", "x"), ("T-9202", " ")):
        p = act / f"{tid}-fixture.md"
        p.write_text(_task(tid, box))
        metas.append({"id": tid, "name": f"fixture {tid}", "status": "started-work",
                      "workflow_type": "build", "horizon": "now", "owner": "agent",
                      "last_update": "2026-10-11T10:00:00Z", "_location": "active",
                      "_path": str(p), "tags": []})
    from web.blueprints import approvals as ap
    from web.blueprints import tasks as tb
    monkeypatch.setattr(tb, "get_all_task_metadata", lambda: metas)
    monkeypatch.setattr(tb, "get_episodic_tags", lambda: {})
    monkeypatch.setattr(ap, "_task_meta", lambda: metas)
    from web.app import app
    return app.test_client(), ap


def _column(html, key):
    m = re.search(r'<div class="kanban-column" data-(?:status|column)="%s">(.*?)(?=<div class="kanban-column"|<!-- Inline editing)' % key,
                  html, re.S)
    assert m, f"column {key} not rendered"
    return m.group(1)


def test_ready_task_sits_in_awaiting_review_only(board):
    client, _ = board
    html = client.get("/tasks?view=board").get_data(as_text=True)
    awaiting = _column(html, "awaiting-review")
    progress = _column(html, "started-work")
    assert "T-9201" in awaiting and "T-9201" not in progress
    assert "T-9202" in progress and "T-9202" not in awaiting


def test_column_sits_between_in_progress_and_issues(board):
    client, _ = board
    html = client.get("/tasks?view=board").get_data(as_text=True)
    i = html.index('<div class="kanban-column" data-status="started-work">')
    a = html.index('<div class="kanban-column" data-column="awaiting-review"')
    s = html.index('<div class="kanban-column" data-status="issues">')
    assert i < a < s


def test_waiting_card_shows_open_human_count(board):
    client, _ = board
    html = client.get("/tasks?view=board").get_data(as_text=True)
    assert "1 Human open" in _column(html, "started-work")
    assert "Human open" not in _column(html, "awaiting-review")


def test_awaiting_count_equals_approvals_ready_count(board):
    client, ap = board
    html = client.get("/tasks?view=board").get_data(as_text=True)
    n = int(re.search(r'Awaiting review <span class="count">\((\d+)\)', html).group(1))
    ready = [t for t in ap._load_pending_human_acs() if t["readiness"] == "ready"]
    assert n == len(ready) == 1


def test_no_new_status_value_is_introduced(board):
    client, _ = board
    html = client.get("/tasks?view=board").get_data(as_text=True)
    assert 'data-status="awaiting-review"' not in html
