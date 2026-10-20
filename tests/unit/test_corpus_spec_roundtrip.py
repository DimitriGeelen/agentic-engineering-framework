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
    # T-4505 made every BPMN 2.0 process flow node supported; the guarantee is
    # pinned on a tag outside the BPMN vocabulary altogether.
    xml = HEAD + '<bpmn:mysteryNode id="mystery_node"/>' + TAIL
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(xml)
    msg = str(e.value)
    assert "mysteryNode" in msg and "mystery_node" in msg


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


# ── T-4374: bpmn:callActivity, round-trip only (832 mapping v1, proposal C) ──

OTHER_UUID = "22222222-2222-4222-8222-222222222222"
_CALL_IDX = {"by_id": {"live-map": LIVE_UUID, "other-map": OTHER_UUID},
             "by_uuid": {LIVE_UUID: "live-map", OTHER_UUID: "other-map"}}


def _call_xml(called="live-map", ref=LIVE_UUID, io=None):
    io = io if io is not None else (
        "<aef:ioMapping>"
        '<aef:in source="task_id" target="parent_task"/>'
        '<aef:out source="verdict" target="review_verdict"/>'
        '<aef:in source="arc" target="arc_id"/>'
        "</aef:ioMapping>")
    ref_part = f'<aef:callRef workflowRef="{ref}"/>' if ref else ""
    called_part = f' calledElement="{called}"' if called else ""
    return HEAD + (
        f'<bpmn:callActivity id="c1" name="run review"{called_part}>'
        '<bpmn:extensionElements><aef:uid value="u1"/>'
        f"{io}{ref_part}</bpmn:extensionElements>"
        "</bpmn:callActivity>"
    ) + TAIL


def test_call_activity_parses_called_element_io_mapping_and_call_ref(monkeypatch):
    monkeypatch.setattr(corpus_spec, "store_index", lambda store=None: _CALL_IDX)
    n = corpus_spec.parse_map(_call_xml())["nodes"][0]
    assert n["type"] == "call" and n["called_element"] == "live-map"
    assert n["call_ref"] == LIVE_UUID
    assert n["io_mapping"] == {
        "in": [{"source": "task_id", "target": "parent_task"},
               {"source": "arc", "target": "arc_id"}],
        "out": [{"source": "verdict", "target": "review_verdict"}]}
    assert "ext_raw" not in n  # structured, not passed through verbatim


def test_call_activity_round_trips_losslessly(monkeypatch):
    monkeypatch.setattr(corpus_spec, "store_index", lambda store=None: _CALL_IDX)
    spec = corpus_spec.parse_map(_call_xml())
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert 'calledElement="live-map"' in out
    assert f'<aef:callRef workflowRef="{LIVE_UUID}"/>' in out
    # callRef is a SIBLING of ioMapping, never inside it
    io_block = out[out.index("<aef:ioMapping>"):out.index("</aef:ioMapping>")]
    assert "callRef" not in io_block
    spec2 = corpus_spec.parse_map(out)
    assert spec2["nodes"] == spec["nodes"]
    assert corpus_spec.canonical(out) == corpus_spec.canonical(
        corpus_spec.emit_map(spec2, version=1, compat_alias=False))


def test_call_activity_without_call_ref_is_valid_and_round_trips(monkeypatch):
    monkeypatch.setattr(corpus_spec, "store_index", lambda store=None: _CALL_IDX)
    spec = corpus_spec.parse_map(_call_xml(ref=None))
    assert "call_ref" not in spec["nodes"][0]
    assert corpus_spec.call_findings(spec) == []
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert "callRef" not in out
    assert corpus_spec.parse_map(out)["nodes"] == spec["nodes"]


@pytest.mark.parametrize("io", [
    '<aef:ioMapping><aef:in source="a" target="b" expression="${a}"/></aef:ioMapping>',
    '<aef:ioMapping><aef:in source="a"/></aef:ioMapping>',
    '<aef:ioMapping><aef:script>a = b</aef:script></aef:ioMapping>',
])
def test_call_activity_io_mapping_outside_v1_is_a_hard_error(monkeypatch, io):
    monkeypatch.setattr(corpus_spec, "store_index", lambda store=None: _CALL_IDX)
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(_call_xml(io=io))
    assert "ioMapping" in str(e.value) and "c1" in str(e.value)


def test_call_findings_unresolved_called_element_is_an_error(monkeypatch):
    monkeypatch.setattr(corpus_spec, "store_index", lambda store=None: _CALL_IDX)
    spec = corpus_spec.parse_map(_call_xml(called="no-such-map", ref=None))
    (f,) = corpus_spec.call_findings(spec)
    assert f["level"] == "error" and "no-such-map" in f["message"]
    with pytest.raises(SystemExit) as e:
        corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert "no-such-map" in str(e.value)


def test_call_findings_unknown_workflow_ref_is_an_error(monkeypatch):
    monkeypatch.setattr(corpus_spec, "store_index", lambda store=None: _CALL_IDX)
    ghost = "33333333-3333-4333-8333-333333333333"
    spec = corpus_spec.parse_map(_call_xml(ref=ghost))
    (f,) = corpus_spec.call_findings(spec)
    assert f["level"] == "error" and ghost in f["message"]


def test_call_findings_disagreement_names_both_sides_and_rewrites_nothing(monkeypatch):
    monkeypatch.setattr(corpus_spec, "store_index", lambda store=None: _CALL_IDX)
    spec = corpus_spec.parse_map(_call_xml(called="live-map", ref=OTHER_UUID))
    (f,) = corpus_spec.call_findings(spec)
    assert f["level"] == "finding"
    assert "live-map" in f["message"] and OTHER_UUID in f["message"]
    assert "other-map" in f["message"]
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)  # not refused
    assert 'calledElement="live-map"' in out
    assert f'workflowRef="{OTHER_UUID}"' in out


def test_validate_verb_exit_codes(monkeypatch, tmp_path, capsys):
    monkeypatch.setattr(corpus_spec, "store_index", lambda store=None: _CALL_IDX)
    good = tmp_path / "good.bpmn"
    good.write_text(_call_xml())
    assert corpus_spec.main(["validate", str(good)]) == 0
    assert "no call findings" in capsys.readouterr().out
    disagree = tmp_path / "disagree.bpmn"
    disagree.write_text(_call_xml(ref=OTHER_UUID))
    assert corpus_spec.main(["validate", str(disagree)]) == 0
    assert "FINDING c1" in capsys.readouterr().out
    bad = tmp_path / "bad.bpmn"
    bad.write_text(_call_xml(called="no-such-map"))
    assert corpus_spec.main(["validate", str(bad)]) == 1
    assert "ERROR c1" in capsys.readouterr().out


# ── T-4399: standard BPMN default="<sequenceFlow id>" on gateways/activities ──

def _default_flow_xml(tag="exclusiveGateway", default="f2", f2_source="n1",
                      extra=""):
    default_part = f' default="{default}"' if default is not None else ""
    return HEAD + (
        f'<bpmn:{tag} id="n1" name="decide"{default_part}{extra}>'
        '<bpmn:extensionElements><aef:uid value="u1"/></bpmn:extensionElements>'
        f"</bpmn:{tag}>"
        '<bpmn:endEvent id="e1"/><bpmn:endEvent id="e2"/>'
        '<bpmn:sequenceFlow id="f1" sourceRef="n1" targetRef="e1"/>'
        f'<bpmn:sequenceFlow id="f2" sourceRef="{f2_source}" targetRef="e2"/>'
    ) + TAIL


@pytest.mark.parametrize("tag", ["exclusiveGateway", "serviceTask", "userTask",
                                 "scriptTask", "subProcess"])
def test_default_flow_round_trips_on_gateway_and_activities(tag):
    spec = corpus_spec.parse_map(_default_flow_xml(tag))
    n1 = next(n for n in spec["nodes"] if n["id"] == "n1")
    assert n1["default"] == "f2"
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert f'<bpmn:{tag} id="n1" name="decide" default="f2">' in out
    spec2 = corpus_spec.parse_map(out)
    assert spec2["nodes"] == spec["nodes"]
    assert corpus_spec.emit_map(spec2, version=1, compat_alias=False) == out


def test_default_flow_round_trips_on_call_activity(monkeypatch):
    monkeypatch.setattr(corpus_spec, "store_index", lambda store=None: _CALL_IDX)
    xml = _default_flow_xml("callActivity", extra=' calledElement="live-map"')
    spec = corpus_spec.parse_map(xml)
    assert spec["nodes"][0]["default"] == "f2"
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert 'default="f2"' in out
    assert corpus_spec.parse_map(out)["nodes"] == spec["nodes"]


def test_default_flow_naming_no_sequence_flow_is_a_hard_error():
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(_default_flow_xml(default="f9"))
    msg = str(e.value)
    assert "n1" in msg and "f9" in msg


def test_default_flow_from_another_node_is_a_hard_error():
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(_default_flow_xml(f2_source="e1"))
    msg = str(e.value)
    assert "n1" in msg and "f2" in msg and "e1" in msg


def test_default_flow_is_checked_at_emit_too():
    spec = corpus_spec.parse_map(_default_flow_xml())
    spec["nodes"][0]["default"] = "f1x"
    with pytest.raises(SystemExit) as e:
        corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert "n1" in str(e.value) and "f1x" in str(e.value)


def test_default_flow_on_non_carrier_and_non_bpmn_unprefixed_attrs_stay_dropped():
    xml = HEAD + (
        '<bpmn:startEvent id="s" default="f1" foo="bar"/>'
        '<bpmn:exclusiveGateway id="n1" default="f1" gatewayDirection="Diverging"/>'
        '<bpmn:endEvent id="e1"/>'
        '<bpmn:sequenceFlow id="f0" sourceRef="s" targetRef="n1"/>'
        '<bpmn:sequenceFlow id="f1" sourceRef="n1" targetRef="e1"/>'
    ) + TAIL
    spec = corpus_spec.parse_map(xml)
    by_id = {n["id"]: n for n in spec["nodes"]}
    assert "default" not in by_id["s"] and "attrs" not in by_id["s"]
    assert by_id["n1"]["default"] == "f1"
    # T-4505: gatewayDirection is BPMN schema (tGateway), so it is carried
    assert by_id["n1"]["attrs"] == {"gatewayDirection": "Diverging"}
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert "foo=" not in out and 'gatewayDirection="Diverging"' in out
    assert out.count(' default="') == 1  # not tier_default


# ── T-4488: plain bpmn:task (832 T-1215), round-trip only, never coerced ──

def _plain_task_xml():
    return HEAD + (
        '<bpmn:startEvent id="s1"><bpmn:outgoing>f1</bpmn:outgoing></bpmn:startEvent>'
        '<bpmn:task id="t1" name="Review draft">'
        '<bpmn:incoming>f1</bpmn:incoming><bpmn:outgoing>f2</bpmn:outgoing></bpmn:task>'
        '<bpmn:task id="t2"><bpmn:incoming>f2</bpmn:incoming>'
        '<bpmn:outgoing>f3</bpmn:outgoing></bpmn:task>'
        '<bpmn:endEvent id="e1"><bpmn:incoming>f3</bpmn:incoming></bpmn:endEvent>'
        '<bpmn:sequenceFlow id="f1" sourceRef="s1" targetRef="t1"/>'
        '<bpmn:sequenceFlow id="f2" sourceRef="t1" targetRef="t2"/>'
        '<bpmn:sequenceFlow id="f3" sourceRef="t2" targetRef="e1"/>'
    ) + TAIL


def test_plain_task_is_accepted_and_round_trips_with_its_count():
    src = _plain_task_xml()
    spec = corpus_spec.parse_map(src)  # 0 refusals: no SystemExit
    tasks = [n for n in spec["nodes"] if n["type"] == "task"]
    assert [n["id"] for n in tasks] == ["t1", "t2"]
    assert tasks[0]["name"] == "Review draft"
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    # same bpmn:task count, none converted to a typed task
    assert out.count("<bpmn:task ") == src.count("<bpmn:task ") == 2
    for typed in ("serviceTask", "userTask", "scriptTask"):
        assert f"<bpmn:{typed}" not in out
    spec2 = corpus_spec.parse_map(out)
    assert [n["type"] for n in spec2["nodes"]] == [n["type"] for n in spec["nodes"]]
    assert corpus_spec.emit_map(spec2, version=1, compat_alias=False) == out


# ── T-4495: bpmn:businessRuleTask (832 kitchen-sink.bpmn), round-trip only ──

def test_business_rule_task_is_accepted_and_round_trips():
    src = (_plain_task_xml()
           .replace("<bpmn:task ", "<bpmn:businessRuleTask ")
           .replace("</bpmn:task>", "</bpmn:businessRuleTask>"))
    spec = corpus_spec.parse_map(src)  # was: SystemExit "unsupported BPMN element"
    rules = [n for n in spec["nodes"] if n["type"] == "business-rule"]
    assert [n["id"] for n in rules] == ["t1", "t2"]
    assert rules[0]["name"] == "Review draft"
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert out.count("<bpmn:businessRuleTask ") == 2
    assert "<bpmn:task " not in out
    spec2 = corpus_spec.parse_map(out)
    assert [n["type"] for n in spec2["nodes"]] == [n["type"] for n in spec["nodes"]]
    assert spec2["flows"] == spec["flows"]
    assert corpus_spec.emit_map(spec2, version=1, compat_alias=False) == out


# ── T-4496: a spec with no id refuses with a message, not an AttributeError ──

@pytest.mark.parametrize("id_line", ["id: null\n", "", "id: ''\n", "id: '  '\n", "id: 7\n"])
def test_generate_missing_id_refuses_naming_the_id(tmp_path, id_line):
    p = tmp_path / "spec.yaml"
    p.write_text(id_line + "title: x\nlanes: []\nnodes: []\nflows: []\n")
    with pytest.raises(SystemExit) as e:
        corpus_spec.main(["generate", str(p)])
    msg = str(e.value)
    assert "needs an id" in msg and "`id:`" in msg


@pytest.mark.parametrize("body", ["", "- a\n", "just text\n"])
def test_generate_non_mapping_spec_refuses_naming_the_id(tmp_path, body):
    p = tmp_path / "spec.yaml"
    p.write_text(body)
    with pytest.raises(SystemExit) as e:
        corpus_spec.main(["generate", str(p)])
    assert "not a mapping" in str(e.value) and "`id:`" in str(e.value)


# ── T-4501: bpmn:boundaryEvent (832 boundary-events / kitchen-sink goldens) ──

GOLDENS = REPO_ROOT / "tests" / "fixtures" / "corpus-832-goldens"


def test_boundary_events_golden_derives_and_round_trips():
    src = (GOLDENS / "boundary-events.bpmn").read_text()
    spec = corpus_spec.parse_map(src)  # was: SystemExit "unsupported BPMN element"
    b = {n["id"]: n for n in spec["nodes"] if n["type"] == "boundary"}
    assert sorted(b) == ["lan_link_batman", "lan_link_superman", "lan_link_wonder"]
    assert b["lan_link_batman"]["attached_to"] == "lan_1_subprocess"
    assert b["lan_link_superman"]["attached_to"] == "lan_3_task"
    assert all(n["cancel_activity"] == "true" for n in b.values())
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert out.count("<bpmn:boundaryEvent ") == src.count("<bpmn:boundaryEvent ") == 3
    assert 'attachedToRef="lan_3_task" cancelActivity="true"' in out
    assert corpus_spec.canonical(out) == corpus_spec.canonical(src)
    spec2 = corpus_spec.parse_map(out)
    assert corpus_spec.emit_map(spec2, version=1, compat_alias=False) == out


def _boundary_xml(attrs='attachedToRef="t1" cancelActivity="false"'):
    return HEAD + (
        '<bpmn:startEvent id="s1"><bpmn:outgoing>f1</bpmn:outgoing></bpmn:startEvent>'
        '<bpmn:task id="t1"><bpmn:incoming>f1</bpmn:incoming></bpmn:task>'
        f'<bpmn:boundaryEvent id="b1" name="timeout" {attrs}>'
        '<bpmn:outgoing>f2</bpmn:outgoing>'
        '<bpmn:timerEventDefinition id="TED_1">'
        '<bpmn:timeDuration>PT5M</bpmn:timeDuration></bpmn:timerEventDefinition>'
        '</bpmn:boundaryEvent>'
        '<bpmn:endEvent id="e1"><bpmn:incoming>f2</bpmn:incoming></bpmn:endEvent>'
        '<bpmn:sequenceFlow id="f1" sourceRef="s1" targetRef="t1"/>'
        '<bpmn:sequenceFlow id="f2" sourceRef="b1" targetRef="e1"/>'
    ) + TAIL


def test_boundary_event_definition_and_non_interrupting_round_trip():
    src = _boundary_xml()
    spec = corpus_spec.parse_map(src)
    b = next(n for n in spec["nodes"] if n["id"] == "b1")
    assert b["cancel_activity"] == "false"
    assert len(b["raw_children"]) == 1 and "timerEventDefinition" in b["raw_children"][0]
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert 'attachedToRef="t1" cancelActivity="false"' in out
    assert "PT5M" in out and "<bpmn:outgoing>f2</bpmn:outgoing>" in out
    spec2 = corpus_spec.parse_map(out)
    assert spec2["nodes"] == spec["nodes"] and spec2["flows"] == spec["flows"]


def test_boundary_event_cancel_activity_absent_stays_absent():
    spec = corpus_spec.parse_map(_boundary_xml('attachedToRef="t1"'))
    b = next(n for n in spec["nodes"] if n["id"] == "b1")
    assert "cancel_activity" not in b
    assert "cancelActivity" not in corpus_spec.emit_map(spec, version=1, compat_alias=False)


@pytest.mark.parametrize("attrs", ['', 'attachedToRef="nope"', 'attachedToRef="s1"'])
def test_boundary_event_without_activity_host_is_a_hard_error(attrs):
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(_boundary_xml(attrs))
    assert "b1" in str(e.value) and "attachedToRef" in str(e.value)


def test_boundary_event_dangling_host_is_checked_at_emit_too():
    spec = corpus_spec.parse_map(_boundary_xml())
    next(n for n in spec["nodes"] if n["id"] == "b1")["attached_to"] = "gone"
    with pytest.raises(SystemExit) as e:
        corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert "generate" in str(e.value) and "gone" in str(e.value)


# ── T-4502: a second bpmn:process is refused, never dropped silently ──

_PROC2 = ('<process xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL" id="Proc_B">'
          '<task id="Task_B" name="B"/></process>')


def test_multiple_diagrams_golden_second_process_refuses_naming_it():
    src = (GOLDENS / "multiple-diagrams.bpmn").read_text()
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(src)  # was: exit 0, Task_B gone
    assert "'Process_2'" in str(e.value) and "2 <bpmn:process>" in str(e.value)


def test_inline_second_process_refuses_and_derive_exits_nonzero(tmp_path):
    src = _plain_task_xml() + ""
    src = src.replace("</bpmn:definitions>", _PROC2 + "</bpmn:definitions>")
    p = tmp_path / "two.bpmn"
    p.write_text(src)
    with pytest.raises(SystemExit) as e:
        corpus_spec.main(["derive", str(p)])
    assert "'Proc_B'" in str(e.value)


def test_empty_second_process_shell_is_dropped_with_a_warning(capsys):
    shell = ('<process xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL" id="Proc_E" '
             'name="Hauptprozess"><documentation/><laneSet id="LS_E"/></process>')
    src = _plain_task_xml().replace("</bpmn:definitions>", shell + "</bpmn:definitions>")
    spec = corpus_spec.parse_map(src)
    assert [n["id"] for n in spec["nodes"] if n["type"] == "task"] == ["t1", "t2"]
    assert "dropping empty process 'Proc_E'" in capsys.readouterr().err


def test_document_without_process_refuses():
    xml = ('<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
           'id="D"/>')
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(xml)
    assert "no <bpmn:process>" in str(e.value)


def test_single_process_map_is_unaffected(capsys):
    spec = corpus_spec.parse_map(_plain_task_xml())
    assert len(spec["nodes"]) == 4 and capsys.readouterr().err == ""


# ── T-4505: every BPMN 2.0 flow node is supported or refused by name ──

# BPMN 2.0 (formal/2011-01-03) §8.3.13 flow-node substitution group, all of it:
# tActivity / tEvent / tGateway / tChoreographyActivity subclasses.
BPMN_FLOW_NODES = [
    "task", "sendTask", "receiveTask", "serviceTask", "userTask", "manualTask",
    "scriptTask", "businessRuleTask", "subProcess", "adHocSubProcess",
    "transaction", "callActivity",
    "startEvent", "endEvent", "intermediateCatchEvent", "intermediateThrowEvent",
    "boundaryEvent", "implicitThrowEvent",
    "exclusiveGateway", "inclusiveGateway", "parallelGateway", "complexGateway",
    "eventBasedGateway",
    "choreographyTask", "subChoreography", "callChoreography",
]


def _single_node_xml(tag, attrs="", body=""):
    # one task host so a boundaryEvent has a legal attachedToRef
    host = '<bpmn:task id="host"/>' if tag == "boundaryEvent" else ""
    if tag == "boundaryEvent":
        attrs += ' attachedToRef="host"'
    if tag == "callActivity":
        attrs += ' calledElement="other-map"'
    return HEAD + host + f'<bpmn:{tag} id="n1" name="N"{attrs}>{body}</bpmn:{tag}>' + TAIL


@pytest.mark.parametrize("tag", BPMN_FLOW_NODES)
def test_every_bpmn_flow_node_is_supported_or_refused_by_name(tag, monkeypatch):
    monkeypatch.setattr(corpus_spec, "store_index", lambda store=None: _CALL_IDX)
    src = _single_node_xml(tag)
    if tag in corpus_spec.TAG_TO_TYPE:
        assert tag not in corpus_spec.REFUSED_FLOW_TAGS
        spec = corpus_spec.parse_map(src)
        n = next(n for n in spec["nodes"] if n["id"] == "n1")
        assert corpus_spec.TYPE_TO_TAG[n["type"]] == tag
        out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
        assert out.count(f"<bpmn:{tag} ") == 1
        assert corpus_spec.parse_map(out)["nodes"] == spec["nodes"]
    else:
        assert tag in corpus_spec.REFUSED_FLOW_TAGS, (
            f"{tag} is neither in TYPE_TO_TAG nor in REFUSED_FLOW_TAGS")
        with pytest.raises(SystemExit) as e:
            corpus_spec.parse_map(src)
        assert tag in str(e.value) and "n1" in str(e.value)


def test_bpmn_flow_node_table_is_the_whole_vocabulary():
    # a tag added to either table must also be on the spec list above
    known = set(corpus_spec.TAG_TO_TYPE) | set(corpus_spec.REFUSED_FLOW_TAGS)
    assert known == set(BPMN_FLOW_NODES)


NEW_FLOW_NODES = [
    # tag, type, plain attributes the parser does not model, verbatim children
    ("sendTask", "send", ' implementation="##WebService" messageRef="Msg_1"', ""),
    ("receiveTask", "receive", ' instantiate="true" messageRef="Msg_1"', ""),
    ("manualTask", "manual", "", "<bpmn:documentation>by hand</bpmn:documentation>"),
    ("inclusiveGateway", "inclusive-gateway", ' gatewayDirection="Diverging"', ""),
    ("complexGateway", "complex-gateway", "",
     '<bpmn:activationCondition xsi:type="bpmn:tFormalExpression">x</bpmn:activationCondition>'),
    ("eventBasedGateway", "event-gateway", ' instantiate="false" eventGatewayType="Exclusive"', ""),
    ("adHocSubProcess", "adhoc-subprocess", ' ordering="Sequential" cancelRemainingInstances="true"',
     '<bpmn:task id="inner"/><bpmn:completionCondition>done</bpmn:completionCondition>'),
    ("transaction", "transaction", ' method="##Compensate"', '<bpmn:task id="inner"/>'),
]


@pytest.mark.parametrize("tag,ntype,attrs,body", NEW_FLOW_NODES)
def test_new_flow_node_round_trips_losslessly(tag, ntype, attrs, body):
    src = HEAD.replace("<bpmn:definitions ",
                       '<bpmn:definitions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ') + (
        '<bpmn:startEvent id="s1"><bpmn:outgoing>f1</bpmn:outgoing></bpmn:startEvent>'
        f'<bpmn:{tag} id="n1" name="N"{attrs}><bpmn:incoming>f1</bpmn:incoming>'
        f'<bpmn:outgoing>f2</bpmn:outgoing>{body}</bpmn:{tag}>'
        '<bpmn:endEvent id="e1"><bpmn:incoming>f2</bpmn:incoming></bpmn:endEvent>'
        '<bpmn:sequenceFlow id="f1" sourceRef="s1" targetRef="n1"/>'
        '<bpmn:sequenceFlow id="f2" sourceRef="n1" targetRef="e1"/>'
    ) + TAIL
    spec = corpus_spec.parse_map(src)  # was: SystemExit "unsupported BPMN element"
    n = next(n for n in spec["nodes"] if n["id"] == "n1")
    assert n["type"] == ntype and n["name"] == "N"
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert out.count(f"<bpmn:{tag} ") == 1
    for attr in attrs.split():
        assert attr in out, f"{attr} dropped on round trip"
    for marker in ("by hand", "activationCondition", 'id="inner"', "completionCondition"):
        if marker in body:
            assert marker in out
    spec2 = corpus_spec.parse_map(out)
    assert spec2["nodes"] == spec["nodes"] and spec2["flows"] == spec["flows"]
    assert corpus_spec.emit_map(spec2, version=1, compat_alias=False) == out


@pytest.mark.parametrize("tag", ["sendTask", "receiveTask", "manualTask",
                                 "adHocSubProcess", "transaction"])
def test_new_activity_is_a_boundary_host(tag):
    src = HEAD + (f'<bpmn:{tag} id="t1"/>'
                  '<bpmn:boundaryEvent id="b1" attachedToRef="t1"/>') + TAIL
    spec = corpus_spec.parse_map(src)
    assert next(n for n in spec["nodes"] if n["id"] == "b1")["attached_to"] == "t1"


def test_new_types_have_lint_occupancy():
    import corpus_lint
    missing = set(corpus_spec.TYPE_TO_TAG) - set(corpus_lint.NODE_OCCUPANCY)
    assert not missing
