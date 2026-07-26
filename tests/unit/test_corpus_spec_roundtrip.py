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
    assert "hum_3_inception" in ids
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
