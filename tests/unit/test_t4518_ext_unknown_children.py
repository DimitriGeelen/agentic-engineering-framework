"""T-4518: unknown content inside / beside aef: extension elements is carried
verbatim through derive (parse_map) → generate (emit_map), or refused naming the
element — never dropped silently (the T-4502 rule).

Origin: 832 T-1243 (msg 19354f92) — their designer keeps unknown child elements
of aef:io through a save; this pins that AEF corpus_spec does the same, and
closes the silent drops the probe found: content inside structured elements,
unknown siblings at process and lane level, and known names in a context that
does not read them.
"""

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_spec  # noqa: E402

U = "11111111-2222-3333-4444-555555555555"
_IDX = {"by_id": {"m": U}, "by_uuid": {U: "m"}}

HEAD = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'xmlns:aef="http://anchorpoint.framework/aef/extensions" xmlns:z="urn:t4518" '
    'id="Definitions_x" targetNamespace="https://aef.anchorpoint.dev/workflows">'
    '<bpmn:process id="Process_x" isExecutable="true">'
)
TAIL = "</bpmn:process></bpmn:definitions>"
WM = '<aef:workflowMeta id="m" version="1" schemaVersion="2" title="m" tier_default="1"/>'

NESTED_IO = ('<aef:io kind="call"><aef:input name="x">'
             '<aef:nested q="1">deep <z:leaf z:a="2">leaf</z:leaf> tail</aef:nested>'
             '</aef:input><aef:output name="y"/></aef:io>')


@pytest.fixture(autouse=True)
def _hermetic_store(monkeypatch):
    monkeypatch.setattr(corpus_spec, "store_index", lambda store=None: _IDX)


def _doc(proc_ext="", lane_ext="", node="", flow_ext=""):
    return (HEAD + f"<bpmn:extensionElements>{WM}{proc_ext}</bpmn:extensionElements>"
            '<bpmn:laneSet id="LS"><bpmn:lane id="l1" name="L1"><bpmn:extensionElements>'
            f'<aef:laneMeta abbr="a" authority="x"/>{lane_ext}</bpmn:extensionElements>'
            "<bpmn:flowNodeRef>n1</bpmn:flowNodeRef></bpmn:lane></bpmn:laneSet>"
            + (node or '<bpmn:task id="n1"><bpmn:extensionElements><aef:uid value="u"/>'
               "</bpmn:extensionElements></bpmn:task>")
            + '<bpmn:task id="n2"/>'
            f'<bpmn:sequenceFlow id="f1" sourceRef="n1" targetRef="n2">'
            f'<bpmn:extensionElements><aef:uid value="fu"/>{flow_ext}'
            "</bpmn:extensionElements></bpmn:sequenceFlow>" + TAIL)


def _round_trip(xml):
    spec = corpus_spec.parse_map(xml)
    out = corpus_spec.emit_map(spec, compat_alias=False)
    again = corpus_spec.parse_map(out)
    again.pop("pool_name", None)  # the emitter always writes a participant
    assert again == spec, "second pass must parse identically"
    return spec, out


def _raw_for(container, needle):
    return next(r for r in container["ext_raw"] if needle in r)


def test_nested_unknown_child_of_aef_io_round_trips_verbatim():
    node = ('<bpmn:task id="n1"><bpmn:extensionElements><aef:uid value="u"/>'
            f"{NESTED_IO}</bpmn:extensionElements></bpmn:task>")
    spec, out = _round_trip(_doc(node=node))
    raw = _raw_for(next(n for n in spec["nodes"] if n["id"] == "n1"), "aef:io")
    # namespace, attributes, text, tail text and child order all survive
    for part in ('kind="call"', '<aef:input name="x">', '<aef:nested q="1">deep ',
                 '<z:leaf z:a="2">leaf</z:leaf> tail', '<aef:output name="y"'):
        assert part in raw and part in out, part
    assert raw.index("aef:input") < raw.index("aef:output")


def test_unknown_siblings_at_process_and_lane_level_round_trip():
    spec, out = _round_trip(_doc(proc_ext='<aef:procNote k="v"><z:deep>t</z:deep></aef:procNote>',
                                 lane_ext="<aef:laneNote>hi<aef:sub/></aef:laneNote>"))
    assert "z:deep" in _raw_for(spec, "procNote") and "<z:deep>t</z:deep>" in out
    assert "<aef:sub" in _raw_for(spec["lanes"][0], "laneNote") and ">hi<aef:sub" in out


def test_known_name_in_a_context_that_does_not_read_it_rides_ext_raw():
    node = ('<bpmn:task id="n1"><bpmn:extensionElements><aef:uid value="u"/>'
            f'<aef:callRef workflowRef="{U}"/></bpmn:extensionElements></bpmn:task>')
    spec, out = _round_trip(_doc(node=node, flow_ext='<aef:position x="1" y="2"/>'))
    assert "callRef" in _raw_for(next(n for n in spec["nodes"] if n["id"] == "n1"), "callRef")
    assert "position" in _raw_for(spec["flows"][0], "position")
    assert out.count("aef:callRef") == 1 and 'x="1"' in out


def test_unmodelled_plain_attributes_on_structured_elements_round_trip():
    xml = _doc(node='<bpmn:task id="n1"><bpmn:extensionElements>'
                    '<aef:uid value="u" note="kept"/><aef:position x="1" y="2" z="3"/>'
                    "</bpmn:extensionElements></bpmn:task>",
               flow_ext="").replace(WM, WM.replace("/>", f' uuid="{U}"/>'))
    spec, out = _round_trip(xml)
    assert spec["ext_attrs"] == {"workflowMeta": {"uuid": U}}
    assert f'uuid="{U}"' in out and 'note="kept"' in out and 'z="3"' in out


@pytest.mark.parametrize("node, named", [
    ('<aef:meta k="v"><aef:mc><aef:inner/></aef:mc></aef:meta>', "aef:meta carries child <mc>"),
    ('<aef:meta k="v">text</aef:meta>', "aef:meta carries text"),
    ('<aef:position x="1" y="2"><aef:pc/></aef:position>', "aef:position carries child <pc>"),
    ('<aef:meta z:k="v"/>', "aef:meta carries attribute {urn:t4518}k"),
    ('<aef:uid value="a"/><aef:uid value="b"/>', "aef:uid more than once"),
])
def test_content_inside_a_structured_element_is_refused_naming_it(node, named):
    xml = _doc(node=f'<bpmn:task id="n1"><bpmn:extensionElements>{node}'
                    "</bpmn:extensionElements></bpmn:task>")
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(xml)
    assert named in str(e.value) and 'id="n1"' in str(e.value)


@pytest.mark.parametrize("inner, named", [
    ('<aef:in source="a" target="b"/><aef:other/>', "<other"),
    ('<aef:in source="a" target="b"><aef:expr/></aef:in>', "<in source target>"),
    ('text<aef:in source="a" target="b"/>', "text or a comment"),
    ('<!-- c --><aef:in source="a" target="b"/>', "text or a comment"),
])
def test_unknown_content_in_io_mapping_is_refused_naming_it(inner, named):
    node = (f'<bpmn:callActivity id="n1" calledElement="m"><bpmn:extensionElements>'
            f'<aef:callRef workflowRef="{U}"/><aef:ioMapping>{inner}</aef:ioMapping>'
            "</bpmn:extensionElements></bpmn:callActivity>")
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(_doc(node=node))
    assert "aef:ioMapping" in str(e.value) and named in str(e.value)
