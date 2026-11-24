"""T-5381: designer phases (832 T-1491) ride parse_map -> spec -> emit_map verbatim.

A phase is plain BPMN: a root <bpmn:category> with <bpmn:categoryValue> children
and a process-level <bpmn:group categoryValueRef=...> per phase. Before T-5381,
parse_map refused any map with a group (T-2614 rule) and never read the category,
so `fw corpus explain|conformance` refused such maps and regenerate lost the phase
list. Pinned here: the elements come back byte for byte, the corpus tools accept
the map, a map without phases is unaffected, and every other unsupported process
child is still refused.
"""

import json
import re
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_conformance as conformance  # noqa: E402
import corpus_explain as ce  # noqa: E402
import corpus_lint  # noqa: E402
import corpus_spec as cs  # noqa: E402

MAP_ID = "aef-task-lifecycle"

# The shapes 832 writes (msg 8dccabe1): category after the process, groups after
# the flow elements, one group with documentation, a BPMNShape per group in DI.
CATEGORY = """<bpmn:category id="Category_fase" name="Fase">
    <bpmn:categoryValue id="CategoryValue_order" value="Order"/>
    <bpmn:categoryValue id="CategoryValue_work" value="Work &amp; review"/>
  </bpmn:category>"""
GROUP_1 = """<bpmn:group id="Group_order" categoryValueRef="CategoryValue_order">
      <bpmn:documentation>Everything before work starts.</bpmn:documentation>
    </bpmn:group>"""
GROUP_2 = '<bpmn:group id="Group_work" categoryValueRef="CategoryValue_work"/>'


def _node(tag, nid, name, state):
    return (f'    <bpmn:{tag} id="{nid}" name="{name}">\n'
            f'      <bpmn:extensionElements><aef:meta state="{state}"/>'
            f'</bpmn:extensionElements>\n'
            f'    </bpmn:{tag}>\n')


def _flow(fid, a, b):
    return f'    <bpmn:sequenceFlow id="{fid}" sourceRef="{a}" targetRef="{b}"/>\n'


BODY = (
    '    <bpmn:startEvent id="s0" name="work identified"/>\n'
    + _node("serviceTask", "create", "create", "captured")
    + _node("serviceTask", "start", "start", "started-work")
    + _node("serviceTask", "heal", "heal", "issues")
    + _node("serviceTask", "shelve", "shelve", "captured")
    + _node("serviceTask", "archive", "archive", "work-completed")
    + _flow("f0", "s0", "create") + _flow("f1", "create", "start")
    + _flow("f2", "start", "heal") + _flow("f3", "heal", "start")
    + _flow("f4", "heal", "archive") + _flow("f5", "start", "archive")
    + _flow("f6", "start", "shelve")
)


def _doc(groups="", category_after="", category_before="", extra=""):
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI" xmlns:dc="http://www.omg.org/spec/DD/20100524/DC" xmlns:aef="http://anchorpoint.framework/aef/extensions" id="Definitions_x" targetNamespace="https://aef.anchorpoint.dev/workflows">
  <bpmn:collaboration id="Collaboration_x">
    <bpmn:participant id="Pool_x" name="Lifecycle" processRef="Process_x"/>
  </bpmn:collaboration>
  {category_before}
  <bpmn:process id="Process_x" isExecutable="true">
    <bpmn:extensionElements><aef:workflowMeta id="{MAP_ID}" version="1" schemaVersion="2" title="lifecycle test" tier_default="1"/></bpmn:extensionElements>
{BODY}{extra}    {groups}
  </bpmn:process>
  {category_after}
  <bpmndi:BPMNDiagram id="Diagram_x">
    <bpmndi:BPMNPlane id="Plane_x" bpmnElement="Collaboration_x">
      <bpmndi:BPMNShape id="Group_order_di" bpmnElement="Group_order">
        <dc:Bounds x="10" y="10" width="300" height="200"/>
      </bpmndi:BPMNShape>
    </bpmndi:BPMNPlane>
  </bpmndi:BPMNDiagram>
</bpmn:definitions>
"""


PHASED = _doc(groups=GROUP_1 + "\n    " + GROUP_2, category_after=CATEGORY)
PLAIN = _doc()


def _emit(spec):
    return cs.emit_map(spec, compat_alias=False)


@pytest.fixture(autouse=True)
def _hermetic_store(tmp_path, monkeypatch):
    """parse_map/emit_map read the store index for handoffs; keep it empty."""
    monkeypatch.setattr(cs, "STORE", tmp_path / "no-store")
    monkeypatch.setattr(cs, "store_index",
                        lambda _store=None: {"by_id": {}, "by_uuid": {}})


def test_spec_carries_category_and_groups_verbatim():
    spec = cs.parse_map(PHASED)
    assert spec["groups"] == [GROUP_1, GROUP_2]
    assert spec["categories"] == [CATEGORY]
    assert "categories_before_process" not in spec
    # nothing modelled as an aef extension: the spec holds plain BPMN text
    assert "aef:" not in "".join(spec["groups"] + spec["categories"])


def test_round_trip_reproduces_phase_elements_byte_identically():
    out = _emit(cs.parse_map(PHASED))
    for element in (CATEGORY, GROUP_1, GROUP_2):
        assert element in out
    # positions: groups inside the process after the last flow, category at the
    # root after the process
    proc_end = out.index("</bpmn:process>")
    assert out.rindex("<bpmn:sequenceFlow") < out.index(GROUP_1) < out.index(GROUP_2) < proc_end
    assert proc_end < out.index(CATEGORY) < out.index("</bpmn:definitions>")
    # regenerate is a fixpoint
    assert _emit(cs.parse_map(out)) == out
    assert cs.canonical(out) == cs.canonical(PHASED)


def test_category_before_process_stays_before_it():
    src = _doc(groups=GROUP_2, category_before=CATEGORY)
    spec = cs.parse_map(src)
    assert spec["categories_before_process"] == [CATEGORY]
    assert "categories" not in spec
    out = _emit(spec)
    assert out.index("</bpmn:collaboration>") < out.index(CATEGORY) < out.index("<bpmn:process")
    assert _emit(cs.parse_map(out)) == out


def test_group_without_root_prefix_falls_back_to_stable_form():
    """A source that binds BPMN to another prefix cannot be pasted literally into
    a document that declares bpmn:; the element is carried in the stable
    serialisation instead, and still re-parses to the same element."""
    src = PHASED.replace(
        "<bpmn:definitions ",
        '<bpmn:definitions xmlns:semantic="http://www.omg.org/spec/BPMN/20100524/MODEL" ',
    ).replace(GROUP_2, '<semantic:group id="Group_work" categoryValueRef="CategoryValue_work"/>')
    spec = cs.parse_map(src)
    assert spec["groups"][1].startswith("<bpmn:group ")
    out = _emit(spec)
    assert _emit(cs.parse_map(out)) == out
    assert cs.canonical(out)["groups"] == spec["groups"]


def test_map_without_phases_is_unchanged():
    spec = cs.parse_map(PLAIN)
    for key in ("groups", "categories", "categories_before_process"):
        assert key not in spec
    out = _emit(spec)
    assert "group" not in out and "category" not in out


def test_other_unsupported_process_child_still_refused():
    src = _doc(extra='    <bpmn:textAnnotation id="Note_1"><bpmn:text>x</bpmn:text>'
                     '</bpmn:textAnnotation>\n')
    with pytest.raises(SystemExit, match=r"unsupported BPMN element <bpmn:textAnnotation"):
        cs.parse_map(src)
    # a group in a foreign namespace is not a BPMN group: still refused
    src = _doc(extra='    <x:group xmlns:x="urn:other" id="G_x"/>\n')
    with pytest.raises(SystemExit, match=r"unsupported BPMN element <bpmn:group"):
        cs.parse_map(src)


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
    d = tmp_path / ".context/designer/projects" / MAP_ID
    d.mkdir(parents=True)
    (d / "meta.json").write_text(json.dumps({"latest": 1, "uuid": "u-1"}))
    (d / "v1.bpmn").write_text(xml)
    (tmp_path / "status-transitions.yaml").write_text(TRANSITIONS)
    (tmp_path / "tools").mkdir()
    (tmp_path / "tools/conformance-registry.yaml").write_text(
        f"{MAP_ID}:\n  primitive: transition-table\n  source: status-transitions.yaml\n")
    return tmp_path


def test_explain_conformance_and_lint_accept_phased_map(tmp_path, capsys):
    root = _store(tmp_path, PHASED)
    assert ce.explain(root, MAP_ID) == 0
    assert "lifecycle test" in capsys.readouterr().out
    entry = conformance.load_registry(root)[MAP_ID]
    assert conformance.check_entry(root, MAP_ID, entry) == 0
    assert "PASS" in capsys.readouterr().out
    store = root / ".context/designer/projects"
    rc = corpus_lint.main(["--store", str(store), "--json", MAP_ID])
    payload = json.loads(capsys.readouterr().out)
    assert payload["scanned"] == [f"{MAP_ID}@v1"]
    errors = [f for f in payload["findings"] if f.get("severity") != "warning"]
    assert errors == [] and rc == 0


def test_explain_still_refuses_unsupported_element(tmp_path):
    """Control leg: the same store with a still-unsupported element is refused,
    so the acceptance above is not a tool that never refuses."""
    bad = PHASED.replace(GROUP_2, re.sub("group", "textAnnotation", GROUP_2))
    root = _store(tmp_path, bad)
    with pytest.raises(SystemExit, match="unsupported BPMN element"):
        ce.explain(root, MAP_ID)
