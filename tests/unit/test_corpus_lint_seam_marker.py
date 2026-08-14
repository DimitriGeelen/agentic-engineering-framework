"""T-2989: the seamPending marker must be provably load-bearing.

`emitterless-typed-event` was retired on `aef-dispatch-loop@v3` by recording a judgement —
`agt_4_worker` carries an `aef:meta seamPending` naming TermLink as the out-of-corpus
emitter — rather than by changing the rule. That distinction is invisible from the outside:
a suppressed finding and a rule that quietly stopped firing produce the same clean scan.

So these assert the marker in BOTH directions on a synthetic map. Without them, a later
refactor could break the emitterless rule outright and every corpus test would still pass,
because the only real-corpus instance is the one now marked.

The live-corpus counterpart lives in test_corpus_lint.py::test_live_corpus_current_findings
(pinned empty) — that one proves the served corpus is clean; these prove clean means
"judged", not "unchecked".
"""

import pathlib
import sys

import pytest

sys.path.insert(0, "tools")
import corpus_lint  # noqa: E402

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent


def _map(seam_attr=""):
    """A minimal map with one typed catch and no typed throw anywhere."""
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
                  xmlns:aef="http://anchorpoint.framework/aef/extensions"
                  id="Definitions_seam" targetNamespace="https://aef.anchorpoint.dev/workflows">
  <bpmn:process id="Process_seam" isExecutable="true">
    <bpmn:extensionElements>
      <aef:workflowMeta id="seam-fixture" version="1" schemaVersion="2" title="seam" tier_default="1"/>
    </bpmn:extensionElements>
    <bpmn:startEvent id="n_start" name="start">
      <bpmn:extensionElements><aef:uid value="sf_s"/><aef:position x="100.0" y="100.0"/></bpmn:extensionElements>
      <bpmn:outgoing>f1</bpmn:outgoing>
    </bpmn:startEvent>
    <bpmn:intermediateCatchEvent id="n_catch" name="result on bus">
      <bpmn:extensionElements>
        <aef:uid value="sf_c"/>
        <aef:position x="300.0" y="100.0"/>
        <aef:meta note="a note that is not a seam marker"{seam_attr}/>
        <aef:eventDef kind="message" binding="bus:seam-fixture-channel"/>
      </bpmn:extensionElements>
      <bpmn:incoming>f1</bpmn:incoming>
      <bpmn:outgoing>f2</bpmn:outgoing>
    </bpmn:intermediateCatchEvent>
    <bpmn:endEvent id="n_end" name="end">
      <bpmn:extensionElements><aef:uid value="sf_e"/><aef:position x="500.0" y="100.0"/></bpmn:extensionElements>
      <bpmn:incoming>f2</bpmn:incoming>
    </bpmn:endEvent>
    <bpmn:sequenceFlow id="f1" sourceRef="n_start" targetRef="n_catch">
      <bpmn:extensionElements><aef:uid value="sf_f1"/></bpmn:extensionElements>
    </bpmn:sequenceFlow>
    <bpmn:sequenceFlow id="f2" sourceRef="n_catch" targetRef="n_end">
      <bpmn:extensionElements><aef:uid value="sf_f2"/></bpmn:extensionElements>
    </bpmn:sequenceFlow>
  </bpmn:process>
</bpmn:definitions>
"""


def _emitterless(xml_text):
    findings, typed = corpus_lint.lint_map("seam-fixture@v1", xml_text, {}, set())
    findings.extend(corpus_lint.cross_map_typed_events(typed))
    return [f for f in findings if f["rule"] == "emitterless-typed-event"]


def test_unmarked_typed_catch_reports():
    """Positive control. If this ever goes quiet the rule is broken, and the live
    corpus can no longer be read as evidence of anything."""
    found = _emitterless(_map())
    assert len(found) == 1, found
    assert found[0]["node"] == "n_catch"
    assert "bus:seam-fixture-channel" in found[0]["detail"]


def test_seam_marker_suppresses_the_finding():
    assert _emitterless(_map(seam_attr=' seamPending="emitter is out of scope"')) == []


def test_an_ordinary_note_does_not_suppress():
    """The marker must be the specific attribute, not any prose on the node.
    Both maps here carry an aef:meta note; only one carries seamPending."""
    assert len(_emitterless(_map())) == 1


def test_empty_seam_marker_does_not_suppress():
    """`seamPending=""` records no judgement, so it must not buy silence —
    otherwise the cheapest way past the rule is an empty string."""
    assert len(_emitterless(_map(seam_attr=' seamPending=""'))) == 1


def test_the_live_marker_is_present_and_explains_itself():
    """The real instance this task retired. A marker whose text is generic records
    that someone silenced the rule, not why — which is the failure mode the marker
    exists to prevent, so assert it names the emitter."""
    p = REPO_ROOT / ".context" / "designer" / "projects" / "aef-dispatch-loop" / "v3.bpmn"
    if not p.exists():
        pytest.skip("aef-dispatch-loop@v3 not in this checkout")
    text = p.read_text()
    assert "seamPending=" in text, "the T-2989 seam marker is gone — finding will return"
    assert "TermLink" in text, (
        "the seam marker no longer names the out-of-corpus emitter; a generic "
        "marker records suppression rather than a judgement"
    )
