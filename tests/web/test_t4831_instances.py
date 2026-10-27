"""T-4831: GET /api/instances — live tasks on the aef-task-lifecycle map."""

import json
import shutil

import pytest

import web.blueprints.designer_api as designer_api

BPMN = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'xmlns:aef="http://anchorpoint.framework/aef/extensions" id="D" '
    'targetNamespace="https://aef.anchorpoint.dev/workflows">'
    '<bpmn:process id="P" isExecutable="true">'
    '<bpmn:extensionElements><aef:workflowMeta id="m" version="1" '
    'schemaVersion="2" title="t" tier_default="1"/></bpmn:extensionElements>'
    "{nodes}</bpmn:process></bpmn:definitions>"
)


def _node(uid):
    return (f'<bpmn:serviceTask id="{uid}" name="{uid}"><bpmn:extensionElements>'
            f'<aef:uid value="{uid}"/></bpmn:extensionElements></bpmn:serviceTask>')


def _seed(store, map_id, uids):
    d = store / map_id
    d.mkdir(parents=True)
    (d / "meta.json").write_text(json.dumps({
        "id": map_id, "title": map_id, "latest": 1,
        "versions": [{"v": 1, "ts": 1785000000}]}))
    (d / "v1.bpmn").write_text(BPMN.replace("{nodes}", "".join(_node(u) for u in uids)))


def _task(root, tid, status, horizon="now", owner="agent"):
    (root / ".tasks" / "active" / f"{tid}-x.md").write_text(
        f"---\nid: {tid}\nname: x\nstatus: {status}\nhorizon: {horizon}\n"
        f"owner: {owner}\n---\nbody\n")


ALL_NODES = ["tl_create", "tl_parked", "tl_work", "tl_heal", "tl_human_review", "tl_archive"]


@pytest.fixture()
def env(monkeypatch, tmp_path):
    store = tmp_path / ".context" / "designer" / "projects"
    _seed(store, "aef-task-lifecycle", ALL_NODES)
    _seed(store, "aef-dispatch-loop", ["a"])
    (tmp_path / ".tasks" / "active").mkdir(parents=True)
    monkeypatch.setattr(designer_api, "_STORE", store)
    monkeypatch.setattr(designer_api, "PROJECT_ROOT", tmp_path)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), tmp_path, store


def test_bad_id_is_400(env):
    c, _, _ = env
    assert c.get("/api/instances?template=Bad/Id").status_code == 400
    assert c.get("/api/instances").status_code == 400


def test_unknown_template_is_404(env):
    c, _, _ = env
    assert c.get("/api/instances?template=nope").status_code == 404


def test_other_template_has_no_instances(env):
    c, root, _ = env
    _task(root, "T-1", "started-work")
    r = c.get("/api/instances?template=aef-dispatch-loop")
    j = r.get_json()
    assert r.status_code == 200
    assert j["state"] == "NO-INSTANCES" and j["instances"] == []
    assert j["template"] == "aef-dispatch-loop" and "generated" in j and j["refusals"] == []


def test_lifecycle_maps_each_status(env):
    c, root, _ = env
    _task(root, "T-1", "captured", "now")
    _task(root, "T-2", "captured", "next")
    _task(root, "T-3", "captured", "later")
    _task(root, "T-4", "started-work")
    _task(root, "T-5", "issues")
    _task(root, "T-6", "work-completed", owner="human")
    _task(root, "T-7", "weird")
    j = c.get("/api/instances?template=aef-task-lifecycle").get_json()
    assert j["state"] == "INSTANCES" and j["examined"] == 7
    got = {i["task"]: (i["state"], i["node"], i["owner"]) for i in j["instances"]}
    assert got == {
        "T-1": ("NODE", "tl_create", "agent"),
        "T-2": ("NODE", "tl_create", "agent"),
        "T-3": ("NODE", "tl_parked", "agent"),
        "T-4": ("NODE", "tl_work", "agent"),
        "T-5": ("NODE", "tl_heal", "agent"),
        "T-6": ("NODE", "tl_human_review", "human"),
        "T-7": ("NO-POSITION", None, "agent"),
    }


def test_stale_when_map_drops_node(env):
    c, root, store = env
    shutil.rmtree(store / "aef-task-lifecycle")
    _seed(store, "aef-task-lifecycle", [n for n in ALL_NODES if n != "tl_work"])
    _task(root, "T-4", "started-work")
    j = c.get("/api/instances?template=aef-task-lifecycle").get_json()
    assert j["instances"][0]["state"] == "STALE"


def test_malformed_task_is_refused_not_dropped(env):
    c, root, _ = env
    (root / ".tasks" / "active" / "T-9-bad.md").write_text("no frontmatter\n")
    j = c.get("/api/instances?template=aef-task-lifecycle").get_json()
    assert j["examined"] == 1 and j["instances"] == []
    assert j["refusals"][0]["task"] == "T-9-bad.md"


def test_table_nodes_exist_in_real_lifecycle_map():
    """Every node the mapping uses must exist in the shipped aef-task-lifecycle map."""
    import importlib.util
    from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT

    spec = importlib.util.spec_from_file_location(
        "corpus_overlay", FRAMEWORK_ROOT / "tools" / "corpus_overlay.py")
    ov = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ov)
    present = ov.carriers(PROJECT_ROOT, "aef-task-lifecycle")
    assert present, "aef-task-lifecycle map not found in the designer store"
    missing = set(designer_api._LIFECYCLE_NODES.values()) - set(present)
    assert not missing, f"mapping uses nodes absent from the map: {missing}"
