"""T-2629: /api/overlay endpoint contract — status codes + payload shape."""

import json

import pytest

import web.blueprints.designer as designer


BPMN = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'xmlns:aef="http://anchorpoint.framework/aef/extensions" id="D" '
    'targetNamespace="https://aef.anchorpoint.dev/workflows">'
    '<bpmn:process id="P" isExecutable="true">'
    '<bpmn:extensionElements><aef:workflowMeta id="m" version="1" '
    'schemaVersion="2" title="t" tier_default="1"/></bpmn:extensionElements>'
    '<bpmn:serviceTask id="n1" name="n1"><bpmn:extensionElements>'
    '<aef:uid value="tl_work"/><aef:meta state="started-work"/>'
    "</bpmn:extensionElements></bpmn:serviceTask>"
    "</bpmn:process></bpmn:definitions>"
)


@pytest.fixture()
def client(monkeypatch, tmp_path):
    proj = tmp_path / ".context/designer/projects/aef-task-lifecycle"
    proj.mkdir(parents=True)
    (proj / "meta.json").write_text('{"latest": 1}')
    (proj / "v1.bpmn").write_text(BPMN)
    active = tmp_path / ".tasks/active"
    active.mkdir(parents=True)
    (tmp_path / ".tasks/completed").mkdir(parents=True)
    (active / "T-1-x.md").write_text(
        "---\nid: T-1\nstatus: started-work\nhorizon: now\n"
        "last_update: '2026-07-26T12:00:00Z'\n---\n# T-1\n"
    )
    monkeypatch.setattr(designer, "PROJECT_ROOT", tmp_path)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client()


def test_overlay_serves_annotate_payload(client):
    resp = client.get("/api/overlay?id=aef-task-lifecycle")
    assert resp.status_code == 200
    assert resp.mimetype == "application/json"
    p = json.loads(resp.get_data(as_text=True))
    assert p["type"] == "aef:annotate"
    assert {n["uid"]: n["badge"] for n in p["nodes"]} == {"tl_work": "1"}


def test_overlay_unknown_map_404s(client):
    assert client.get("/api/overlay?id=no-such-map").status_code == 404


def test_overlay_bad_id_404s(client):
    assert client.get("/api/overlay?id=../../etc").status_code == 404
