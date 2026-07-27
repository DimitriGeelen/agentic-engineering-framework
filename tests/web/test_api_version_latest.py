"""T-2624: /api/version bare-id resolution — `?id=` alone serves the latest version.

Read-value deep links (gate stderr, /review + /inception map links) must not
hardcode a version that goes stale on every save; the server resolves latest,
mirroring the missing-v behavior /api/thumb already had. Explicit-v and
invalid-v behavior is unchanged (832 client contract, T-2530).
"""

import json

import pytest

import web.blueprints.designer_api as designer_api


@pytest.fixture()
def client(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    store.mkdir(parents=True)
    monkeypatch.setattr(designer_api, "_STORE", store)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), store


def _seed(store, pid, latest=3):
    d = store / pid
    d.mkdir()
    versions = [{"v": v, "note": f"v{v}", "ts": 1784600000 + v} for v in range(1, latest + 1)]
    (d / "meta.json").write_text(json.dumps({
        "id": pid, "title": pid, "latest": latest, "versions": versions,
    }))
    for v in range(1, latest + 1):
        (d / f"v{v}.bpmn").write_text(f'<?xml version="1.0"?><bpmn:definitions data-v="{v}"/>')


def test_bare_id_serves_latest_version(client):
    c, store = client
    _seed(store, "aef-task-lifecycle", latest=3)
    resp = c.get("/api/version?id=aef-task-lifecycle")
    assert resp.status_code == 200
    assert resp.mimetype == "text/xml"
    assert 'data-v="3"' in resp.get_data(as_text=True)


def test_explicit_v_unchanged(client):
    c, store = client
    _seed(store, "aef-task-lifecycle", latest=3)
    resp = c.get("/api/version?id=aef-task-lifecycle&v=2")
    assert resp.status_code == 200
    assert 'data-v="2"' in resp.get_data(as_text=True)


def test_invalid_v_still_rejected(client):
    c, store = client
    _seed(store, "aef-task-lifecycle", latest=1)
    resp = c.get("/api/version?id=aef-task-lifecycle&v=abc")
    assert resp.get_json()["ok"] is False


def test_bare_id_on_unknown_map_404s(client):
    c, _store = client
    resp = c.get("/api/version?id=no-such-map")
    assert resp.status_code == 404
