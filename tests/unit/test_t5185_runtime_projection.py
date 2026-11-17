"""T-5185: runtime projection contract v1 pins GET /api/instances and GET /api/overlay.

Real responses from both endpoints (Flask test client on a fixture project) must
validate against docs/research/executable-workflow/contracts/v2/runtime-projection/
runtime-projection.schema.json, through the schema's own x-responses table. The
controls prove the schema bites: a captured response with a required field removed
(or an enum value changed) must fail validation.

T-5193: the endpoints now serve runtime projection v2 (pinned by
test_t5193_runtime_projection_v2.py). v1 stays frozen, and this file keeps pinning it
on the v1-compatible projection of each v2 body (_to_v1): drop the v2-only fields and
read `unplaced` back as v1 `refusals`. So every v1 field is still served, unchanged.
"""

import copy
import json
import sys
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator
from referencing import Registry, Resource

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import web.blueprints.designer as designer  # noqa: E402
import web.blueprints.designer_api as designer_api  # noqa: E402

SCHEMA_PATH = (ROOT / "docs/research/executable-workflow/contracts/v2/runtime-projection"
               / "runtime-projection.schema.json")
SCHEMA = json.loads(SCHEMA_PATH.read_text())

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
LIFECYCLE = ["tl_create", "tl_parked", "tl_work", "tl_heal", "tl_human_review", "tl_archive"]


def _node(uid):
    return (f'<bpmn:serviceTask id="{uid}" name="{uid}"><bpmn:extensionElements>'
            f'<aef:uid value="{uid}"/></bpmn:extensionElements></bpmn:serviceTask>')


def _seed_map(store, map_id, uids):
    d = store / map_id
    d.mkdir(parents=True)
    (d / "meta.json").write_text(json.dumps({
        "id": map_id, "title": map_id, "latest": 1,
        "versions": [{"v": 1, "ts": 1785000000}]}))
    (d / "v1.bpmn").write_text(BPMN.replace("{nodes}", "".join(_node(u) for u in uids)))


def _task(root, tid, status, horizon="now", owner="agent", last_update="2026-01-01T00:00:00Z"):
    (root / ".tasks/active" / f"{tid}-x.md").write_text(
        f"---\nid: {tid}\nname: x\nstatus: {status}\nhorizon: {horizon}\n"
        f"owner: {owner}\nlast_update: '{last_update}'\n---\nbody\n")


@pytest.fixture()
def project(monkeypatch, tmp_path):
    store = tmp_path / ".context/designer/projects"
    _seed_map(store, "aef-task-lifecycle", [u for u in LIFECYCLE if u != "tl_heal"])
    _seed_map(store, "aef-dispatch-loop", ["a"])
    (tmp_path / ".tasks/active").mkdir(parents=True)
    (tmp_path / ".tasks/completed").mkdir(parents=True)
    monkeypatch.setattr(designer_api, "_STORE", store)
    monkeypatch.setattr(designer_api, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(designer, "PROJECT_ROOT", tmp_path)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), tmp_path


def _populate(root):
    _task(root, "T-1", "captured", "now")
    _task(root, "T-2", "captured", "later")
    _task(root, "T-3", "started-work", last_update="2020-01-01T00:00:00Z")  # alert
    _task(root, "T-4", "issues")             # tl_heal absent from map -> STALE
    _task(root, "T-5", "work-completed", owner="human")
    _task(root, "T-6", "weird")              # NO-POSITION
    (root / ".tasks/active/T-9-bad.md").write_text("no frontmatter\n")  # refusal
    (root / ".context/working").mkdir(parents=True)
    (root / ".context/working/focus.yaml").write_text("current_task: T-3\n")


def _validator(path, status):
    ref = SCHEMA["x-responses"][path][str(status)]
    registry = Registry().with_resource(SCHEMA["$id"], Resource.from_contents(SCHEMA))
    return Draft202012Validator({"$ref": SCHEMA["$id"] + ref}, registry=registry)


def _to_v1(body):
    """The v1-compatible view of a v2 200 body (T-5193); error bodies are unchanged."""
    body = dict(body)
    body.pop("runtime_projection_version", None)
    if "unplaced" in body:
        body["refusals"] = body.pop("unplaced")
    if "instances" in body:
        body["instances"] = [{k: v for k, v in i.items() if k not in ("traversed", "unmapped")}
                             for i in body["instances"]]
    return body


def _get(resp):
    body = json.loads(resp.get_data(as_text=True))
    return _to_v1(body) if resp.status_code == 200 else body


def _check(resp, path):
    assert resp.mimetype == "application/json"
    body = _get(resp)
    errors = list(_validator(path, resp.status_code).iter_errors(body))
    assert not errors, [e.message for e in errors]
    return body


def test_schema_is_valid_and_versioned():
    Draft202012Validator.check_schema(SCHEMA)
    assert SCHEMA["runtime_projection_version"] == 1
    for path in ("GET /api/instances", "GET /api/overlay"):
        assert "200" in SCHEMA["x-responses"][path]


def test_every_field_has_a_description():
    """Each declared field (properties of every $defs object) carries a description,
    its own or that of the $defs entry it references. Conditional allOf/if/then
    clauses restate fields already declared, so they are not fields."""
    defs = SCHEMA["$defs"]
    missing = []
    for dname, d in defs.items():
        for name, sub in (d.get("properties") or {}).items():
            target = defs.get(sub.get("$ref", "").rsplit("/", 1)[-1], {})
            if "description" not in sub and "description" not in target:
                missing.append(f"{dname}.{name}")
    assert not missing, missing
    assert all("description" in d for d in defs.values())


def test_instances_non_empty(project):
    c, root = project
    _populate(root)
    j = _check(c.get("/api/instances?template=aef-task-lifecycle"), "GET /api/instances")
    assert j["state"] == "INSTANCES"
    states = {i["task"]: i["state"] for i in j["instances"]}
    assert states == {"T-1": "NODE", "T-2": "NODE", "T-3": "NODE", "T-4": "STALE",
                      "T-5": "NODE", "T-6": "NO-POSITION"}
    assert j["refusals"] == [{"task": "T-9-bad.md", "reason": "no frontmatter"}]


def test_instances_empty_cases(project):
    c, root = project
    j = _check(c.get("/api/instances?template=aef-task-lifecycle"), "GET /api/instances")
    assert j["state"] == "NO-INSTANCES" and j["examined"] == 0
    _populate(root)  # another known map: still no instances
    j = _check(c.get("/api/instances?template=aef-dispatch-loop"), "GET /api/instances")
    assert j["state"] == "NO-INSTANCES" and j["instances"] == []


def test_instances_errors(project):
    c, _ = project
    for url, status in (("/api/instances", 400), ("/api/instances?template=Bad/Id", 400),
                        ("/api/instances?template=nope", 404)):
        r = c.get(url)
        assert r.status_code == status
        _check(r, "GET /api/instances")


def test_overlay_non_empty(project):
    c, root = project
    _populate(root)
    j = _check(c.get("/api/overlay?id=aef-task-lifecycle"), "GET /api/overlay")
    by_uid = {n["uid"]: n for n in j["nodes"]}
    assert set(by_uid) == {"tl_create", "tl_parked", "tl_work", "tl_human_review"}
    assert by_uid["tl_work"]["severity"] == "alert" and "focus: T-3" in by_uid["tl_work"]["text"]


def test_overlay_empty_cases(project):
    c, root = project
    j = _check(c.get("/api/overlay?id=aef-task-lifecycle"), "GET /api/overlay")
    assert j["nodes"] == []
    _populate(root)  # a map with no projection profile
    j = _check(c.get("/api/overlay?id=aef-dispatch-loop"), "GET /api/overlay")
    assert j["nodes"] == []


def test_overlay_errors(project):
    c, _ = project
    for url in ("/api/overlay?id=no-such-map", "/api/overlay?id=../../etc", "/api/overlay"):
        r = c.get(url)
        assert r.status_code == 404
        _check(r, "GET /api/overlay")


def _captured(project):
    c, root = project
    _populate(root)
    inst = _get(c.get("/api/instances?template=aef-task-lifecycle"))
    ovl = _get(c.get("/api/overlay?id=aef-task-lifecycle"))
    err = _get(c.get("/api/instances?template=nope"))
    return inst, ovl, err


@pytest.mark.parametrize("which,path,status,drop", [
    ("inst", "GET /api/instances", 200, ("template",)),
    ("inst", "GET /api/instances", 200, ("refusals",)),
    ("inst", "GET /api/instances", 200, ("instances", 0, "node")),
    ("inst", "GET /api/instances", 200, ("refusals", 0, "task")),
    ("ovl", "GET /api/overlay", 200, ("type",)),
    ("ovl", "GET /api/overlay", 200, ("nodes", 0, "severity")),
    ("err", "GET /api/instances", 404, ("ok",)),
])
def test_control_removing_a_required_field_fails(project, which, path, status, drop):
    inst, ovl, err = _captured(project)
    body = copy.deepcopy({"inst": inst, "ovl": ovl, "err": err}[which])
    assert not list(_validator(path, status).iter_errors(body)), "captured body must validate first"
    target = body
    for key in drop[:-1]:
        target = target[key]
    del target[drop[-1]]
    assert list(_validator(path, status).iter_errors(body)), f"removing {drop} must fail"


def test_control_changed_enum_and_extra_field_fail(project):
    inst, ovl, _ = _captured(project)
    v_inst, v_ovl = _validator("GET /api/instances", 200), _validator("GET /api/overlay", 200)
    bad = copy.deepcopy(inst)
    bad["instances"][0]["state"] = "ON-NODE"
    assert list(v_inst.iter_errors(bad))
    bad = copy.deepcopy(inst)
    bad["state"] = "NO-INSTANCES"  # contradicts a non-empty instances list
    assert list(v_inst.iter_errors(bad))
    bad = copy.deepcopy(ovl)
    bad["nodes"][0]["severity"] = "err"
    assert list(v_ovl.iter_errors(bad))
    bad = copy.deepcopy(ovl)
    bad["schema_version"] = 2
    assert list(v_ovl.iter_errors(bad))
