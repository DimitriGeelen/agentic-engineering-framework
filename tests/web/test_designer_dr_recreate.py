"""T-2605 AC5: disaster-recovery recreate variant, hermetic (tmp store only).

The identity-preserving recreate (`fw corpus prove`, default leg) deletes
versions and keeps meta.json/uuid. This file pins the OTHER leg: what happens
when a map-scope delete destroys meta.json — /api/save mints a FRESH uuid
(`meta.setdefault("uuid", uuid4())` ignores the XML's workflowMeta uuid), every
referrer pinned to the old uuid goes ghost, and `fw bpmn claim` is the rebind
path. Runs against a tmp store because ghost registration on the live corpus
has side effects (registry writes, ghost surfacing) that pollute real state.
"""

import json

import pytest

import web.blueprints.designer_api as designer_api
from web.designer_registry import ClaimError, claim_ghost, load_registry

from tests.web.test_designer_registry_ghosts import bpmn_with_links


@pytest.fixture()
def client(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    monkeypatch.setattr(designer_api, "_STORE", store)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), store


def _referrer_xml(target_uuid):
    return bpmn_with_links(
        ("n1", "go", f'<aef:link workflowRef="{target_uuid}" name="dr-target"/>'))


def test_dr_map_scope_delete_mints_fresh_uuid_ghosts_referrer_claim_rebinds(client):
    c, store = client

    # Baseline: target minted uuid A; referrer pins A → resolves live, no ghost.
    assert c.post("/api/save", json={
        "id": "dr-target", "bpmn": bpmn_with_links()}).status_code == 200
    uuid_a = json.loads((store / "dr-target" / "meta.json").read_text())["uuid"]
    assert c.post("/api/save", json={
        "id": "dr-referrer", "bpmn": _referrer_xml(uuid_a)}).status_code == 200
    assert load_registry(store)["ghosts"] == []

    # DR event: map-scope delete destroys meta.json (uuid A gone with it).
    r = c.post("/api/delete", json={"id": "dr-target", "scope": "map"})
    assert r.status_code == 200
    assert not (store / "dr-target" / "meta.json").is_file()

    # Recreate under the same id: server mints FRESH uuid B — identity broken.
    assert c.post("/api/save", json={
        "id": "dr-target", "bpmn": bpmn_with_links()}).status_code == 200
    meta_path = store / "dr-target" / "meta.json"
    uuid_b = json.loads(meta_path.read_text())["uuid"]
    assert uuid_b != uuid_a

    # Referrer re-save: its pinned uuid A is now unknown → registered ghost.
    assert c.post("/api/save", json={
        "id": "dr-referrer", "bpmn": _referrer_xml(uuid_a)}).status_code == 200
    ghosts = load_registry(store)["ghosts"]
    assert [g["uuid"] for g in ghosts] == [uuid_a]

    # Gotcha pinned: claim refuses while the recreated map owns different uuid B.
    with pytest.raises(ClaimError, match="already owns uuid"):
        claim_ghost(store, uuid_a, "dr-target")

    # Manual uuid-strip (the documented DR step), then claim rebinds A.
    m = json.loads(meta_path.read_text())
    del m["uuid"]
    meta_path.write_text(json.dumps(m))
    r = claim_ghost(store, uuid_a, "dr-target")
    assert r["uuid"] == uuid_a and r["project"] == "dr-target"
    assert json.loads(meta_path.read_text())["uuid"] == uuid_a

    # Post-claim invariants: ghost gone, claim recorded, referrer resolves live.
    reg = load_registry(store)
    assert reg["ghosts"] == [] and len(reg["claims"]) == 1
    maps = c.get("/api/list").get_json()["maps"]
    assert next(x for x in maps if x["id"] == "dr-target")["uuid"] == uuid_a
