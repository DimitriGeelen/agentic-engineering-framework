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
    # T-4374 made callActivity supported; the guarantee is pinned on a tag
    # that is still outside TYPE_TO_TAG.
    xml = HEAD + '<bpmn:complexGateway id="mystery_node"/>' + TAIL
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(xml)
    msg = str(e.value)
    assert "complexGateway" in msg and "mystery_node" in msg


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


def test_default_flow_on_non_carrier_and_other_unprefixed_attrs_stay_dropped():
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
    assert by_id["n1"]["default"] == "f1" and "attrs" not in by_id["n1"]
    out = corpus_spec.emit_map(spec, version=1, compat_alias=False)
    assert "foo=" not in out and "gatewayDirection" not in out
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
