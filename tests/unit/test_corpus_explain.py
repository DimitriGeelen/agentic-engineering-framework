"""T-2622: corpus explain — walkthrough rendering + authority-stage derivation.

Stage derivation is the load-bearing piece: the cascading-detail model (T-2619)
routes precedence on it, so both directions are pinned against synthetic stores.
"""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_explain as ce  # noqa: E402

HEAD = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'xmlns:aef="http://anchorpoint.framework/aef/extensions" id="Definitions_x" '
    'targetNamespace="https://aef.anchorpoint.dev/workflows">'
    '<bpmn:process id="Process_x" isExecutable="true">'
    '<bpmn:extensionElements><aef:workflowMeta id="m" version="1" '
    'schemaVersion="2" title="lifecycle test" tier_default="1"/>'
    "</bpmn:extensionElements>"
)
TAIL = "</bpmn:process></bpmn:definitions>"


def _node(tag, nid, name, state=None):
    ext = ""
    if state:
        ext = (f"<bpmn:extensionElements><aef:meta state=\"{state}\"/>"
               "</bpmn:extensionElements>")
    return f'<bpmn:{tag} id="{nid}" name="{name}">{ext}</bpmn:{tag}>'


def _flow(fid, a, b, name=""):
    nm = f' name="{name}"' if name else ""
    return f'<bpmn:sequenceFlow id="{fid}" sourceRef="{a}" targetRef="{b}"{nm}/>'


# Full non-legacy state machine expressed as a map.
GREEN_XML = HEAD + "".join([
    _node("startEvent", "s0", "work identified"),
    _node("serviceTask", "create", "create", "captured"),
    _node("serviceTask", "start", "start", "started-work"),
    _node("serviceTask", "heal", "heal", "issues"),
    _node("serviceTask", "shelve", "shelve", "captured"),
    _node("serviceTask", "archive", "archive", "work-completed"),
    _flow("f0", "s0", "create"),
    _flow("f1", "create", "start"),
    _flow("f2", "start", "heal"),
    _flow("f3", "heal", "start"),
    _flow("f4", "heal", "archive"),
    _flow("f5", "start", "archive"),
    _flow("f6", "start", "shelve"),
]) + TAIL

# Same map minus two edges -> divergent.
THIN_XML = HEAD + "".join([
    _node("serviceTask", "create", "create", "captured"),
    _node("serviceTask", "start", "start", "started-work"),
    _node("serviceTask", "heal", "heal", "issues"),
    _node("serviceTask", "archive", "archive", "work-completed"),
    _flow("f1", "create", "start"),
    _flow("f2", "start", "heal"),
    _flow("f3", "heal", "start"),
    _flow("f5", "start", "archive"),
]) + TAIL

TRANSITIONS = (
    "transitions:\n"
    "  - {from: captured, to: started-work}\n"
    "  - {from: started-work, to: captured}\n"
    "  - {from: started-work, to: issues}\n"
    "  - {from: started-work, to: work-completed}\n"
    "  - {from: issues, to: started-work}\n"
    "  - {from: issues, to: work-completed}\n"
)


def _store(tmp_path, xml):
    d = tmp_path / ".context/designer/projects/aef-task-lifecycle"
    d.mkdir(parents=True)
    (d / "meta.json").write_text('{"latest": 1, "uuid": "u-1"}')
    (d / "v1.bpmn").write_text(xml)
    (tmp_path / "status-transitions.yaml").write_text(TRANSITIONS)
    return tmp_path


def test_green_rail_grants_detail_authority(tmp_path):
    root = _store(tmp_path, GREEN_XML)
    stage, rail = ce.authority_stage(root, "aef-task-lifecycle")
    assert stage == "detail-authority"
    assert "GREEN" in rail


def test_divergent_rail_stays_transitional_subordinate(tmp_path):
    root = _store(tmp_path, THIN_XML)
    stage, rail = ce.authority_stage(root, "aef-task-lifecycle")
    assert stage == "transitional-subordinate"
    assert "DIVERGENT" in rail
    assert "started-work->captured" in rail


def test_unrailed_map_is_transitional_subordinate(tmp_path):
    stage, rail = ce.authority_stage(tmp_path, "some-other-map")
    assert stage == "transitional-subordinate"
    assert "no conformance rail" in rail


def test_explain_renders_every_node_and_the_provenance_footer(tmp_path, capsys):
    root = _store(tmp_path, GREEN_XML)
    assert ce.explain(root, "aef-task-lifecycle") == 0
    out = capsys.readouterr().out
    for name in ("work identified", "create", "start", "heal", "shelve", "archive"):
        assert name in out
    assert "authority stage: detail-authority" in out
    assert "state: captured" in out


def test_search_matches_node_names_and_points_at_explain(tmp_path, capsys):
    root = _store(tmp_path, GREEN_XML)
    assert ce.search(root, "shelve") == 0
    out = capsys.readouterr().out
    assert "aef-task-lifecycle" in out and "fw corpus explain" in out


def test_search_silent_on_no_match(tmp_path, capsys):
    root = _store(tmp_path, GREEN_XML)
    assert ce.search(root, "zzz-no-such-term") == 0
    assert capsys.readouterr().out == ""
