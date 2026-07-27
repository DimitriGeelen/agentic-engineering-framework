"""T-2629: overlay projection — IW-4 rules pinned against a synthetic store.

The projection is NOT a pure status join (T-2620 IW-4): partial-complete is
work-completed-still-in-active/, captured splits on horizon, archive is
windowed. Each rule and the phantom-uid filter get a direct pin.
"""

import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_overlay as co  # noqa: E402

NOW = time.mktime(time.strptime("2026-07-27T12:00:00", "%Y-%m-%dT%H:%M:%S"))

HEAD = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'xmlns:aef="http://anchorpoint.framework/aef/extensions" id="D" '
    'targetNamespace="https://aef.anchorpoint.dev/workflows">'
    '<bpmn:process id="P" isExecutable="true">'
    '<bpmn:extensionElements><aef:workflowMeta id="m" version="1" '
    'schemaVersion="2" title="t" tier_default="1"/></bpmn:extensionElements>'
)
TAIL = "</bpmn:process></bpmn:definitions>"


def _carrier(nid, uid, state):
    return (f'<bpmn:serviceTask id="{nid}" name="{nid}"><bpmn:extensionElements>'
            f'<aef:uid value="{uid}"/><aef:meta state="{state}"/>'
            f"</bpmn:extensionElements></bpmn:serviceTask>")


FULL_CARRIERS = HEAD + "".join([
    _carrier("n1", "tl_create", "captured"),
    _carrier("n2", "tl_parked", "captured"),
    _carrier("n3", "tl_work", "started-work"),
    _carrier("n4", "tl_heal", "issues"),
    _carrier("n5", "tl_human_review", "started-work"),
    _carrier("n6", "tl_archive", "work-completed"),
]) + TAIL

# tl_parked removed — its badge must be silently dropped, not phantom-emitted.
THIN_CARRIERS = HEAD + "".join([
    _carrier("n1", "tl_create", "captured"),
    _carrier("n3", "tl_work", "started-work"),
]) + TAIL


def _task(d, tid, status, horizon="now", last_update="2026-07-26T12:00:00Z"):
    (d / f"{tid}-x.md").write_text(
        f"---\nid: {tid}\nstatus: {status}\nhorizon: {horizon}\n"
        f"last_update: '{last_update}'\n---\n# {tid}\n"
    )


def _root(tmp_path, xml=FULL_CARRIERS, focus=None):
    proj = tmp_path / ".context/designer/projects/aef-task-lifecycle"
    proj.mkdir(parents=True)
    (proj / "meta.json").write_text('{"latest": 1}')
    (proj / "v1.bpmn").write_text(xml)
    (tmp_path / ".tasks/active").mkdir(parents=True)
    (tmp_path / ".tasks/completed").mkdir(parents=True)
    wd = tmp_path / ".context/working"
    wd.mkdir(parents=True, exist_ok=True)
    if focus:
        (wd / "focus.yaml").write_text(f"current_task: {focus}\n")
    return tmp_path


def _nodes(payload):
    return {n["uid"]: n for n in payload["nodes"]}


def test_projection_rules_route_each_status_to_its_carrier(tmp_path):
    root = _root(tmp_path)
    a = root / ".tasks/active"
    _task(a, "T-1", "captured", horizon="now")
    _task(a, "T-2", "captured", horizon="later")
    _task(a, "T-3", "started-work")
    _task(a, "T-4", "issues")
    _task(a, "T-5", "work-completed")  # partial-complete: still in active/
    _task(root / ".tasks/completed", "T-6", "work-completed")
    n = _nodes(co.build_payload(root, "aef-task-lifecycle", now=NOW))
    assert n["tl_create"]["badge"] == "1"
    assert n["tl_parked"]["badge"] == "1"
    assert n["tl_work"]["badge"] == "1"
    assert n["tl_heal"]["badge"] == "1"
    assert n["tl_human_review"]["badge"] == "1"  # NOT tl_archive
    assert n["tl_archive"]["badge"] == "1"


def test_archive_window_excludes_old_completions(tmp_path):
    root = _root(tmp_path)
    c = root / ".tasks/completed"
    _task(c, "T-1", "work-completed", last_update="2026-07-25T12:00:00Z")  # 2d
    _task(c, "T-2", "work-completed", last_update="2026-06-01T12:00:00Z")  # 56d
    n = _nodes(co.build_payload(root, "aef-task-lifecycle", now=NOW))
    assert n["tl_archive"]["badge"] == "1"


def test_severity_thresholds_and_stuck_text(tmp_path):
    root = _root(tmp_path)
    a = root / ".tasks/active"
    _task(a, "T-1", "started-work", last_update="2026-07-15T12:00:00Z")  # 12d -> warn
    n = _nodes(co.build_payload(root, "aef-task-lifecycle", now=NOW))
    assert n["tl_work"]["severity"] == "warn"
    assert "1 stuck >7d" in n["tl_work"]["text"]
    _task(a, "T-2", "started-work", last_update="2026-06-01T12:00:00Z")  # 56d -> alert
    n = _nodes(co.build_payload(root, "aef-task-lifecycle", now=NOW))
    assert n["tl_work"]["severity"] == "alert"


def test_focus_badge_lands_in_the_focused_tasks_bucket(tmp_path):
    root = _root(tmp_path, focus="T-9")
    _task(root / ".tasks/active", "T-9", "started-work")
    n = _nodes(co.build_payload(root, "aef-task-lifecycle", now=NOW))
    assert "focus: T-9" in n["tl_work"]["text"]


def test_phantom_uid_filter_drops_buckets_without_live_carrier(tmp_path):
    root = _root(tmp_path, xml=THIN_CARRIERS)
    a = root / ".tasks/active"
    _task(a, "T-1", "captured", horizon="later")   # tl_parked: carrier gone
    _task(a, "T-2", "started-work")                # tl_work: carrier present
    n = _nodes(co.build_payload(root, "aef-task-lifecycle", now=NOW))
    assert "tl_parked" not in n
    assert n["tl_work"]["badge"] == "1"


def test_unprofiled_map_and_empty_buckets_yield_empty_nodes(tmp_path):
    root = _root(tmp_path)
    assert co.build_payload(root, "some-other-map", now=NOW)["nodes"] == []
    assert co.build_payload(root, "aef-task-lifecycle", now=NOW)["nodes"] == []


def test_payload_carries_contract_shape(tmp_path):
    root = _root(tmp_path)
    _task(root / ".tasks/active", "T-1", "issues")
    p = co.build_payload(root, "aef-task-lifecycle", now=NOW)
    assert p["type"] == "aef:annotate" and p["map"] == "aef-task-lifecycle"
    assert set(p["nodes"][0]) == {"uid", "badge", "text", "severity"}
