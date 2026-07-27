"""T-2630: /designer/overlay wrapper page + landing overlay-link contract."""

import json

import pytest

import web.blueprints.designer as designer
import web.blueprints.designer_api as designer_api


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


def _seed_map(store, map_id):
    proj = store / map_id
    proj.mkdir(parents=True)
    (proj / "meta.json").write_text(json.dumps({
        "id": map_id, "title": map_id, "latest": 1,
        "versions": [{"v": 1, "ts": 1785000000}], "updated": 1785000000,
    }))
    (proj / "v1.bpmn").write_text(BPMN)


@pytest.fixture()
def client(monkeypatch, tmp_path):
    store = tmp_path / ".context/designer/projects"
    _seed_map(store, "aef-task-lifecycle")   # profiled map
    _seed_map(store, "aef-dispatch-loop")    # unprofiled map
    (tmp_path / ".tasks/active").mkdir(parents=True)
    (tmp_path / ".tasks/completed").mkdir(parents=True)
    monkeypatch.setattr(designer, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(designer_api, "_STORE", store)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client()


def test_wrapper_iframes_editor_and_wires_the_forward_loop(client):
    resp = client.get("/designer/overlay?id=aef-task-lifecycle")
    assert resp.status_code == 200
    body = resp.get_data(as_text=True)
    # editor at server-latest via the app route (nonce flow is its job)
    assert '/designer/app?load=%2Fapi%2Fversion%3Fid%3Daef-task-lifecycle' in body
    # listener guards + verbatim forward, per the ratified 216 contract
    assert '"aef:ready"' in body
    assert "ev.origin !== window.location.origin" in body
    assert "ev.source !== frame.contentWindow" in body
    assert "/api/overlay?id=" in body
    assert "postMessage(payload" in body


def test_wrapper_unknown_and_traversal_ids_404(client):
    assert client.get("/designer/overlay?id=no-such-map").status_code == 404
    assert client.get("/designer/overlay?id=../../etc").status_code == 404


def test_landing_links_overlay_only_for_profiled_maps(client):
    body = client.get("/designer").get_data(as_text=True)
    assert "/designer/overlay?id=aef-task-lifecycle" in body
    assert "/designer/overlay?id=aef-dispatch-loop" not in body
