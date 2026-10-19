"""T-2614: parse_map loss-free round-trip — strict on unknown tags, verbatim on
rich extension content.

Origin: the T-2609 recreate silently dropped aef-inception-flow's
`hum_3_inception` (bpmn:subProcess — a tag parse_map didn't know) while keeping
both flows through it; the served map rendered as two disconnected halves and
the canonical-diff identity guard was blind because both sides of the diff pass
through the same lossy parse. These tests pin the fix both ways.
"""

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_spec  # noqa: E402

HEAD = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'xmlns:aef="http://anchorpoint.framework/aef/extensions" id="Definitions_x" '
    'targetNamespace="https://aef.anchorpoint.dev/workflows">'
    '<bpmn:process id="Process_x" isExecutable="true">'
    '<bpmn:extensionElements><aef:workflowMeta id="m" version="1" '
    'schemaVersion="2" title="m" tier_default="1"/></bpmn:extensionElements>'
)
TAIL = "</bpmn:process></bpmn:definitions>"


def test_unknown_tag_is_a_hard_error_not_a_silent_drop():
    xml = HEAD + '<bpmn:callActivity id="mystery_node"/>' + TAIL
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(xml)
    msg = str(e.value)
    assert "callActivity" in msg and "mystery_node" in msg


def test_subprocess_round_trips_with_rich_extension_content():
    xml = HEAD + (
        '<bpmn:subProcess id="hum_x" name="explore — go/no-go">'
        "<bpmn:extensionElements>"
        '<aef:uid value="u1"/><aef:position x="10.0" y="20.0"/>'
        '<aef:constituents><aef:constituent id="c1" name="spikes"/>'
        '<aef:constituent id="c2" name="recommend"/></aef:constituents>'
        "</bpmn:extensionElements>"
        "<bpmn:incoming>f1</bpmn:incoming><bpmn:outgoing>f2</bpmn:outgoing>"
        "</bpmn:subProcess>"
    ) + TAIL
    spec = corpus_spec.parse_map(xml)
    node = next(n for n in spec["nodes"] if n["id"] == "hum_x")
    assert node["type"] == "subprocess"
    assert len(node["ext_raw"]) == 1 and "constituents" in node["ext_raw"][0]
    out = corpus_spec.emit_map(spec, version=1)
    assert 'id="hum_x"' in out and 'id="c2"' in out
    # loss-free: a second pass parses identically (raw capture is
    # serialization-stable across passes)
    assert corpus_spec.parse_map(out)["nodes"] == spec["nodes"]


def test_scripttask_parallel_gateway_and_flow_condition_round_trip():
    xml = HEAD + (
        '<bpmn:scriptTask id="s1" name="load ctx">'
        "<bpmn:extensionElements>"
        "<aef:endpoint>fw context build --task ${task_id}</aef:endpoint>"
        '<aef:contextReads paths=".context/project/"/>'
        "</bpmn:extensionElements></bpmn:scriptTask>"
        '<bpmn:parallelGateway id="g1" name="fan out"/>'
        '<bpmn:sequenceFlow id="f1" sourceRef="s1" targetRef="g1">'
        '<bpmn:conditionExpression xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:type="bpmn:tFormalExpression">${x &gt;= 0.7}</bpmn:conditionExpression>'
        "</bpmn:sequenceFlow>"
    ) + TAIL
    spec = corpus_spec.parse_map(xml)
    assert {n["id"]: n["type"] for n in spec["nodes"]} == {
        "s1": "script", "g1": "parallel-gateway"}
    assert len(spec["flows"][0]["raw_children"]) == 1
    out = corpus_spec.emit_map(spec, version=1)
    assert "fw context build" in out
    assert "conditionExpression" in out and "0.7" in out
    spec2 = corpus_spec.parse_map(out)
    assert spec2["nodes"] == spec["nodes"]
    assert spec2["flows"] == spec["flows"]


LIVE_UUID = "11111111-1111-4111-8111-111111111111"
_IDX = {"by_id": {"live-map": LIVE_UUID}, "by_uuid": {LIVE_UUID: "live-map"}}


def _handoff_spec(monkeypatch):
    """Parse a minimal map with one handoff throw against a synthetic store."""
    monkeypatch.setattr(corpus_spec, "store_index", lambda store=None: _IDX)
    xml = HEAD + (
        '<bpmn:intermediateThrowEvent id="n1" name="hand off">'
        "<bpmn:extensionElements>"
        f'<aef:link workflowRef="{LIVE_UUID}" name="live map" linkId="l1"/>'
        "</bpmn:extensionElements></bpmn:intermediateThrowEvent>"
    ) + TAIL
    return corpus_spec.parse_map(xml)


# ── T-2615: compat alias is capability-conditional on the pin flag ────────────

def test_emit_dual_form_while_editor_cannot_resolve_uuid(monkeypatch):
    spec = _handoff_spec(monkeypatch)
    out = corpus_spec.emit_map(spec, version=1, compat_alias=True)
    assert 'targetWorkflow="live-map"' in out
    assert f'workflowRef="{LIVE_UUID}"' in out


def test_emit_uuid_only_when_editor_resolves_uuid(monkeypatch):
    spec = _handoff_spec(monkeypatch)
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert "targetWorkflow" not in out
    assert f'workflowRef="{LIVE_UUID}"' in out


def test_emit_default_reads_pin_capability_flag(monkeypatch):
    """Default (compat_alias=None) derives from policy/designer-pin.yaml —
    pinned expectation post-T-2615: 0.3.2 resolves uuids, so the live default
    is uuid-only. If a future re-pin flips the flag back to false, this pin
    must be updated deliberately alongside a corpus regeneration."""
    assert corpus_spec._pin_resolves_workflow_ref() is True
    spec = _handoff_spec(monkeypatch)
    out = corpus_spec.emit_map(spec, version=1)
    assert "targetWorkflow" not in out and f'workflowRef="{LIVE_UUID}"' in out


def test_live_inception_flow_carries_the_restored_subprocess():
    """Regression pin on the store itself: the operator-visible defect was the
    inception-decision node missing from the SERVED map. Latest version must
    contain it, typed as subprocess, with all flows attached (no dangling)."""
    import json
    d = REPO_ROOT / ".context/designer/projects/aef-inception-flow"
    latest = json.loads((d / "meta.json").read_text())["latest"]
    xml = (d / f"v{latest}.bpmn").read_text()
    spec = corpus_spec.parse_map(xml)
    ids = {n["id"] for n in spec["nodes"]}
    # T-4224: hum_3_inception before designer 0.21.0 (832 T-1189 uid-paired table)
    assert "hum_1_explore" in ids
    assert next(n for n in spec["nodes"] if n["id"] == "hum_1_explore")["type"] == "subprocess"
    for f in spec["flows"]:
        assert f["from"] in ids and f["to"] in ids, f"dangling flow {f['id']}"


def test_fractional_lane_height_round_trips_and_integer_stays_bare():
    """T-2625: the designer editor saves fractional lane heights (drag-resize);
    int() coercion crashed derive. Fractional heights must round-trip verbatim,
    integer heights must keep emitting bare (byte-stability for existing maps)."""
    xml = (
        HEAD.replace("</bpmn:extensionElements>", "</bpmn:extensionElements>"
                     '<bpmn:laneSet id="ls">'
                     '<bpmn:lane id="a" name="A"><bpmn:extensionElements>'
                     '<aef:laneMeta abbr="a" authority="initiative" height="220"/>'
                     "</bpmn:extensionElements></bpmn:lane>"
                     '<bpmn:lane id="h" name="H"><bpmn:extensionElements>'
                     '<aef:laneMeta abbr="h" authority="sovereignty" '
                     'height="323.91686531856146"/>'
                     "</bpmn:extensionElements></bpmn:lane>"
                     "</bpmn:laneSet>")
        + TAIL
    )
    spec = corpus_spec.parse_map(xml)
    heights = {l["id"]: l["height"] for l in spec["lanes"]}
    assert heights["a"] == 220 and isinstance(heights["a"], int)
    assert heights["h"] == 323.91686531856146
    out = corpus_spec.emit_map(spec, version=1)
    assert 'height="220"' in out
    assert 'height="323.91686531856146"' in out


# ── T-4387: extension children are keyed by namespace AND local name ─────────

ZEEBE = "http://camunda.org/schema/zeebe/1.0"
FOREIGN_HEAD = HEAD.replace("xmlns:aef=", f'xmlns:zeebe="{ZEEBE}" xmlns:aef=', 1)


def test_foreign_extension_child_does_not_overwrite_node_aef_uid():
    xml = FOREIGN_HEAD + (
        '<bpmn:serviceTask id="s1" name="svc"><bpmn:extensionElements>'
        '<aef:uid value="u1"/><zeebe:uid value="X"/>'
        "</bpmn:extensionElements></bpmn:serviceTask>"
    ) + TAIL
    spec = corpus_spec.parse_map(xml)
    node = spec["nodes"][0]
    assert node["uid"] == "u1"
    assert len(node["ext_raw"]) == 1 and ZEEBE in node["ext_raw"][0]
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert '<aef:uid value="u1"/>' in out and 'value="X"' in out
    spec2 = corpus_spec.parse_map(out)
    assert spec2["nodes"] == spec["nodes"]
    again = corpus_spec.emit_map(spec2, version=1, compat_alias=False)
    assert corpus_spec.canonical(again) == corpus_spec.canonical(out)


def test_foreign_extension_child_does_not_overwrite_flow_aef_uid():
    xml = FOREIGN_HEAD + (
        '<bpmn:serviceTask id="a"/><bpmn:serviceTask id="b"/>'
        '<bpmn:sequenceFlow id="f1" sourceRef="a" targetRef="b">'
        '<bpmn:extensionElements><aef:uid value="fu1"/><zeebe:uid value="X"/>'
        "</bpmn:extensionElements></bpmn:sequenceFlow>"
    ) + TAIL
    spec = corpus_spec.parse_map(xml)
    flow = spec["flows"][0]
    assert flow["uid"] == "fu1"
    assert len(flow["ext_raw"]) == 1 and ZEEBE in flow["ext_raw"][0]
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    spec2 = corpus_spec.parse_map(out)
    assert spec2["flows"] == spec["flows"]
    again = corpus_spec.emit_map(spec2, version=1, compat_alias=False)
    assert corpus_spec.canonical(again) == corpus_spec.canonical(out)


# ── T-4388: unmodelled node children round-trip in BPMN schema order ─────────

_LOOPS = {
    "standardLoopCharacteristics":
        '<bpmn:standardLoopCharacteristics testBefore="true"/>',
    "multiInstanceLoopCharacteristics":
        '<bpmn:multiInstanceLoopCharacteristics isSequential="true">'
        "<bpmn:loopCardinality>3</bpmn:loopCardinality>"
        "</bpmn:multiInstanceLoopCharacteristics>",
}


@pytest.mark.parametrize("tag", sorted(_LOOPS))
def test_loop_characteristics_round_trip_on_service_task(tag):
    xml = HEAD + (
        '<bpmn:serviceTask id="s1" name="svc"><bpmn:extensionElements>'
        '<aef:uid value="u1"/></bpmn:extensionElements>'
        f"{_LOOPS[tag]}</bpmn:serviceTask>"
    ) + TAIL
    spec = corpus_spec.parse_map(xml)
    node = spec["nodes"][0]
    assert len(node["raw_children"]) == 1 and tag in node["raw_children"][0]
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert tag in out
    spec2 = corpus_spec.parse_map(out)
    assert spec2["nodes"] == spec["nodes"]
    again = corpus_spec.emit_map(spec2, version=1, compat_alias=False)
    assert corpus_spec.canonical(again) == corpus_spec.canonical(out)


def test_node_children_loop_characteristics_emit_in_schema_order():
    """tBaseElement: documentation, extensionElements; tFlowNode: incoming,
    outgoing; tActivity: ioSpecification … loopCharacteristics LAST."""
    xml = HEAD + (
        '<bpmn:serviceTask id="a"/>'
        '<bpmn:serviceTask id="s1" name="svc">'
        "<bpmn:documentation>why</bpmn:documentation>"
        '<bpmn:extensionElements><aef:uid value="u1"/></bpmn:extensionElements>'
        "<bpmn:incoming>f1</bpmn:incoming>"
        '<bpmn:property id="p1" name="x"/>'
        f'{_LOOPS["multiInstanceLoopCharacteristics"]}'
        "</bpmn:serviceTask>"
        '<bpmn:sequenceFlow id="f1" sourceRef="a" targetRef="s1"/>'
    ) + TAIL
    out = corpus_spec.emit_map(corpus_spec.parse_map(xml), version=1,
                               compat_alias=False)
    block = out[out.index('<bpmn:serviceTask id="s1"'):]
    block = block[:block.index("</bpmn:serviceTask>")]
    order = [block.index(t) for t in (
        "<bpmn:documentation", "<bpmn:extensionElements", "<bpmn:incoming",
        "<bpmn:property", "<bpmn:multiInstanceLoopCharacteristics")]
    assert order == sorted(order), block


# ── T-4389: foreign attributes + original prefixes survive, text-stable ──────

CAMUNDA = "http://camunda.org/schema/1.0/bpmn"


def _foreign_attr_xml():
    return FOREIGN_HEAD + (
        f'<bpmn:serviceTask id="s1" name="svc" xmlns:camunda="{CAMUNDA}" '
        'camunda:asyncBefore="true"><bpmn:extensionElements>'
        '<aef:uid value="u1"/><zeebe:taskDefinition type="work"/>'
        "</bpmn:extensionElements></bpmn:serviceTask>"
    ) + TAIL


def test_foreign_attribute_and_declaration_survive_round_trip():
    spec = corpus_spec.parse_map(_foreign_attr_xml())
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert 'camunda:asyncBefore="true"' in out
    assert f'xmlns:camunda="{CAMUNDA}"' in out
    spec2 = corpus_spec.parse_map(out)
    assert spec2["nodes"] == spec["nodes"]
    again = corpus_spec.emit_map(spec2, version=1, compat_alias=False)
    assert corpus_spec.canonical(again) == corpus_spec.canonical(out)


def test_foreign_attribute_and_ext_child_keep_original_prefix_text_stable():
    out = corpus_spec.emit_map(corpus_spec.parse_map(_foreign_attr_xml()),
                               version=1, compat_alias=False)
    assert "ns0:" not in out and "xmlns:ns0" not in out
    assert "<zeebe:taskDefinition" in out
    again = corpus_spec.emit_map(corpus_spec.parse_map(out), version=1,
                                 compat_alias=False)
    assert again == out
