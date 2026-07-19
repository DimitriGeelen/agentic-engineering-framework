"""T-2564: /api/save well-formedness gate.

Origin: D4 v1 (T-2563) — a malformed payload (raw `<dispatch_id>` inside an
attribute) was ACCEPTED by the store and only `fw bpmn compile` caught it
downstream. The gate rejects malformed XML with HTTP 400 + a line/column-bearing
message and writes NOTHING; well-formed saves keep today's exact behavior
(version increment, meta.json update, atomic replace).
"""

import json

import pytest

import web.blueprints.designer_api as designer_api

WELL_FORMED = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'id="Definitions_t2564"><bpmn:process id="P1"/></bpmn:definitions>\n'
)
# The exact D4-class defect: a raw angle-bracket token inside an attribute value.
MALFORMED = WELL_FORMED.replace('id="P1"', 'id="P1" note="pass <dispatch_id> here"')


@pytest.fixture()
def client(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    monkeypatch.setattr(designer_api, "_STORE", store)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), store


def test_malformed_xml_rejected_400_nothing_written(client):
    c, store = client
    resp = c.post("/api/save", json={"id": "t2564-bad", "bpmn": MALFORMED})
    assert resp.status_code == 400
    body = resp.get_json()
    assert body["ok"] is False
    assert "malformed XML" in body["error"]
    assert "line" in body["error"] and "column" in body["error"]
    # no version, no meta, no directory — the reject leaves zero store residue
    assert not (store / "t2564-bad").exists()


def test_well_formed_save_behavior_unchanged(client):
    c, store = client
    resp = c.post(
        "/api/save", json={"id": "t2564-good", "bpmn": WELL_FORMED, "note": "v1"}
    )
    assert resp.status_code == 200
    assert resp.get_json() == {"ok": True, "v": 1}
    assert (store / "t2564-good" / "v1.bpmn").read_text() == WELL_FORMED
    meta = json.loads((store / "t2564-good" / "meta.json").read_text())
    assert meta["latest"] == 1
    assert meta["versions"][0]["note"] == "v1"
    # second save increments
    resp2 = c.post("/api/save", json={"id": "t2564-good", "bpmn": WELL_FORMED})
    assert resp2.get_json()["v"] == 2
    assert (store / "t2564-good" / "v2.bpmn").is_file()
