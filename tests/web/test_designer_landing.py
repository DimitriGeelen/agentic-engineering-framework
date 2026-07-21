"""T-2589: /designer corpus landing page — server truth first, editor at /designer/app.

Origin: operator recurrence #2 of "off-page connectors not working" — the 0.3.0
bundle's B1 autosave restored a stale local draft on /designer open, shadowing the
server's latest saved corpus content. The landing page makes the entry point show
server truth; cards deep-link /designer/app?load=<version src> which defeats the
autosave restore (differing src → deep-link wins, bundle B1 contract).
"""

import json

import pytest

import web.blueprints.designer_api as designer_api

BPMN = "<?xml version=\"1.0\"?><bpmn:definitions/>"


@pytest.fixture()
def client(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    store.mkdir(parents=True)
    monkeypatch.setattr(designer_api, "_STORE", store)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), store


def _seed_project(store, pid, title, latest=2):
    d = store / pid
    d.mkdir()
    versions = [{"v": v, "note": f"v{v}", "ts": 1784600000 + v} for v in range(1, latest + 1)]
    (d / "meta.json").write_text(json.dumps({
        "id": pid, "title": title, "latest": latest, "versions": versions,
    }))
    for v in range(1, latest + 1):
        (d / f"v{v}.bpmn").write_text(BPMN)


def test_landing_lists_projects_with_deep_links(client):
    c, store = client
    _seed_project(store, "aef-task-lifecycle", "AEF task lifecycle", latest=2)
    _seed_project(store, "aef-dispatch-loop", "AEF dispatch loop", latest=1)

    resp = c.get("/designer")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)
    assert "Workflow Designer — Corpus" in html
    assert "aef-task-lifecycle" in html and "AEF task lifecycle" in html
    assert "aef-dispatch-loop" in html
    # Deep-link must target /designer/app with an URL-encoded /api/version src
    # pinned to the latest version — this is what defeats the autosave shadow.
    assert "/designer/app?load=%2Fapi%2Fversion%3Fid%3Daef-task-lifecycle%26v%3D2" in html
    assert "/designer/app?load=%2Fapi%2Fversion%3Fid%3Daef-dispatch-loop%26v%3D1" in html


def test_landing_falls_back_to_bundle_when_store_empty(client):
    c, store = client
    resp = c.get("/designer")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)
    # Fresh install: nothing to land on — serve the editor (or the not-yet-synced
    # placeholder when the vendored bundle is absent), never an empty landing page.
    assert "Workflow Designer — Corpus" not in html


def test_designer_app_serves_bundle(client):
    c, store = client
    _seed_project(store, "aef-task-lifecycle", "AEF task lifecycle")

    landing = c.get("/designer").get_data(as_text=True)
    app_page = c.get("/designer/app")
    assert app_page.status_code == 200
    app_html = app_page.get_data(as_text=True)
    # The editor route serves the vendored single-file build (self-contained,
    # carries the autosave key marker), NOT the landing template.
    assert "aefAutosaveDoc" in app_html
    assert "Workflow Designer — Corpus" not in app_html
    assert app_html != landing


def test_ghosts_page_unchanged(client):
    c, store = client
    resp = c.get("/designer/ghosts")
    assert resp.status_code == 200
