"""T-4046 (GitHub #93): /inception/<id> renders criteria as tickable, not dead text.

Flask test client against a fixture inception with an unticked `### Human`
criterion. The page must carry a checkbox form posting to the task page's
/api/task/<id>/toggle-ac endpoint, link to /tasks/<id>, and that endpoint must
tick the box in the task file.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

TASK = """---
id: T-9946
name: "Inception with a Human criterion"
description: >
  Fixture for T-4046.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-10-11T00:00:00Z
last_update: 2026-10-11T00:00:00Z
date_finished: null
---

# T-9946: fixture

## Problem Statement

Fixture.

## Acceptance Criteria

### Agent
- [ ] Agent criterion one

### Human
- [ ] [REVIEW] Operator confirms the page reads cleanly
  **Steps:**
  1. Open the page
  **Expected:** it reads cleanly
  **If not:** screenshot it

## Recommendation

**Recommendation:** GO
**Rationale:** fixture rationale that is long enough to count as substantive.

## Decision

**Decision**: GO

**Rationale**: fixture

**Date**: 2026-10-11T00:00:00Z

## Updates
"""


@pytest.fixture
def project(tmp_path, monkeypatch):
    for d in (".tasks/active", ".tasks/completed", ".context/working", "docs/reports"):
        (tmp_path / d).mkdir(parents=True)
    (tmp_path / ".tasks/active/T-9946-fixture.md").write_text(TASK)
    import web.shared
    import web.blueprints.inception
    import web.blueprints.tasks
    monkeypatch.setattr(web.shared, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(web.blueprints.inception, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(web.blueprints.tasks, "PROJECT_ROOT", tmp_path)
    monkeypatch.setenv("PROJECT_ROOT", str(tmp_path))
    return tmp_path


def _client():
    from web.app import app
    app.config["TESTING"] = True
    client = app.test_client()
    client.get("/health")
    with client.session_transaction() as sess:
        sess.setdefault("_csrf_token", "test-csrf-token")
        token = sess["_csrf_token"]
    return client, token


def test_inception_page_has_tickable_human_criterion(project):
    client, csrf = _client()
    resp = client.get("/inception/T-9946")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)

    # A form posting to the shared endpoint, carrying a checkbox, for the Human line.
    forms = re.findall(
        r'<form[^>]*hx-post="/api/task/T-9946/toggle-ac"[^>]*>(.*?)</form>', html, re.S
    )
    assert len(forms) >= 2, "expected a toggle form for the agent and the human criterion"
    assert any('type="checkbox"' in f for f in forms)
    assert 'href="/tasks/T-9946"' in html
    # Steps/Expected/If-not stay readable
    assert "Open the page" in html and "it reads cleanly" in html and "screenshot it" in html
    # one-step-left card names the open Human criterion
    assert "Operator confirms the page reads cleanly" in html.split("one step left")[1]


def test_toggle_through_existing_endpoint_ticks_the_box(project):
    client, csrf = _client()
    html = client.get("/inception/T-9946").get_data(as_text=True)
    human_form = next(
        f for f in re.findall(r'<form[^>]*toggle-ac[^>]*>(.*?)</form>', html, re.S)
        if "line" in f
        and "Operator" in html.split(f)[1][:600]
    )
    line = re.search(r'name="line" value="(\d+)"', human_form).group(1)
    resp = client.post(
        "/api/task/T-9946/toggle-ac", data={"line": line, "_csrf_token": csrf}
    )
    assert resp.status_code == 200
    text = (project / ".tasks/active/T-9946-fixture.md").read_text()
    assert "- [x] [REVIEW] Operator confirms the page reads cleanly" in text
    assert "- [ ] Agent criterion one" in text
