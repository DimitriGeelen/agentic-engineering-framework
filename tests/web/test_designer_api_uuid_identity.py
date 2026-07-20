"""T-2573 (T-2571 S1): immutable workflow uuid in the designer store.

Contract v0 (rail offsets 108/109): every workflow carries an immutable uuid in
meta.json — the identity that off-page ``workflowRef`` connectors pin. Minted at
project creation (or lazily on the first save of a pre-uuid legacy meta), never
rewritten, and exposed additively in ``/api/list`` map entries.
"""

import json
import uuid as uuid_mod

import pytest

import web.blueprints.designer_api as designer_api

BPMN = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'id="Definitions_t2573"><bpmn:process id="P1"/></bpmn:definitions>\n'
)


@pytest.fixture()
def client(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    monkeypatch.setattr(designer_api, "_STORE", store)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), store


def _meta(store, i):
    return json.loads((store / i / "meta.json").read_text())


def test_new_project_mints_valid_uuid4(client):
    c, store = client
    assert c.post("/api/save", json={"id": "t2573-new", "bpmn": BPMN}).status_code == 200
    u = _meta(store, "t2573-new")["uuid"]
    assert uuid_mod.UUID(u).version == 4


def test_uuid_immutable_across_saves(client):
    c, store = client
    c.post("/api/save", json={"id": "t2573-imm", "bpmn": BPMN})
    u1 = _meta(store, "t2573-imm")["uuid"]
    c.post("/api/save", json={"id": "t2573-imm", "bpmn": BPMN, "note": "v2"})
    m = _meta(store, "t2573-imm")
    assert m["uuid"] == u1
    assert m["latest"] == 2


def test_legacy_meta_lazily_backfilled_on_save(client):
    c, store = client
    # a pre-T-2573 project: meta without uuid
    c.post("/api/save", json={"id": "t2573-legacy", "bpmn": BPMN})
    mp = store / "t2573-legacy" / "meta.json"
    m = json.loads(mp.read_text())
    del m["uuid"]
    mp.write_text(json.dumps(m))
    c.post("/api/save", json={"id": "t2573-legacy", "bpmn": BPMN})
    assert uuid_mod.UUID(_meta(store, "t2573-legacy")["uuid"]).version == 4


def test_api_list_exposes_uuid_additively(client):
    c, store = client
    c.post("/api/save", json={"id": "t2573-list", "bpmn": BPMN})
    maps = c.get("/api/list").get_json()["maps"]
    entry = next(m for m in maps if m["id"] == "t2573-list")
    assert entry["uuid"] == _meta(store, "t2573-list")["uuid"]
    # authoritative shape untouched (T-2523/T-2530): same keys plus uuid, no extras
    assert set(entry) == {"id", "title", "uuid", "sources", "latest", "openTarget"}
    assert set(entry["latest"]) == {"v", "ts", "count"}
