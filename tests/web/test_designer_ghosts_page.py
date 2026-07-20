"""T-2578 (T-2571 S5): /designer/ghosts — AEF-side ghost cards with
bidirectional reference markers (operator round-1 steer)."""

import pytest

import web.blueprints.designer_api as designer_api
from web.designer_registry import save_registry

GHOST_UUID = "66666666-6666-4666-8666-666666666666"


@pytest.fixture()
def client(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    store.mkdir(parents=True)
    monkeypatch.setattr(designer_api, "_STORE", store)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), store


def test_ghost_card_renders_all_elements(client):
    c, store = client
    save_registry(store, {
        "ghosts": [{
            "uuid": GHOST_UUID,
            "name": "escalation handling",
            "referenced_by": [
                {"id": "aef-dispatch-loop", "node": "n1", "nodeName": "escalate"},
                {"id": "aef-task-lifecycle", "node": "n7", "nodeName": "hand off"},
            ],
            "task": "T-9001",
            "first_seen": 1784580000,
        }],
        "claims": [],
    })
    r = c.get("/designer/ghosts")
    assert r.status_code == 200
    html = r.get_data(as_text=True)
    assert "escalation handling" in html
    assert "ghost — needs mapping" in html
    assert GHOST_UUID[:8] in html
    # both referrers with their connector nodes
    assert "aef-dispatch-loop" in html and "n1" in html and "escalate" in html
    assert "aef-task-lifecycle" in html and "n7" in html
    # documentation-task chip links into the task page
    assert '/tasks/T-9001' in html
    # claim affordance carries the full uuid
    assert f"fw bpmn claim {GHOST_UUID}" in html
    # reverse direction: per-referrer unmapped counts
    assert "1 unmapped reference" in html


def test_empty_state(client):
    c, _ = client
    r = c.get("/designer/ghosts")
    assert r.status_code == 200
    html = r.get_data(as_text=True)
    assert "No pending references" in html
    assert '<article class="ghost-card"' not in html


def test_missing_task_chip_marks_unminted(client):
    c, store = client
    save_registry(store, {
        "ghosts": [{
            "uuid": GHOST_UUID,
            "name": "x",
            "referenced_by": [{"id": "p1", "node": "n1", "nodeName": ""}],
            "task": None,
            "first_seen": 0,
        }],
        "claims": [],
    })
    html = c.get("/designer/ghosts").get_data(as_text=True)
    assert "no documentation task yet" in html


def test_claims_history_renders(client):
    c, store = client
    save_registry(store, {
        "ghosts": [],
        "claims": [{"uuid": GHOST_UUID, "project": "escalation", "ts": 1784580000, "via": "cli"}],
    })
    html = c.get("/designer/ghosts").get_data(as_text=True)
    assert "Recent claims" in html and "escalation" in html
