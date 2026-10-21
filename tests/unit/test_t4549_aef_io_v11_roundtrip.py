"""T-4549: corpus_spec models mapping v1.1 aef:io and the process aef:meta.

policy/standards/aef-bpmn-mapping-v1.1-io.md (T-4548) adds attributes on
aef:input / aef:output, child aef:field (with aef:when), aef:expect (with
aef:value), aef:example, and mappingVersion + aef:prefixes on the process-level
aef:meta. These tests pin that parse_map reads every one of them into the spec,
that emit_map writes them back byte-stable (emit → parse → emit is a fixed
point), and that a v1.0 map's bytes are exactly what the verbatim ext_raw path
produced before aef:io was modelled.
"""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_spec  # noqa: E402

AEF = "{http://anchorpoint.framework/aef/extensions}"
BPMN = "{http://www.omg.org/spec/BPMN/20100524/MODEL}"

HEAD = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'xmlns:aef="http://anchorpoint.framework/aef/extensions" id="Definitions_x" '
    'targetNamespace="https://aef.anchorpoint.dev/workflows">\n'
    '<bpmn:process id="Process_x" isExecutable="true">\n'
)
TAIL = "</bpmn:process>\n</bpmn:definitions>\n"
WM = '<aef:workflowMeta id="m" version="1" schemaVersion="2" title="m" tier_default="1"/>'

V11_META = """<aef:meta mappingVersion="1.1">
        <aef:prefixes>
          <aef:prefix name="sfdc" iri="https://example.org/sfdc#" system="sys:salesforce" kind="field"/>
          <aef:prefix name="tacton" iri="https://example.org/tacton#" kind="type"/>
        </aef:prefixes>
      </aef:meta>"""

# §11 worked examples, verbatim from the standard.
H042 = """<aef:output typeRef="tacton:Opportunity" operation="upsert">
  <aef:field fieldRef="tacton:Opportunity.crmOppExtId" role="match"/>
  <aef:field fieldRef="tacton:Opportunity.name" role="write"/>
  <aef:field fieldRef="tacton:Opportunity.accountId" role="create"/>
</aef:output>"""
ACCOUNT = """<aef:output typeRef="sfdc:Account" targetSystem="sys:salesforce" operation="create">
  <aef:field fieldRef="sfdc:Account.Name" role="write"/>
  <aef:field path="Phone" role="write"/>
  <aef:field path="OwnerId" role="write" required="true"/>
</aef:output>"""
STYLE_B = """<aef:output typeRef="sfdc:Opportunity" operation="update">
  <aef:field fieldRef="sfdc:Opportunity.Id" role="match"/>
  <aef:expect path="StageName" const="Closed Won"/>
</aef:output>"""
DELETES = """<aef:output typeRef="sfdc:Contact" operation="update">
  <aef:field fieldRef="sfdc:Contact.Id" role="match"/>
  <aef:expect path="Status" const="archived"/>
</aef:output>
<aef:output typeRef="sfdc:Contact" operation="delete">
  <aef:field fieldRef="sfdc:Contact.Id" role="match"/>
  <aef:expect fieldRef="sfdc:Contact.Id" absent="true"/>
</aef:output>"""
# Every other v1.1 construct the standard names: all §2 attributes, aef:when
# (5.3), enum with aef:value children (§8), ruleRef (8.4), aef:example (§9).
FULL = """<aef:input name="opp" typeRef="sf:Opportunity" sourceSystem="sys:crm" required="true" cardinality="one" conceptRef="biz:Deal" ref="nid:x" dataType="id">
  <aef:field path="LineItems[]" cardinality="many"><aef:when path="Kind" const="TradeIn"/></aef:field>
  <aef:expect path="Status"><aef:value>Won</aef:value><aef:value>Closed Won</aef:value></aef:expect>
  <aef:expect path="Amount" minimum="10000" exclusiveMaximum="1e9" pattern="^[0-9]+$"/>
  <aef:expect path="Notes" description="free text" ruleRef="rules:notes" ruleLanguage="shacl" present="true"/>
  <aef:example path="Amount" value="12500"/>
</aef:input>
<aef:input fieldRef="sfdc:Opportunity.Id" role="read" type="ref"/>
<aef:output schemaRef="https://example.org/s.json" operation="read" targetSystem="sys:erp"/>"""


@pytest.fixture(autouse=True)
def _hermetic_store(monkeypatch):
    monkeypatch.setattr(corpus_spec, "store_index",
                        lambda store=None: {"by_id": {}, "by_uuid": {}})


def _doc(io_inner, meta=V11_META, before="", after=""):
    return (HEAD + f"<bpmn:extensionElements>{WM}{meta}</bpmn:extensionElements>\n"
            '<bpmn:serviceTask id="n1" name="step"><bpmn:extensionElements>'
            f'<aef:uid value="u"/>{before}<aef:io>{io_inner}</aef:io>{after}'
            "</bpmn:extensionElements></bpmn:serviceTask>\n" + TAIL)


def _fixed_point(xml):
    """parse → emit → parse → emit: the two specs and the two emits must match."""
    spec = corpus_spec.parse_map(xml)
    out = corpus_spec.emit_map(spec, compat_alias=False)
    spec2 = corpus_spec.parse_map(out)
    out2 = corpus_spec.emit_map(spec2, compat_alias=False)
    if "pool_name" not in spec:
        spec2.pop("pool_name", None)  # the emitter always writes a participant
    assert spec2 == spec, "second parse must equal the first"
    assert out2 == out, "second emit must be byte-identical to the first"
    return spec, out


def _io(spec):
    return next(n for n in spec["nodes"] if n["id"] == "n1")["io"]


def test_h042_upsert_parses_and_round_trips():
    spec, out = _fixed_point(_doc(H042))
    (item,) = _io(spec)["items"]
    assert item["kind"] == "output"
    assert item["attrs"] == {"typeRef": "tacton:Opportunity", "operation": "upsert"}
    assert [f["attrs"] for f in item["fields"]] == [
        {"fieldRef": "tacton:Opportunity.crmOppExtId", "role": "match"},
        {"fieldRef": "tacton:Opportunity.name", "role": "write"},
        {"fieldRef": "tacton:Opportunity.accountId", "role": "create"},
    ]
    assert 'operation="upsert"' in out and 'role="create"' in out


@pytest.mark.parametrize("example", [ACCOUNT, STYLE_B, DELETES], ids=["create", "style-b", "deletes"])
def test_section_11_examples_round_trip(example):
    spec, out = _fixed_point(_doc(example))
    items = _io(spec)["items"]
    src = ET.fromstring(f'<aef:io xmlns:aef="{AEF[1:-1]}">{example}</aef:io>')
    assert [i["attrs"] for i in items] == [dict(o.attrib) for o in src]
    for item, o in zip(items, src):
        assert [f["attrs"] for f in item.get("fields", [])] == [
            dict(f.attrib) for f in o.findall(AEF + "field")]
        assert [e["attrs"] for e in item.get("expects", [])] == [
            dict(e.attrib) for e in o.findall(AEF + "expect")]


def test_every_v11_construct_is_modelled_not_raw():
    spec, out = _fixed_point(_doc(FULL))
    first, second, third = _io(spec)["items"]
    assert first["attrs"]["cardinality"] == "one" and first["attrs"]["dataType"] == "id"
    assert first["fields"][0]["when"] == [{"attrs": {"path": "Kind", "const": "TradeIn"}}]
    assert first["expects"][0] == {"attrs": {"path": "Status"}, "values": ["Won", "Closed Won"]}
    assert first["expects"][2]["attrs"]["ruleLanguage"] == "shacl"
    assert first["examples"] == [{"attrs": {"path": "Amount", "value": "12500"}}]
    assert second["attrs"] == {"fieldRef": "sfdc:Opportunity.Id", "role": "read", "type": "ref"}
    assert third["attrs"]["schemaRef"] == "https://example.org/s.json"
    for entry in (first, second, third, *first["fields"], *first["expects"]):
        assert "raw" not in entry
    assert "<aef:value>Closed Won</aef:value>" in out


def test_process_meta_mapping_version_and_prefix_map():
    spec, out = _fixed_point(_doc(H042))
    assert "ext_raw" not in spec
    assert corpus_spec.mapping_version(spec) == "1.1"
    pm = corpus_spec.prefix_map(spec)
    assert pm["sfdc"] == {"name": "sfdc", "iri": "https://example.org/sfdc#",
                          "system": "sys:salesforce", "kind": "field"}
    assert pm["tacton"]["kind"] == "type"
    assert 'mappingVersion="1.1"' in out and "<aef:prefixes>" in out


def test_prefixes_without_mapping_version_is_a_v10_map():
    meta = V11_META.replace(' mappingVersion="1.1"', "")
    spec, _ = _fixed_point(_doc('<aef:input name="x" ref="sfdc:Account.Id"/>', meta=meta))
    assert corpus_spec.mapping_version(spec) is None
    assert set(corpus_spec.prefix_map(spec)) == {"sfdc", "tacton"}


def test_unknown_mapping_version_is_refused_naming_it():
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(_doc(H042, meta='<aef:meta mappingVersion="2.0"/>'))
    assert "2.0" in str(e.value) and "1.5" in str(e.value)


def test_text_inside_a_modelled_element_is_refused_not_dropped():
    with pytest.raises(SystemExit) as e:
        corpus_spec.parse_map(_doc('<aef:output typeRef="t">stray<aef:field path="a"/></aef:output>'))
    assert "aef:io > aef:output" in str(e.value) and 'id="n1"' in str(e.value)


def test_unknown_children_ride_raw_in_place_of_their_parent():
    spec, out = _fixed_point(_doc(
        '<aef:output typeRef="t"><aef:field path="a"><aef:future x="1"/></aef:field>'
        '<aef:shape/></aef:output><aef:note/>'))
    io = _io(spec)
    assert io["raw"][0].startswith("<aef:note")
    assert io["items"][0]["raw"][0].startswith("<aef:shape")
    assert io["items"][0]["fields"][0]["raw"][0].startswith("<aef:future")


def test_io_keeps_its_slot_among_unknown_siblings():
    spec, out = _fixed_point(_doc('<aef:input name="x"/>', before="<aef:endpoint>e</aef:endpoint>",
                                  after='<aef:contextReads paths="p"/>'))
    node = next(n for n in spec["nodes"] if n["id"] == "n1")
    assert node["io_at"] == 1
    assert out.index("aef:endpoint") < out.index("<aef:io") < out.index("aef:contextReads")


# ── v1.0 control: bytes identical to the pre-T-4549 verbatim ext_raw path ────

def _old_raw_io_blocks(xml):
    """What emit_map wrote for each node's aef:io before T-4549: the element
    serialized verbatim (corpus_spec._raw_xml) — the reference bytes."""
    root = ET.fromstring(xml)
    return [corpus_spec._raw_xml(io) for io in root.iter(AEF + "io")]


def test_v10_dispatch_loop_fixture_io_bytes_unchanged():
    xml = (REPO_ROOT / "tests/fixtures/aef-bpmn/dispatch-loop.bpmn").read_text()
    spec, out = _fixed_point(xml)
    assert corpus_spec.mapping_version(spec) is None and "process_meta" not in spec
    old = _old_raw_io_blocks(xml)
    assert len(old) >= 3
    for block in old:
        assert f"        {block}\n" in out, block


def test_v10_control_map_round_trips_unchanged():
    io = ('\n          <aef:input name="task_id" type="task_id" required="true"/>'
          '\n          <aef:output name="deliverables" type="list"/>\n        ')
    xml = _doc(io, meta="")
    spec, out = _fixed_point(xml)
    assert "process_meta" not in spec
    (block,) = _old_raw_io_blocks(xml)
    assert f"        {block}\n" in out
