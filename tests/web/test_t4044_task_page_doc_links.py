"""T-4044 (GitHub #91): document paths written in a task's description, `## Context`
or an `### Agent` criterion link to /file/ on /tasks/<id>, under the same
existence gate `_auto_link_files` applies to Human criteria.

Fixtures only: PROJECT_ROOT is pointed at a tmp dir holding one fixture task.
"""

import re

import pytest

FIXTURE = """---
id: T-9044
name: fixture
description: "See docs/reports/desc-note.md for the background"
status: started-work
workflow_type: build
owner: agent
---

# T-9044: fixture

## Context

Read docs/reports/ctx-note.md first. Missing one: docs/reports/missing-thing.md.
Hostile text: <script>alert('x')</script>

## Acceptance Criteria

### Agent
- [ ] Summarise docs/reports/agent-note.md in the RCA
- [ ] Check docs/reports/missing-thing.md is absent

### Human
- [ ] [REVIEW] Open the human note
  **Steps:**
  1. Open docs/reports/human-note.md
  **Expected:** it opens
  **If not:** screenshot it

## Verification
python3 -c "print(1)"
"""


@pytest.fixture()
def client(tmp_path, monkeypatch):
    import web.blueprints.tasks as tb
    import web.shared as shared
    from web.app import app

    for name in ("desc-note", "ctx-note", "agent-note", "human-note"):
        (tmp_path / "docs" / "reports").mkdir(parents=True, exist_ok=True)
        (tmp_path / "docs" / "reports" / f"{name}.md").write_text(f"# {name}\n\nbody\n")
    active = tmp_path / ".tasks" / "active"
    active.mkdir(parents=True)
    (tmp_path / ".tasks" / "completed").mkdir()
    (active / "T-9044-fixture.md").write_text(FIXTURE)
    monkeypatch.setattr(tb, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(shared, "PROJECT_ROOT", tmp_path)

    app.config["TESTING"] = True
    return app.test_client()


def _page(client):
    resp = client.get("/tasks/T-9044")
    assert resp.status_code == 200
    return resp.get_data(as_text=True)


def _link_count(html, path):
    return len(re.findall(rf'href="/file/{re.escape(path)}"', html))


def test_context_path_links_to_existing_file(client):
    assert _link_count(_page(client), "docs/reports/ctx-note.md") >= 1


def test_agent_criterion_path_links_to_existing_file(client):
    assert _link_count(_page(client), "docs/reports/agent-note.md") >= 1


def test_description_path_links_to_existing_file(client):
    assert _link_count(_page(client), "docs/reports/desc-note.md") >= 1


def test_missing_path_does_not_link(client):
    assert _link_count(_page(client), "docs/reports/missing-thing.md") == 0


def test_human_criterion_path_still_links(client):
    assert _link_count(_page(client), "docs/reports/human-note.md") >= 1


def test_script_in_context_stays_escaped(client):
    html = _page(client)
    assert "<script>alert('x')</script>" not in html
    assert "&lt;script&gt;" in html
