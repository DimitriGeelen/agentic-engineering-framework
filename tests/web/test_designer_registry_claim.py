"""T-2575 (T-2571 S6): claim — bind a ghost uuid to a live project.

Single-uuid-namespace invariant (rail offsets 110/111): a claim binds the uuid
every referring connector already pins — never re-mints, never rebinds a
project that owns a different uuid.
"""

import json

import pytest
import yaml

import web.blueprints.designer_api as designer_api
from web.designer_registry import ClaimError, claim_ghost, load_registry

from tests.web.test_designer_registry_ghosts import PLAIN, bpmn_with_links


@pytest.fixture()
def client(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    monkeypatch.setattr(designer_api, "_STORE", store)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), store


GHOST_UUID = "33333333-3333-4333-8333-333333333333"


def _seed_ghost(c):
    r = c.post("/api/save", json={
        "id": "referrer",
        "bpmn": bpmn_with_links(("n1", "go", f'<aef:link workflowRef="{GHOST_UUID}" name="future-flow"/>')),
    })
    assert r.status_code == 200


def test_claim_binds_uuid_removes_ghost_appends_audit(client):
    c, store = client
    _seed_ghost(c)
    c.post("/api/save", json={"id": "future-flow", "bpmn": PLAIN})
    # simulate a pre-uuid project so the claim binds rather than conflicts
    mp = store / "future-flow" / "meta.json"
    m = json.loads(mp.read_text())
    del m["uuid"]
    mp.write_text(json.dumps(m))

    r = claim_ghost(store, GHOST_UUID, "future-flow")
    assert r == {"uuid": GHOST_UUID, "project": "future-flow", "resolved_referrers": 1}
    assert json.loads(mp.read_text())["uuid"] == GHOST_UUID
    reg = load_registry(store)
    assert reg["ghosts"] == []
    assert len(reg["claims"]) == 1
    claim = reg["claims"][0]
    assert claim["uuid"] == GHOST_UUID and claim["project"] == "future-flow"
    assert claim["via"] == "cli"
    # maps[].uuid now reports the claimed identity
    maps = c.get("/api/list").get_json()["maps"]
    assert next(m for m in maps if m["id"] == "future-flow")["uuid"] == GHOST_UUID


def test_claim_refuses_unknown_uuid(client):
    _, store = client
    with pytest.raises(ClaimError, match="unknown ghost uuid"):
        claim_ghost(store, GHOST_UUID, "anything")


def test_claim_refuses_unknown_project(client):
    c, store = client
    _seed_ghost(c)
    with pytest.raises(ClaimError, match="not found in store"):
        claim_ghost(store, GHOST_UUID, "no-such-project")


def test_claim_refuses_uuid_conflict(client):
    c, store = client
    _seed_ghost(c)
    c.post("/api/save", json={"id": "owns-own-uuid", "bpmn": PLAIN})  # minted its own uuid
    with pytest.raises(ClaimError, match="already owns uuid"):
        claim_ghost(store, GHOST_UUID, "owns-own-uuid")
    # nothing mutated
    reg = load_registry(store)
    assert len(reg["ghosts"]) == 1 and reg["claims"] == []
