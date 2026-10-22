"""T-4551: the forward compiler (tools/bpmn_to_tasks.py) reads structured aef:io.

Standard: policy/standards/aef-bpmn-mapping-v1.1-io.md. Covers every §11 worked example,
the §2.3 `ref` read rule, §2.5 system derivation, §3 type defaults/aliases, the §1.5
version refusal, §1.4 verbatim carry of unknown children, the §4.3/§4.4 warnings, and
that a node with no aef:io renders byte-identically to the pre-T-4551 compiler.
"""
import os
import subprocess
import sys

import pytest
import yaml

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))

import bpmn_to_tasks  # noqa: E402

FIXTURE = os.path.join(REPO_ROOT, "tests", "fixtures", "bpmn", "two-lane-sample.bpmn")

BPMN = "http://www.omg.org/spec/BPMN/20100524/MODEL"
AEF = "http://agentic-engineering.dev/aef"


def _map(tmp_path, io_xml: str, proc_meta: str = "", step_meta: str = "",
         name: str = "m.bpmn") -> str:
    xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="{BPMN}" xmlns:aef="{AEF}" id="d">
  <bpmn:process id="p">
    <bpmn:extensionElements>{proc_meta}</bpmn:extensionElements>
    <bpmn:startEvent id="s"/>
    <bpmn:serviceTask id="t1" name="Step">
      <bpmn:extensionElements>
        <aef:uid value="u1"/>{step_meta}
        <aef:io>{io_xml}</aef:io>
      </bpmn:extensionElements>
    </bpmn:serviceTask>
    <bpmn:sequenceFlow id="f1" sourceRef="s" targetRef="t1"/>
  </bpmn:process>
</bpmn:definitions>
"""
    path = tmp_path / name
    path.write_text(xml, encoding="utf-8")
    return str(path)


V11 = '<aef:meta mappingVersion="1.1"><aef:prefixes>' \
      '<aef:prefix name="sfdc" iri="urn:sfdc#" system="sys:salesforce" kind="field"/>' \
      '<aef:prefix name="tacton" iri="urn:tacton#" system="sys:tacton" kind="type"/>' \
      '</aef:prefixes></aef:meta>'


def _compile(path):
    sks, warns = bpmn_to_tasks.parse_bpmn(path)
    assert len(sks) == 1
    return sks[0], warns


def _frontmatter(sk) -> dict:
    text = bpmn_to_tasks.render_skeleton(sk)
    assert text.startswith("---\n") and text.endswith("---\n")
    return yaml.safe_load(text[4:-4])


# ── §11 worked examples ─────────────────────────────────────────────────────

def test_upsert_with_field_roles(tmp_path):
    p = _map(tmp_path, """
      <aef:output typeRef="tacton:Opportunity" operation="upsert">
        <aef:field fieldRef="tacton:Opportunity.crmOppExtId" role="match"/>
        <aef:field fieldRef="tacton:Opportunity.name" role="write"/>
        <aef:field fieldRef="tacton:Opportunity.accountId" role="create"/>
      </aef:output>""", V11)
    sk, warns = _compile(p)
    (item,) = sk["io"]
    assert item["kind"] == "output"
    assert item["attrs"] == {"typeRef": "tacton:Opportunity", "operation": "upsert"}
    assert "type" not in item  # typeRef present: no string default (§2.2)
    assert [f["attrs"]["role"] for f in item["fields"]] == ["match", "write", "create"]
    assert item["targetSystem"] == "sys:tacton" and item["system_from"] == "prefix"
    assert not [w for w in warns if "§4" in w]
    fm = _frontmatter(sk)
    assert fm["io"][0]["fields"][0]["attrs"]["fieldRef"] == "tacton:Opportunity.crmOppExtId"


def test_field_selection_with_target_system(tmp_path):
    p = _map(tmp_path, """
      <aef:output typeRef="sfdc:Account" targetSystem="sys:salesforce" operation="create">
        <aef:field fieldRef="sfdc:Account.Name" role="write"/>
        <aef:field path="Phone" role="write"/>
        <aef:field path="OwnerId" role="write" required="true"/>
      </aef:output>""", V11)
    sk, warns = _compile(p)
    (item,) = sk["io"]
    assert item["targetSystem"] == "sys:salesforce" and item["system_from"] == "attribute"
    assert item["fields"][2]["attrs"] == {"path": "OwnerId", "role": "write", "required": "true"}
    assert not [w for w in warns if "§4" in w]
    assert _frontmatter(sk)["io"][0]["fields"][1]["attrs"]["path"] == "Phone"


def test_style_b_postcondition(tmp_path):
    p = _map(tmp_path, """
      <aef:output typeRef="sfdc:Opportunity" operation="update">
        <aef:field fieldRef="sfdc:Opportunity.Id" role="match"/>
        <aef:expect path="StageName" const="Closed Won"/>
      </aef:output>""", V11)
    sk, warns = _compile(p)
    (item,) = sk["io"]
    assert item["expects"] == [{"attrs": {"path": "StageName", "const": "Closed Won"}}]
    assert not [w for w in warns if "§4" in w]
    text = bpmn_to_tasks.render_skeleton(sk)
    assert ('# postcondition: [NEEDS-FILL] output sfdc:Opportunity: '
            'path StageName const="Closed Won"') in text


def test_soft_and_hard_delete(tmp_path):
    p = _map(tmp_path, """
      <aef:output typeRef="sfdc:Contact" operation="update">
        <aef:field fieldRef="sfdc:Contact.Id" role="match"/>
        <aef:expect path="Status" const="archived"/>
      </aef:output>
      <aef:output typeRef="sfdc:Contact" operation="delete">
        <aef:field fieldRef="sfdc:Contact.Id" role="match"/>
        <aef:expect fieldRef="sfdc:Contact.Id" absent="true"/>
      </aef:output>""", V11)
    sk, warns = _compile(p)
    assert [i["attrs"]["operation"] for i in sk["io"]] == ["update", "delete"]
    assert not [w for w in warns if "§4" in w]
    text = bpmn_to_tasks.render_skeleton(sk)
    assert 'path Status const="archived"' in text
    assert 'fieldRef sfdc:Contact.Id absent="true"' in text
    assert len(_frontmatter(sk)["io"]) == 2


# ── read rules ──────────────────────────────────────────────────────────────

def test_input_precondition_and_enum_values(tmp_path):
    p = _map(tmp_path, """
      <aef:input fieldRef="sfdc:Opportunity.StageName">
        <aef:expect><aef:value>Open</aef:value><aef:value>Won</aef:value></aef:expect>
        <aef:example path="Amount" value="12500"/>
      </aef:input>""", V11)
    sk, _ = _compile(p)
    (item,) = sk["io"]
    assert item["expects"][0]["values"] == ["Open", "Won"]
    assert item["examples"] == [{"attrs": {"path": "Amount", "value": "12500"}}]
    assert item["sourceSystem"] == "sys:salesforce"  # §2.5 via the fieldRef prefix
    text = bpmn_to_tasks.render_skeleton(sk)
    assert '# precondition: [NEEDS-FILL] input sfdc:Opportunity.StageName: enum=["Open", "Won"]' in text


def test_when_child_on_field(tmp_path):
    p = _map(tmp_path, """
      <aef:input typeRef="sfdc:Quote">
        <aef:field path="LineItems[]"><aef:when path="Kind" const="TradeIn"/></aef:field>
      </aef:input>""", V11)
    sk, _ = _compile(p)
    f = sk["io"][0]["fields"][0]
    assert f["when"] == [{"attrs": {"path": "Kind", "const": "TradeIn"}}]


@pytest.mark.parametrize("typ,expected", [
    (None, "string"), ("int", "number"), ("bool", "boolean"),
    ("enum", "enum"), ("money", "money"), ("list", "list"),
])
def test_type_default_and_aliases(tmp_path, typ, expected):
    attr = f' type="{typ}"' if typ else ""
    p = _map(tmp_path, f'<aef:input name="x"{attr}/>')
    sk, _ = _compile(p)
    assert sk["io"][0]["type"] == expected
    assert sk["io"][0]["attrs"].get("type") == typ  # verbatim attribute kept


def test_ref_read_as_fieldref_only_under_all_four_conditions(tmp_path):
    v10_prefixes = ('<aef:meta><aef:prefixes><aef:prefix name="sfdc" iri="urn:s#" '
                    'kind="field"/><aef:prefix name="obj" iri="urn:o#" kind="object"/>'
                    '</aef:prefixes></aef:meta>')
    p = _map(tmp_path, """
      <aef:input ref="sfdc:Account.Name"/>
      <aef:input ref="obj:Account"/>
      <aef:input ref="sfdc:Account.Phone" typeRef="sfdc:Account"/>
      <aef:input ref="nope:Thing"/>""", v10_prefixes)
    sk, _ = _compile(p)
    a, b, c, d = sk["io"]
    assert a["fieldRef"] == "sfdc:Account.Name" and a["fieldRef_from"] == "ref"
    assert "fieldRef" not in b  # prefix kind is not field
    assert "fieldRef" not in c  # typeRef present
    assert "fieldRef" not in d  # prefix undeclared
    # condition 1: a v1.1 map never reads ref as fieldRef
    p11 = _map(tmp_path, '<aef:input ref="sfdc:Account.Name"/>', V11, name="v11.bpmn")
    sk11, _ = _compile(p11)
    assert "fieldRef" not in sk11["io"][0]


def test_system_precedence_attribute_step_prefix(tmp_path):
    step = '<aef:meta sourceSystem="sys:step" targetSystem="sys:step-out"/>'
    p = _map(tmp_path, """
      <aef:input fieldRef="sfdc:A.x" sourceSystem="sys:explicit"/>
      <aef:input fieldRef="sfdc:A.y"/>
      <aef:output typeRef="tacton:Opp" operation="create"/>""", V11, step)
    sk, _ = _compile(p)
    a, b, c = sk["io"]
    assert (a["sourceSystem"], a["system_from"]) == ("sys:explicit", "attribute")
    assert (b["sourceSystem"], b["system_from"]) == ("sys:step", "step")
    assert (c["targetSystem"], c["system_from"]) == ("sys:step-out", "step")
    p2 = _map(tmp_path, '<aef:input fieldRef="sfdc:A.y"/>', V11, name="noStep.bpmn")
    sk2, _ = _compile(p2)
    assert (sk2["io"][0]["sourceSystem"], sk2["io"][0]["system_from"]) == \
        ("sys:salesforce", "prefix")


def test_unknown_children_and_attributes_carried_verbatim(tmp_path):
    p = _map(tmp_path, """
      <aef:input name="x" futureAttr="keep">
        <aef:futureChild k="v"/>
      </aef:input>
      <aef:futureIo a="b"/>""")
    sk, _ = _compile(p)
    inp, other = sk["io"]
    assert inp["attrs"]["futureAttr"] == "keep"
    assert len(inp["raw"]) == 1 and "futureChild" in inp["raw"][0] and 'k="v"' in inp["raw"][0]
    assert other["kind"] == "futureIo" and 'a="b"' in other["raw"]
    assert _frontmatter(sk)["io"][1]["kind"] == "futureIo"


def test_text_outside_value_is_refused(tmp_path):
    p = _map(tmp_path, '<aef:input name="x">stray</aef:input>')
    with pytest.raises(bpmn_to_tasks.IoTextError, match="aef:input"):
        bpmn_to_tasks.parse_bpmn(p)


# ── refusal and warnings ───────────────────────────────────────────────────

def test_unknown_mapping_version_refused_naming_value(tmp_path):
    p = _map(tmp_path, '<aef:input name="x"/>', '<aef:meta mappingVersion="9.9"/>')
    with pytest.raises(bpmn_to_tasks.UnsupportedMappingVersionError, match="'9.9'"):
        bpmn_to_tasks.parse_bpmn(p)
    r = subprocess.run([sys.executable, os.path.join(REPO_ROOT, "tools", "bpmn_to_tasks.py"), p],
                       capture_output=True, text=True, timeout=60)
    assert r.returncode == 3 and "9.9" in r.stderr and r.stdout == ""


@pytest.mark.parametrize("op", ["update", "upsert", "delete"])
def test_keyed_operation_without_match_warns(tmp_path, op):
    p = _map(tmp_path, f"""
      <aef:output typeRef="sfdc:Contact" operation="{op}">
        <aef:field fieldRef="sfdc:Contact.Name" role="write"/>
      </aef:output>""", V11)
    _, warns = _compile(p)
    assert any("§4.3" in w and op in w for w in warns)


def test_create_without_match_does_not_warn(tmp_path):
    p = _map(tmp_path, '<aef:output typeRef="sfdc:Contact" operation="create"/>', V11)
    _, warns = _compile(p)
    assert not any("§4.3" in w for w in warns)


def test_undetermined_match_key_warns(tmp_path):
    p = _map(tmp_path, """
      <aef:output typeRef="sfdc:Contact" operation="update">
        <aef:field role="match"/>
      </aef:output>""", V11)
    _, warns = _compile(p)
    assert any("§4.4" in w for w in warns)
    assert not any("§4.3" in w for w in warns)


# ── io-free nodes unchanged ────────────────────────────────────────────────

def test_io_free_node_renders_byte_identically_to_pre_t4551():
    """The committed fixture has no aef:io: its compile must not change at all."""
    sks, _ = bpmn_to_tasks.parse_bpmn(FIXTURE)
    assert sks and all("io" not in s for s in sks)
    for s in sks:
        text = bpmn_to_tasks.render_skeleton(s)
        assert "io:" not in text and "condition:" not in text
    expected = (
        "---\n"
        f"id: {sks[0]['uid']}\n"
        f'name: "{sks[0]["name"]}"\n'
        f"owner: {sks[0]['owner']}\n"
        f"workflow_type: {sks[0]['workflow_type']}\n"
        f"tier: {sks[0]['tier']}\n"
        f"horizon: {sks[0]['horizon']}\n"
        f"related_tasks: [{', '.join(sks[0]['related_tasks'])}]\n"
        "status: captured\n"
        "# acceptance_criteria: [NEEDS-FILL] — seed T-193 Agent/Human split before start\n"
        "---\n"
    )
    assert bpmn_to_tasks.render_skeleton(sks[0]) == expected


def test_proposal_rendering_still_marks_proposal_with_io(tmp_path):
    p = _map(tmp_path, '<aef:input name="x"/>')
    sk, _ = _compile(p)
    text = bpmn_to_tasks.render_proposal(sk)
    assert "status: proposal\n" in text and "status: captured" not in text
    assert yaml.safe_load(text.split("---\n")[1])["io"][0]["type"] == "string"
