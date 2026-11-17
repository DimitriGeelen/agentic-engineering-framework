"""T-5193: runtime projection v2 — traversed edges, unmapped transitions, unplaced, version.

Pins GET /api/instances and GET /api/overlay to
docs/research/executable-workflow/contracts/v2/runtime-projection/runtime-projection-v2.schema.json
(Flask test client on a fixture project whose lifecycle map has real flows), and the
traversal derivation on fixture tasks: a normal path, a transition with no edge, an
ambiguous transition, and a task with no history. Controls prove the schema bites.
"""

import copy
import json
import subprocess
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

DIR = ROOT / "docs/research/executable-workflow/contracts/v2/runtime-projection"
SCHEMA = json.loads((DIR / "runtime-projection-v2.schema.json").read_text())
V1_PATH = DIR / "runtime-projection.schema.json"

# A cut-down aef-task-lifecycle with the real uids: create -> gw_ready -> start -> work,
# gw_ready -> parked -> start, work -> gw_issues -> heal, heal -> work (direct) AND
# heal -> verify -> gates -> work (so heal -> work is ambiguous), work -> parked,
# gw_issues -> verify -> gates -> gw_human -> human_review.
NODES = [("agt_1_create", "tl_create", "serviceTask"), ("agt_2_parked", "tl_parked", "serviceTask"),
         ("agt_3_start", "tl_start", "serviceTask"), ("agt_4_do", "tl_work", "serviceTask"),
         ("agt_5_healing", "tl_heal", "serviceTask"), ("agt_6_completion", "tl_verify", "serviceTask"),
         ("agt_7_archive", "tl_archive", "serviceTask"), ("hum_1_partial", "tl_human_review", "userTask"),
         ("agt_gw_ready", "tl_gw_ready", "exclusiveGateway"),
         ("agt_gw_issues", "tl_gw_issues", "exclusiveGateway"),
         ("agt_gw_gates", "tl_gw_gates", "exclusiveGateway"),
         ("agt_gw_unchecked", "tl_gw_human", "exclusiveGateway")]
FLOWS = [("tl_e2", "agt_1_create", "agt_gw_ready"), ("tl_e14", "agt_gw_ready", "agt_3_start"),
         ("tl_e15", "agt_gw_ready", "agt_2_parked"), ("tl_e16", "agt_2_parked", "agt_3_start"),
         ("tl_e3", "agt_3_start", "agt_4_do"), ("tl_e4", "agt_4_do", "agt_gw_issues"),
         ("tl_e5", "agt_gw_issues", "agt_5_healing"), ("tl_e6", "agt_5_healing", "agt_4_do"),
         ("tl_e7", "agt_gw_issues", "agt_6_completion"), ("tl_e8", "agt_6_completion", "agt_gw_gates"),
         ("tl_e17", "agt_gw_gates", "agt_gw_unchecked"), ("tl_e18", "agt_gw_gates", "agt_4_do"),
         ("tl_e9", "agt_gw_unchecked", "hum_1_partial"), ("tl_e10", "agt_gw_unchecked", "agt_7_archive"),
         ("tl_e19", "agt_4_do", "agt_2_parked"), ("tl_e20", "agt_5_healing", "agt_6_completion")]


def _bpmn():
    ext = '<bpmn:extensionElements><aef:uid value="{}"/></bpmn:extensionElements>'
    body = "".join(f'<bpmn:{t} id="{i}" name="{i}">{ext.format(u)}</bpmn:{t}>' for i, u, t in NODES)
    body += "".join(f'<bpmn:sequenceFlow id="f_{u}" sourceRef="{a}" targetRef="{b}">{ext.format(u)}'
                    "</bpmn:sequenceFlow>" for u, a, b in FLOWS)
    return ('<?xml version="1.0" encoding="UTF-8"?>'
            '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
            'xmlns:aef="http://anchorpoint.framework/aef/extensions" id="D" '
            'targetNamespace="https://aef.anchorpoint.dev/workflows">'
            '<bpmn:process id="P" isExecutable="true">'
            '<bpmn:extensionElements><aef:workflowMeta id="m" version="1" '
            'schemaVersion="2" title="t" tier_default="1"/></bpmn:extensionElements>'
            f"{body}</bpmn:process></bpmn:definitions>")


def _seed_map(store, map_id, xml):
    d = store / map_id
    d.mkdir(parents=True)
    (d / "meta.json").write_text(json.dumps({
        "id": map_id, "title": map_id, "latest": 1, "versions": [{"v": 1, "ts": 1785000000}]}))
    (d / "v1.bpmn").write_text(xml)


def _upd(ts, *changes):
    lines = "".join(f"- **Change:** {c}\n" for c in changes)
    return f"\n### {ts} — status-update [task-update-agent]\n{lines}"


def _task(root, tid, status, horizon="now", history=""):
    (root / ".tasks/active" / f"{tid}-x.md").write_text(
        f"---\nid: {tid}\nname: x\nstatus: {status}\nhorizon: {horizon}\nowner: agent\n"
        f"last_update: '2026-01-01T00:00:00Z'\n---\n# {tid}\n\n## Updates\n"
        f"\n### 2026-01-01T00:00:00Z — task-created [task-create-agent]\n- **Action:** Created\n"
        f"{history}")


@pytest.fixture()
def project(monkeypatch, tmp_path):
    store = tmp_path / ".context/designer/projects"
    _seed_map(store, "aef-task-lifecycle", _bpmn())
    (tmp_path / ".tasks/active").mkdir(parents=True)
    (tmp_path / ".tasks/completed").mkdir(parents=True)
    monkeypatch.setattr(designer_api, "_STORE", store)
    monkeypatch.setattr(designer_api, "PROJECT_ROOT", tmp_path)
    monkeypatch.setattr(designer, "PROJECT_ROOT", tmp_path)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), tmp_path


def _populate(root):
    # normal path: created (next) -> started -> issues
    _task(root, "T-1", "issues", history=(
        _upd("2026-01-02T00:00:00Z", "status: captured → started-work", "horizon: next → now (auto-sync)")
        + _upd("2026-01-03T00:00:00Z", "status: started-work → issues")))
    # unmapped: started -> captured with horizon now (no edge back to tl_create), then a
    # horizon-only change that moves the node (tl_create -> tl_parked)
    _task(root, "T-2", "captured", horizon="later", history=(
        _upd("2026-01-02T00:00:00Z", "status: captured → started-work")
        + _upd("2026-01-03T00:00:00Z", "status: started-work → captured")
        + _upd("2026-01-04T00:00:00Z", "horizon: now → later")))
    _task(root, "T-3", "captured")  # no history
    # ambiguous: heal -> work has two chains (direct tl_e6 and the gates detour)
    _task(root, "T-4", "started-work", history=_upd("2026-01-02T00:00:00Z", "status: issues → started-work"))
    # no node on one side; and a parked task picked up then completed (partial-complete)
    _task(root, "T-5", "weird", history=_upd("2026-01-02T00:00:00Z", "status: started-work → weird"))
    _task(root, "T-6", "work-completed", history=(
        _upd("2026-01-02T00:00:00Z", "status: captured → started-work", "horizon: later → now (auto-sync)")
        + _upd("2026-01-03T00:00:00Z", "status: started-work → work-completed")))
    (root / ".tasks/active/T-9-bad.md").write_text("no frontmatter\n")


def _validator(path, status):
    ref = SCHEMA["x-responses"][path][str(status)]
    registry = Registry().with_resource(SCHEMA["$id"], Resource.from_contents(SCHEMA))
    return Draft202012Validator({"$ref": SCHEMA["$id"] + ref}, registry=registry)


def _check(resp, path):
    assert resp.mimetype == "application/json"
    body = json.loads(resp.get_data(as_text=True))
    errors = list(_validator(path, resp.status_code).iter_errors(body))
    assert not errors, [e.message for e in errors]
    return body


def test_schema_valid_versioned_and_v1_frozen():
    Draft202012Validator.check_schema(SCHEMA)
    assert SCHEMA["runtime_projection_version"] == 2
    v1 = json.loads(V1_PATH.read_text())
    assert v1["runtime_projection_version"] == 1 and "instance_refusal" in v1["$defs"]
    rel = str(V1_PATH.relative_to(ROOT))
    r = subprocess.run(["git", "log", "--format=%s", "--", rel], cwd=ROOT,
                       capture_output=True, text=True)
    if r.returncode == 0 and r.stdout.strip():  # git available: only T-5185 ever wrote it
        assert all(s.startswith("T-5185") for s in r.stdout.splitlines()), r.stdout
        assert subprocess.run(["git", "diff", "--quiet", "HEAD", "--", rel], cwd=ROOT).returncode == 0


def test_every_field_has_a_description():
    defs = SCHEMA["$defs"]
    missing = [f"{dn}.{n}" for dn, d in defs.items() for n, sub in (d.get("properties") or {}).items()
               if "description" not in sub
               and "description" not in defs.get(sub.get("$ref", "").rsplit("/", 1)[-1], {})]
    assert not missing, missing
    assert all("description" in d for d in defs.values())


def test_traversal_on_fixture_tasks(project):
    c, root = project
    _populate(root)
    j = _check(c.get("/api/instances?template=aef-task-lifecycle"), "GET /api/instances")
    got = {i["task"]: (i["traversed"], i["unmapped"]) for i in j["instances"]}
    assert got["T-1"] == (["tl_e2", "tl_e14", "tl_e3", "tl_e4", "tl_e5"], [])
    assert got["T-2"] == (
        ["tl_e2", "tl_e14", "tl_e3", "tl_e2", "tl_e15"],
        [{"from": "tl_work", "to": "tl_create", "at": "2026-01-03T00:00:00Z"}])
    assert got["T-3"] == ([], [])
    assert got["T-4"] == ([], [{"from": "tl_heal", "to": "tl_work", "at": "2026-01-02T00:00:00Z"}])
    assert got["T-5"] == ([], [{"from": "tl_work", "to": None, "at": "2026-01-02T00:00:00Z"}])
    assert got["T-6"] == (["tl_e16", "tl_e3", "tl_e4", "tl_e7", "tl_e8", "tl_e17", "tl_e9"], [])
    flow_uids = {u for u, _, _ in FLOWS}
    assert all(e in flow_uids for t, _ in got.values() for e in t)


def test_instances_shape(project):
    c, root = project
    _populate(root)
    j = _check(c.get("/api/instances?template=aef-task-lifecycle"), "GET /api/instances")
    assert j["runtime_projection_version"] == 2
    assert j["unplaced"] == [{"task": "T-9-bad.md", "reason": "no frontmatter"}]
    assert j["refusals"] == [] and j["examined"] == 7


def test_unreadable_map_unmaps_every_change(project):
    c, root = project
    _populate(root)
    (root / ".context/designer/projects/aef-task-lifecycle/v1.bpmn").unlink()  # latest unreadable
    j = _check(c.get("/api/instances?template=aef-task-lifecycle"), "GET /api/instances")
    assert all(i["traversed"] == [] for i in j["instances"])
    assert next(i for i in j["instances"] if i["task"] == "T-1")["unmapped"][0]["from"] == "tl_create"


def test_empty_errors_and_overlay_validate(project):
    c, root = project
    j = _check(c.get("/api/instances?template=aef-task-lifecycle"), "GET /api/instances")
    assert j["state"] == "NO-INSTANCES" and j["refusals"] == [] and j["unplaced"] == []
    for url, status in (("/api/instances", 400), ("/api/instances?template=nope", 404)):
        r = c.get(url)
        assert r.status_code == status
        _check(r, "GET /api/instances")
    _populate(root)
    j = _check(c.get("/api/overlay?id=aef-task-lifecycle"), "GET /api/overlay")
    assert j["runtime_projection_version"] == 2 and j["nodes"]
    r = c.get("/api/overlay?id=no-such-map")
    assert r.status_code == 404
    _check(r, "GET /api/overlay")


def test_live_repo_responses_validate():
    """The real project: both endpoints validate, and every traversed uid is a flow of the
    real map's latest version (an invariant, not a count)."""
    from web.app import app

    c = app.test_client()
    j = _check(c.get("/api/instances?template=aef-task-lifecycle"), "GET /api/instances")
    _check(c.get("/api/overlay?id=aef-task-lifecycle"), "GET /api/overlay")
    import importlib.util

    spec = importlib.util.spec_from_file_location("corpus_spec", ROOT / "tools" / "corpus_spec.py")
    cs = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cs)
    d = designer_api.PROJECT_ROOT / ".context/designer/projects/aef-task-lifecycle"
    latest = json.loads((d / "meta.json").read_text())["latest"]
    flows = {f.get("uid") for f in cs.parse_map((d / f"v{latest}.bpmn").read_text())["flows"]}
    assert all(e in flows for i in j["instances"] for e in i["traversed"])


def _captured(project):
    c, root = project
    _populate(root)
    inst = json.loads(c.get("/api/instances?template=aef-task-lifecycle").get_data(as_text=True))
    ovl = json.loads(c.get("/api/overlay?id=aef-task-lifecycle").get_data(as_text=True))
    return inst, ovl


@pytest.mark.parametrize("which,path,drop", [
    ("inst", "GET /api/instances", ("runtime_projection_version",)),
    ("inst", "GET /api/instances", ("unplaced",)),
    ("inst", "GET /api/instances", ("refusals",)),
    ("inst", "GET /api/instances", ("instances", 0, "traversed")),
    ("inst", "GET /api/instances", ("instances", 1, "unmapped")),
    ("inst", "GET /api/instances", ("instances", 1, "unmapped", 0, "at")),
    ("ovl", "GET /api/overlay", ("runtime_projection_version",)),
])
def test_control_removing_a_required_field_fails(project, which, path, drop):
    inst, ovl = _captured(project)
    body = copy.deepcopy({"inst": inst, "ovl": ovl}[which])
    v = _validator(path, 200)
    assert not list(v.iter_errors(body)), "captured body must validate first"
    target = body
    for key in drop[:-1]:
        target = target[key]
    del target[drop[-1]]
    assert list(v.iter_errors(body)), f"removing {drop} must fail"


def test_control_v1_shapes_and_wrong_values_fail(project):
    inst, ovl = _captured(project)
    v = _validator("GET /api/instances", 200)
    for mutate in (
        lambda b: b.__setitem__("refusals", b.pop("unplaced")),          # v1 shape
        lambda b: b["refusals"].append({"task": "T-1", "reason": "x"}),  # refusals must be []
        lambda b: b.__setitem__("runtime_projection_version", 1),
        lambda b: b["instances"][0]["traversed"].append(""),
        lambda b: b["instances"][1]["unmapped"][0].__setitem__("from", "tl_nowhere"),
    ):
        bad = copy.deepcopy(inst)
        mutate(bad)
        assert list(v.iter_errors(bad))
    bad = copy.deepcopy(ovl)
    bad["runtime_projection_version"] = 1
    assert list(_validator("GET /api/overlay", 200).iter_errors(bad))
