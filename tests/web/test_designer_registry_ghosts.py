"""T-2574 (T-2571 S2): pending-ref registry — ghost capture at save.

Contract v0 (rail offsets 108/109): unresolved off-page ``aef:link`` refs become
uuid-keyed ghost entries in the store registry, exposed via ``/api/list``
``ghosts[]`` (partitioned — never inside maps[]).
"""

import json
import uuid as uuid_mod

import pytest

import web.blueprints.designer_api as designer_api
from web.designer_registry import load_registry, registry_path

AEF = "http://anchorpoint.framework/aef/extensions"


def bpmn_with_links(*links):
    nodes = "".join(
        f'<bpmn:intermediateThrowEvent id="{nid}" name="{nname}">'
        f"<bpmn:extensionElements>{link}</bpmn:extensionElements>"
        f"</bpmn:intermediateThrowEvent>"
        for nid, nname, link in links
    )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
        f'xmlns:aef="{AEF}" id="D_t2574">'
        f'<bpmn:process id="P1">{nodes}</bpmn:process></bpmn:definitions>'
    )


PLAIN = bpmn_with_links()


@pytest.fixture()
def client(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    monkeypatch.setattr(designer_api, "_STORE", store)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), store


def _save(c, i, bpmn):
    r = c.post("/api/save", json={"id": i, "bpmn": bpmn})
    assert r.status_code == 200, r.get_json()
    return r


def test_unresolved_workflowref_becomes_ghost(client):
    c, store = client
    _save(c, "referrer", bpmn_with_links(
        ("n1", "escalate", '<aef:link workflowRef="11111111-1111-4111-8111-111111111111" name="escalation handling"/>')
    ))
    ghosts = load_registry(store)["ghosts"]
    assert len(ghosts) == 1
    g = ghosts[0]
    assert g["uuid"] == "11111111-1111-4111-8111-111111111111"
    assert g["name"] == "escalation handling"
    assert g["referenced_by"] == [{"id": "referrer", "node": "n1", "nodeName": "escalate"}]
    assert g["task"] is None


def test_resolved_uuid_ref_leaves_no_ghost(client):
    c, store = client
    _save(c, "target", PLAIN)
    target_uuid = json.loads((store / "target" / "meta.json").read_text())["uuid"]
    _save(c, "referrer", bpmn_with_links(
        ("n1", "go", f'<aef:link workflowRef="{target_uuid}" name="target"/>')
    ))
    assert load_registry(store)["ghosts"] == []


def test_legacy_slug_resolves_by_name_no_ghost(client):
    c, store = client
    _save(c, "escalation", PLAIN)
    _save(c, "referrer", bpmn_with_links(
        ("n1", "go", '<aef:link targetWorkflow="escalation"/>')
    ))
    assert load_registry(store)["ghosts"] == []


def test_nameonly_ghosts_dedupe_across_referrers(client):
    c, store = client
    _save(c, "ref-a", bpmn_with_links(("na", "A", '<aef:link targetWorkflow="missing-flow"/>')))
    _save(c, "ref-b", bpmn_with_links(("nb", "B", '<aef:link targetWorkflow="missing-flow"/>')))
    ghosts = load_registry(store)["ghosts"]
    assert len(ghosts) == 1
    assert uuid_mod.UUID(ghosts[0]["uuid"]).version == 4  # store-minted
    assert {r["id"] for r in ghosts[0]["referenced_by"]} == {"ref-a", "ref-b"}


def test_rescan_removes_stale_refs_and_empty_ghosts(client):
    c, store = client
    _save(c, "referrer", bpmn_with_links(("n1", "go", '<aef:link targetWorkflow="missing-flow"/>')))
    assert len(load_registry(store)["ghosts"]) == 1
    _save(c, "referrer", PLAIN)  # connector deleted
    assert load_registry(store)["ghosts"] == []


def test_ghost_with_task_survives_empty_referrers(client):
    c, store = client
    _save(c, "referrer", bpmn_with_links(("n1", "go", '<aef:link targetWorkflow="missing-flow"/>')))
    reg = load_registry(store)
    reg["ghosts"][0]["task"] = "T-9999"
    registry_path(store).write_text(__import__("yaml").safe_dump(reg))
    _save(c, "referrer", PLAIN)
    ghosts = load_registry(store)["ghosts"]
    assert len(ghosts) == 1 and ghosts[0]["task"] == "T-9999"
    assert ghosts[0]["referenced_by"] == []


def test_delete_map_strips_its_ghost_refs(client):
    c, store = client
    _save(c, "referrer", bpmn_with_links(("n1", "go", '<aef:link targetWorkflow="missing-flow"/>')))
    assert len(load_registry(store)["ghosts"]) == 1
    r = c.post("/api/delete", json={"id": "referrer", "scope": "map"})
    assert r.status_code == 200
    assert load_registry(store)["ghosts"] == []


def test_api_list_emits_ghosts_partitioned(client):
    c, store = client
    _save(c, "referrer", bpmn_with_links(
        ("n1", "escalate", '<aef:link workflowRef="22222222-2222-4222-8222-222222222222" name="ghosty"/>')
    ))
    body = c.get("/api/list").get_json()
    assert [m["id"] for m in body["maps"]] == ["referrer"]  # ghost NOT in maps[]
    assert len(body["ghosts"]) == 1
    g = body["ghosts"][0]
    assert set(g) == {"uuid", "name", "referenced_by", "task", "first_seen"}
    assert g["referenced_by"][0] == {"id": "referrer", "node": "n1", "nodeName": "escalate"}
