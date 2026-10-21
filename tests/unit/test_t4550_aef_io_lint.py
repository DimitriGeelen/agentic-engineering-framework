"""T-4550: corpus_lint rules for mapping v1.1 aef:io.

policy/standards/aef-bpmn-mapping-v1.1-io.md: §4.3 (keyed operation needs a match
field), §4.4 (undetermined match key, warning), §8.6 (expectation contradicting /
implied by the type), §6.2/§6.3 (prefix kinds, undeclared prefixes), §2.3 (the
`ref` read rule). One test per rule, a clean-map control built from the
standard's own §11 worked examples, and the warning/exit-code contract.
"""

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_lint  # noqa: E402
import corpus_spec  # noqa: E402

HEAD = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'xmlns:aef="http://anchorpoint.framework/aef/extensions" id="Definitions_x" '
    'targetNamespace="https://aef.anchorpoint.dev/workflows">\n'
    '<bpmn:process id="Process_x" isExecutable="true">\n'
)
TAIL = "</bpmn:process>\n</bpmn:definitions>\n"
WM = '<aef:workflowMeta id="m" version="1" schemaVersion="2" title="m" tier_default="1"/>'


def _meta(version='mappingVersion="1.1"', extra=""):
    return (f'<aef:meta {version}><aef:prefixes>'
            '<aef:prefix name="sfdc" iri="https://example.org/sfdc#" kind="field"/>'
            '<aef:prefix name="tacton" iri="https://example.org/tacton#"/>'
            '<aef:prefix name="sft" iri="https://example.org/sft#" kind="type"/>'
            f'{extra}</aef:prefixes></aef:meta>')


def _doc(io_inner, meta=None):
    meta = _meta() if meta is None else meta
    return (HEAD + f"<bpmn:extensionElements>{WM}{meta}</bpmn:extensionElements>\n"
            '<bpmn:serviceTask id="n1" name="step"><bpmn:extensionElements>'
            f'<aef:io>{io_inner}</aef:io></bpmn:extensionElements></bpmn:serviceTask>\n'
            + TAIL)


@pytest.fixture(autouse=True)
def _hermetic_store(monkeypatch):
    monkeypatch.setattr(corpus_spec, "store_index",
                        lambda store=None: {"by_id": {}, "by_uuid": {}})


def _io(io_inner, meta=None):
    return corpus_lint.io_v11("m", _doc(io_inner, meta))


def _rules(findings):
    return sorted((f["rule"], f["severity"]) for f in findings)


# Clean control: the §11 worked examples, verbatim apart from prefix choice.
CLEAN = """<aef:output typeRef="tacton:Opportunity" operation="upsert">
  <aef:field fieldRef="tacton:Opportunity.crmOppExtId" role="match"/>
  <aef:field fieldRef="tacton:Opportunity.name" role="write"/>
  <aef:field fieldRef="tacton:Opportunity.accountId" role="create"/>
</aef:output>
<aef:output typeRef="sft:Opportunity" operation="update">
  <aef:field fieldRef="sfdc:Opportunity.Id" role="match"/>
  <aef:expect path="StageName" const="Closed Won"/>
</aef:output>
<aef:output typeRef="sft:Contact" operation="delete">
  <aef:field fieldRef="sfdc:Contact.Id" role="match" required="true"/>
  <aef:expect fieldRef="sfdc:Contact.Id" absent="true"/>
</aef:output>
<aef:input fieldRef="sfdc:Opportunity.Amount" role="read" type="int">
  <aef:expect minimum="0" const="12500"/>
</aef:input>
<aef:input fieldRef="https://example.org/sfdc#Opportunity.Id" role="read" type="ref"/>"""


def test_clean_map_control():
    assert _io(CLEAN) == []
    assert corpus_lint.lint_map("m", _doc(CLEAN), {"by_id": {}, "by_uuid": {}},
                                set(), editor_resolves_uuid=True)[0] == []


@pytest.mark.parametrize("op", ["update", "upsert", "delete"])
def test_keyed_operation_without_match_field_is_error(op):
    f = _io(f'<aef:output typeRef="sft:Contact" operation="{op}">'
            '<aef:field fieldRef="sfdc:Contact.Name" role="write"/></aef:output>')
    assert _rules(f) == [("io-operation-no-match", "error")]
    assert f'"{op} everything"' in f[0]["detail"]


def test_read_and_create_need_no_match_field():
    assert _io('<aef:output typeRef="sft:A" operation="create"/>'
               '<aef:input typeRef="sft:A" operation="read"/>') == []


def test_match_field_with_no_key_is_warning():
    f = _io('<aef:output typeRef="sft:Contact" operation="update">'
            '<aef:field role="match"/></aef:output>')
    assert _rules(f) == [("io-match-undetermined", "warning")]


def test_expect_contradicting_type_is_error():
    f = _io('<aef:input fieldRef="sfdc:Opportunity.Amount" type="number">'
            '<aef:expect fieldRef="sfdc:Opportunity.Amount" const="lots"/></aef:input>')
    assert _rules(f) == [("io-expect-contradicts-type", "error")]


def test_absent_on_required_field_is_error_outside_delete():
    f = _io('<aef:output typeRef="sft:Contact" operation="update">'
            '<aef:field fieldRef="sfdc:Contact.Id" role="match" required="true"/>'
            '<aef:expect fieldRef="sfdc:Contact.Id" absent="true"/></aef:output>')
    assert _rules(f) == [("io-expect-contradicts-type", "error")]


def test_expect_implied_by_type_is_warning():
    f = _io('<aef:input fieldRef="sfdc:Contact.Active" type="bool">'
            '<aef:expect><aef:value>true</aef:value><aef:value>false</aef:value>'
            '</aef:expect></aef:input>'
            '<aef:output typeRef="sft:Contact" operation="update">'
            '<aef:field fieldRef="sfdc:Contact.Id" role="match"/>'
            '<aef:field path="Owner" required="true"/>'
            '<aef:expect path="Owner" present="true"/></aef:output>')
    assert _rules(f) == [("io-expect-implied-by-type", "warning")] * 2


def test_typeref_member_is_never_judged():
    # The member's type lives in the ontology; an informational `type` does not count.
    assert _io('<aef:input typeRef="sft:Opp" type="number" operation="read">'
               '<aef:expect path="Amount" const="lots"/></aef:input>') == []


def test_unknown_prefix_is_error():
    f = _io('<aef:input fieldRef="nope:Thing.Id" role="read"/>'
            '<aef:input typeRef="sft:Thing" conceptRef="biz:Deal" operation="read"/>')
    assert _rules(f) == [("io-prefix-unknown", "error")] * 2


def test_prefix_of_wrong_kind_is_error():
    f = _io('<aef:input fieldRef="sft:Thing.Id" role="read"/>'
            '<aef:output typeRef="sfdc:Account" operation="create"/>')
    assert _rules(f) == [("io-prefix-kind", "error")] * 2


def test_ref_read_rule_applies_only_per_2_3():
    v10 = _meta(version="")
    # ref is a v1 data-object identity unless all four §2.3 conditions hold:
    # an undeclared or non-field prefix, and any ref in a v1.1 map, is left alone.
    assert _io('<aef:input ref="nope:x" type="number">'
               '<aef:expect const="lots"/></aef:input>', v10) == []
    assert _io('<aef:input ref="sft:x" type="number">'
               '<aef:expect const="lots"/></aef:input>', v10) == []
    assert _io('<aef:input ref="sfdc:Opp.Amount" type="number">'
               '<aef:expect const="lots"/></aef:input>') == []
    # All four hold (v1.0 map, no fieldRef/typeRef, kind="field"): ref is a fieldRef.
    f = _io('<aef:input ref="sfdc:Opp.Amount" type="number">'
            '<aef:expect fieldRef="sfdc:Opp.Amount" const="lots"/></aef:input>', v10)
    assert _rules(f) == [("io-expect-contradicts-type", "error")]


def test_warnings_alone_exit_zero_errors_exit_one(tmp_path, capsys):
    warn = tmp_path / "warn.bpmn"
    warn.write_text(_doc('<aef:output typeRef="sft:C" operation="update">'
                         '<aef:field role="match"/></aef:output>'))
    err = tmp_path / "err.bpmn"
    err.write_text(_doc('<aef:output typeRef="sft:C" operation="delete"/>'))
    store = tmp_path / "store"
    store.mkdir()
    assert corpus_lint.main([str(warn), "--store", str(store)]) == 0
    assert "WARN [io-match-undetermined]" in capsys.readouterr().out
    assert corpus_lint.main([str(err), "--store", str(store)]) == 1
