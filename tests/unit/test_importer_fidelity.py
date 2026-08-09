"""T-2882 — a CONTENT census of what our BPMN importer does with what it does not consume.

832 asked (DM rail 484): on meeting an element, attribute or sub-tree it has no field
for, does the importer (a) preserve it verbatim and re-emit, (b) consume what it
understands and drop the rest, or (c) refuse? This module measures the answer instead
of asserting it.

Why a *content* census and not a structural one — 832's sharpest line of the week: an
element that survives with its body stripped keeps its node, flow and lane counts. A
structural census literally cannot represent the defect, so it reads exactly like a
census that found nothing. Every probe below therefore carries a unique SENTINEL string
and asks where that string ended up, not how many elements survived.

Method: differential compile. Take one fixture, mutate exactly one position, compile
both, compare (stdout, stderr, exit code). The classification is derived from the
comparison — no probe has a hand-written expected verdict that could drift away from
what the compiler actually does.

Two controls make the negatives mean something:

  NULL control     adding only an unused xmlns declaration must NOT change the output.
                   Without it, "the foreign-element probe changed nothing" is
                   ambiguous between the element being dropped and the declaration
                   being what mattered.

  POSITIVE control mutating a position the compiler demonstrably consumes MUST change
                   the output. Without it, every "identical output" reading is equally
                   consistent with a harness that never ran the compiler at all — the
                   failure mode that made a scan-contamination bug look like a working
                   fix during T-2881.
"""

from __future__ import annotations

import os
import subprocess
import sys
from dataclasses import dataclass

import pytest

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(os.path.dirname(_HERE))
COMPILER = os.path.join(_ROOT, "tools", "bpmn_to_tasks.py")
FIXTURE = os.path.join(_ROOT, "tests", "fixtures", "bpmn", "two-lane-sample.bpmn")

# Namespace declaration the foreign-namespace probes need. Declaring a prefix is not
# content — the NULL control proves the declaration alone moves nothing.
VENDOR_NS = 'xmlns:vendor="http://example.invalid/vendor"\n                  '
_DEFS_ANCHOR = 'xmlns:aef="http://agentic.dev/schema/aef"\n                  '


def _with_vendor_ns(xml: str) -> str:
    assert _DEFS_ANCHOR in xml, "definitions anchor not found — probe would be a no-op"
    return xml.replace(_DEFS_ANCHOR, _DEFS_ANCHOR + VENDOR_NS, 1)


# The one node every probe hangs content off, so positions are comparable to each other.
_TASK_OPEN = '<bpmn:userTask id="Task_review" name="Review proposal">'
_TASK_EXT = """      <bpmn:extensionElements>
        <aef:uid>u-review-001</aef:uid>
      </bpmn:extensionElements>"""


# --- verdict vocabulary -----------------------------------------------------
# Deliberately finer than 832's three options. Their (b) does not distinguish a drop
# the operator is told about from one they are not, and that distinction is the whole
# difference between a fidelity gap and a silent one.
PRESERVED = "preserved"  # (a) — the sentinel is re-emitted verbatim
DROPPED_SILENT = "dropped-silently"  # (b) — output byte-identical, nothing said
DROPPED_NOTICED = "dropped-with-notice"  # (b) — dropped, but stderr says so
CONSUMED = "consumed"  # read into typed state; output moved
REFUSED = "refused"  # (c) — non-zero exit


@dataclass(frozen=True)
class Probe:
    name: str
    position: str  # where the content sits, in the input's terms
    sentinel: str
    mutate: object  # (xml: str) -> str


def _p(name, position, sentinel, mutate):
    return Probe(name=name, position=position, sentinel=sentinel, mutate=mutate)


PROBES: list[Probe] = [
    _p(
        "foreign-element-in-consumed-node",
        "a foreign-namespace child of a node the compiler DOES read",
        "SENTINEL-FOREIGN-ELEM",
        lambda x: _with_vendor_ns(x).replace(
            _TASK_EXT,
            _TASK_EXT + '\n      <vendor:note>SENTINEL-FOREIGN-ELEM</vendor:note>',
            1,
        ),
    ),
    _p(
        "foreign-attribute-on-consumed-node",
        "a foreign-namespace attribute on a node the compiler DOES read",
        "SENTINEL-FOREIGN-ATTR",
        lambda x: _with_vendor_ns(x).replace(
            _TASK_OPEN,
            '<bpmn:userTask id="Task_review" name="Review proposal" '
            'vendor:priority="SENTINEL-FOREIGN-ATTR">',
            1,
        ),
    ),
    _p(
        "text-in-consumed-element",
        "loose text inside a known tag (832's T-347 shape)",
        "SENTINEL-INNER-TEXT",
        lambda x: x.replace(_TASK_OPEN, _TASK_OPEN + "SENTINEL-INNER-TEXT", 1),
    ),
    _p(
        "standard-bpmn-documentation",
        "<bpmn:documentation> — standard BPMN, no field for it here",
        "SENTINEL-DOCUMENTATION",
        lambda x: x.replace(
            _TASK_OPEN,
            _TASK_OPEN
            + "\n      <bpmn:documentation>SENTINEL-DOCUMENTATION</bpmn:documentation>",
            1,
        ),
    ),
    _p(
        "unknown-child-of-a-branch-we-read",
        "an unrecognised child INSIDE <extensionElements>, which we do descend into",
        "SENTINEL-EXT-CHILD",
        lambda x: x.replace(
            "<aef:uid>u-review-001</aef:uid>",
            "<aef:uid>u-review-001</aef:uid>\n"
            "        <aef:notARealThing>SENTINEL-EXT-CHILD</aef:notARealThing>",
            1,
        ),
    ),
    _p(
        "unread-node-type",
        "a whole BPMN node type outside TASK_TAGS (businessRuleTask)",
        "SENTINEL-UNREAD-NODE",
        lambda x: x.replace(
            "<bpmn:endEvent",
            '<bpmn:businessRuleTask id="Task_rule" name="SENTINEL-UNREAD-NODE">\n'
            "      <bpmn:extensionElements>\n"
            "        <aef:uid>u-rule-004</aef:uid>\n"
            "      </bpmn:extensionElements>\n"
            "    </bpmn:businessRuleTask>\n\n    <bpmn:endEvent",
            1,
        ),
    ),
    _p(
        "diagram-geometry",
        "BPMNDI layout — the exact position 832's T-340 ruled CONSUME on",
        "SENTINEL-DI-GEOMETRY",
        lambda x: x.replace(
            "</bpmn:definitions>",
            '  <bpmndi:BPMNDiagram xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI"\n'
            '                      xmlns:dc="http://www.omg.org/spec/DD/20100524/DC"\n'
            '                      id="SENTINEL-DI-GEOMETRY">\n'
            '    <bpmndi:BPMNPlane id="Plane_1" bpmnElement="Proc_sample">\n'
            '      <bpmndi:BPMNShape id="Shape_review" bpmnElement="Task_review">\n'
            '        <dc:Bounds x="100" y="80" width="100" height="80"/>\n'
            "      </bpmndi:BPMNShape>\n"
            "    </bpmndi:BPMNPlane>\n"
            "  </bpmndi:BPMNDiagram>\n</bpmn:definitions>",
            1,
        ),
    ),
    _p(
        "foreign-top-level-subtree",
        "a foreign-namespace sub-tree hanging off <definitions>",
        "SENTINEL-TOP-SUBTREE",
        lambda x: _with_vendor_ns(x).replace(
            "</bpmn:definitions>",
            "  <vendor:catalog>\n"
            "    <vendor:entry key=\"k\">SENTINEL-TOP-SUBTREE</vendor:entry>\n"
            "  </vendor:catalog>\n</bpmn:definitions>",
            1,
        ),
    ),
    _p(
        "content-on-an-element-read-for-another-fact",
        "documentation on a <lane> — the lane IS read, but for authority only",
        "SENTINEL-LANE-DOC",
        lambda x: x.replace(
            '<bpmn:lane id="Lane_human" name="Human">',
            '<bpmn:lane id="Lane_human" name="Human">\n'
            "        <bpmn:documentation>SENTINEL-LANE-DOC</bpmn:documentation>",
            1,
        ),
    ),
]

# Mutations in positions the compiler is known to read. If any of these fails to move
# the output, every "identical" reading above is vacuous.
POSITIVE_CONTROLS: list[Probe] = [
    _p(
        "control-lane-membership",
        "moving a node between lanes (owner is compiled FROM the lane, IW-7)",
        "",
        lambda x: x.replace(
            "<bpmn:flowNodeRef>Task_review</bpmn:flowNodeRef>\n        ", "", 1
        ).replace(
            '<bpmn:lane id="Lane_agent" name="Agent">',
            '<bpmn:lane id="Lane_agent" name="Agent">\n'
            "        <bpmn:flowNodeRef>Task_review</bpmn:flowNodeRef>",
            1,
        ),
    ),
    _p(
        "control-aef-uid",
        "the aef:uid — the task's stable identity (IW-1)",
        "",
        lambda x: x.replace("u-review-001", "u-review-999", 1),
    ),
]

# Adding an unused namespace declaration is not content. If this moves the output, the
# foreign-namespace probes are measuring the declaration rather than the payload.
NULL_CONTROL = _p(
    "null-unused-xmlns",
    "an xmlns declaration nothing uses",
    "",
    _with_vendor_ns,
)


# --- measurement ------------------------------------------------------------


def _compile(xml: str, tmp_path) -> tuple[int, str, str]:
    """Run the compiler on `xml` from a directory with no designer store.

    cwd is the tmp dir on purpose: `_designer_store()` resolves `.context/designer/
    projects` relative to cwd, so running from the repo would let unrelated store
    contents perturb off-page-ref resolution between probes.
    """
    src = tmp_path / "probe.bpmn"
    src.write_text(xml)
    r = subprocess.run(
        [sys.executable, COMPILER, str(src)],
        cwd=str(tmp_path),
        capture_output=True,
        text=True,
    )
    return r.returncode, r.stdout, r.stderr


def _classify(base: tuple[int, str, str], mut: tuple[int, str, str], sentinel: str) -> str:
    b_rc, b_out, b_err = base
    m_rc, m_out, m_err = mut
    if m_rc != 0 and b_rc == 0:
        return REFUSED
    if sentinel and sentinel in m_out:
        return PRESERVED
    if m_out != b_out:
        return CONSUMED
    if m_err != b_err:
        return DROPPED_NOTICED
    return DROPPED_SILENT


@pytest.fixture(scope="module")
def baseline():
    return open(FIXTURE).read()


def measure(baseline_xml: str, tmp_path) -> dict[str, str]:
    """Run every probe and return {probe name: verdict}. Used by the report too."""
    base = _compile(baseline_xml, tmp_path)
    out = {}
    for probe in PROBES:
        mutated = probe.mutate(baseline_xml)
        assert mutated != baseline_xml, f"{probe.name}: mutation was a no-op"
        out[probe.name] = _classify(base, _compile(mutated, tmp_path), probe.sentinel)
    return out


# --- the controls, first ----------------------------------------------------


def test_the_compiler_runs_at_all(baseline, tmp_path):
    """SMOKE. Every reading below is about a compile that produced skeletons."""
    rc, out, _ = _compile(baseline, tmp_path)
    assert rc == 0
    assert "id: u-review-001" in out


def test_positive_controls_move_the_output(baseline, tmp_path):
    """A mutation the compiler DOES read must change what it emits.

    This is the leg that makes 'dropped-silently' mean something. Without it, a
    harness that silently failed to invoke the compiler would report every probe as
    dropped-silently — indistinguishable from the real finding.
    """
    base = _compile(baseline, tmp_path)
    for probe in POSITIVE_CONTROLS:
        mutated = probe.mutate(baseline)
        assert mutated != baseline, f"{probe.name}: mutation was a no-op"
        assert _compile(mutated, tmp_path)[1] != base[1], (
            f"{probe.name} did not move the output — the harness cannot see a "
            f"difference, so no negative result from it is trustworthy"
        )


def test_null_control_does_not_move_the_output(baseline, tmp_path):
    """An unused xmlns declaration is not content and must read as inert."""
    base = _compile(baseline, tmp_path)
    mutated = NULL_CONTROL.mutate(baseline)
    assert mutated != baseline
    assert _compile(mutated, tmp_path)[1] == base[1]


# --- the census -------------------------------------------------------------


def test_every_probe_is_classified(baseline, tmp_path):
    """No position may be left implicit — the enumeration is the deliverable."""
    verdicts = measure(baseline, tmp_path)
    assert set(verdicts) == {p.name for p in PROBES}
    assert all(v in {PRESERVED, DROPPED_SILENT, DROPPED_NOTICED, CONSUMED, REFUSED}
               for v in verdicts.values())


# The measured answer, pinned. This is not a hand-written expectation: it is what the
# probes above returned on 2026-08-09, recorded so that a later compiler change which
# moves any verdict turns this test red rather than quietly invalidating the answer we
# gave 832. If you are here because it went red: the answer we published moved. Update
# the report and tell them, then update this table — in that order.
MEASURED_2026_08_09 = {
    "foreign-element-in-consumed-node": DROPPED_SILENT,
    "foreign-attribute-on-consumed-node": DROPPED_SILENT,
    "text-in-consumed-element": DROPPED_SILENT,
    "standard-bpmn-documentation": DROPPED_SILENT,
    "unknown-child-of-a-branch-we-read": DROPPED_SILENT,
    "unread-node-type": DROPPED_SILENT,
    "diagram-geometry": DROPPED_SILENT,
    "foreign-top-level-subtree": DROPPED_SILENT,
    "content-on-an-element-read-for-another-fact": DROPPED_SILENT,
}


def test_measured_verdicts_have_not_moved(baseline, tmp_path):
    assert measure(baseline, tmp_path) == MEASURED_2026_08_09


# --- the other axis: what the importer INVENTS ------------------------------
# 832's rail 486 split loss from fabrication: what we drop is a fidelity question,
# what we invent is an accountability question about who owns a step. Measured
# separately because the two have different remedies and different owners.

# Frontmatter keys the compiler emits. Any key here whose value is not traceable to
# something the input states is fabricated — and `owner` is the one that decides
# accountability for the step.
FABRICATED_KEYS = {"workflow_type", "tier", "horizon", "status", "related_tasks"}
DERIVED_KEYS = {"owner"}  # not stated by the node; derived from its lane (IW-7)
SOURCED_KEYS = {"id", "name"}  # traceable to aef:uid and @name


def test_fabricated_fields_are_enumerated(baseline, tmp_path):
    """Every emitted key is accounted for as sourced, derived, or fabricated.

    A new key that is none of the three fails here — the point is that nothing gets
    added to the output without someone deciding which axis it lands on.
    """
    _, out, _ = _compile(baseline, tmp_path)
    emitted = {
        line.split(":", 1)[0].strip()
        for line in out.splitlines()
        if line and not line.startswith(("#", "-", " ")) and ":" in line
    }
    known = FABRICATED_KEYS | DERIVED_KEYS | SOURCED_KEYS
    assert emitted <= known, f"unaccounted emitted key(s): {sorted(emitted - known)}"
    # And the fabricated ones really are absent from the input.
    src = open(FIXTURE).read()
    for key in ("workflow_type", "horizon", "tier"):
        assert key not in src, f"{key} appears in the input — it is not fabricated"


def test_owner_is_derived_not_stated(baseline, tmp_path):
    """`owner` is the accountability field, and no node states it.

    IW-7 makes the lane the authority-of-record, so this is derivation rather than
    invention — but it is derivation the diagram author cannot see in the node, which
    is exactly why 832 want it on a separate axis from loss.

    Asserted against the parsed tree, not the raw text: the fixture's XML *comments*
    use the word "owner" to explain the lane rules, and a substring check on the file
    reads that prose as data.
    """
    import xml.etree.ElementTree as ET

    root = ET.fromstring(baseline)
    for el in root.iter():
        assert not any(a.rsplit("}", 1)[-1] == "owner" for a in el.attrib), (
            f"{el.tag} carries an owner attribute — owner would be stated, not derived"
        )
        assert el.tag.rsplit("}", 1)[-1] != "owner"

    _, out, _ = _compile(baseline, tmp_path)
    assert "owner: human" in out and "owner: agent" in out


# ===========================================================================
# SECOND IMPORTER — tools/corpus_spec.py, the one that actually round-trips
# ===========================================================================
# The compiler above is a PROJECTION: BPMN in, task skeletons out, and it never
# writes a .bpmn. `corpus_spec` is the round-trip — derive (BPMN → spec YAML) and
# generate (spec → BPMN), with `--save` writing a new version through /api/save.
# 832's (a)/(b)/(c) question is about round-trips, so this is the importer their
# question is really about, and the answer here is not the same as above.
#
# Measuring both is the point. Answering with only the projection would have been
# true and useless.

sys.path.insert(0, os.path.join(_ROOT, "tools"))
import corpus_spec as cs  # noqa: E402

CORPUS_FIXTURE = os.path.join(_ROOT, "tests", "fixtures", "aef-bpmn", "session-handover.bpmn")

# Anchors in that fixture. Asserted before use so a fixture edit fails loudly rather
# than turning every probe into a silent no-op.
_C_TASK = '<bpmn:userTask id="hum_pickup" name="Read handover, choose first action (human-only)">'
_C_EXT = '<bpmn:extensionElements>\n        <aef:uid value="n_pickup"/>'
_C_FLOW = '<bpmn:sequenceFlow id="flow_1" sourceRef="agt_start" targetRef="frw_resume">'
_C_AEF_NS = 'xmlns:aef="http://anchorpoint.framework/aef/extensions"\n                  '
_C_VENDOR_NS = 'xmlns:vendor="http://example.invalid/v"\n                  '

_C_DI = (
    '  <bpmndi:BPMNDiagram id="S-DI-DIAGRAM">\n'
    '    <bpmndi:BPMNPlane id="pl1" bpmnElement="proc_session_handover">\n'
    '      <bpmndi:BPMNShape id="sh1" bpmnElement="hum_pickup">\n'
    '        <dc:Bounds x="999" y="999" width="100" height="80"/>\n'
    "      </bpmndi:BPMNShape>\n"
    "    </bpmndi:BPMNPlane>\n"
    "  </bpmndi:BPMNDiagram>\n</bpmn:definitions>"
)


def _c_vendor(x: str) -> str:
    assert _C_AEF_NS in x, "aef xmlns anchor missing — probe would be a no-op"
    return x.replace(_C_AEF_NS, _C_AEF_NS + _C_VENDOR_NS, 1)


CORPUS_PROBES: list[Probe] = [
    _p("unknown-aef-ext-child", "an unrecognised aef:* child of extensionElements",
       "S-EXT-UNKNOWN",
       lambda x: x.replace(_C_EXT, _C_EXT + '\n        <aef:notAThing>S-EXT-UNKNOWN</aef:notAThing>', 1)),
    _p("foreign-ns-ext-child", "a foreign-namespace child of extensionElements",
       "S-EXT-FOREIGN",
       lambda x: _c_vendor(x).replace(_C_EXT, _C_EXT + '\n        <vendor:note>S-EXT-FOREIGN</vendor:note>', 1)),
    _p("foreign-attr-on-node", "a foreign-namespace attribute on a node",
       "S-ATTR",
       lambda x: _c_vendor(x).replace(_C_TASK, _C_TASK[:-1] + ' vendor:p="S-ATTR">', 1)),
    _p("text-in-node", "loose text inside a node (832's T-347 shape)",
       "S-TEXT",
       lambda x: x.replace(_C_TASK, _C_TASK + "S-TEXT", 1)),
    _p("documentation-child-of-node", "<bpmn:documentation> as a non-extension child of a NODE",
       "S-DOC-NODE",
       lambda x: x.replace(_C_TASK, _C_TASK + "\n      <bpmn:documentation>S-DOC-NODE</bpmn:documentation>", 1)),
    _p("non-ext-child-of-flow", "the same class of content on an EDGE instead of a node",
       "S-COND",
       lambda x: x.replace(_C_FLOW, _C_FLOW + "\n      <bpmn:conditionExpression>S-COND</bpmn:conditionExpression>", 1)),
    _p("unsupported-identified-process-child", "a process child we cannot round-trip, WITH an id",
       "S-BOUNDARY",
       lambda x: x.replace("</bpmn:process>", '  <bpmn:boundaryEvent id="S-BOUNDARY" attachedToRef="hum_pickup"/>\n  </bpmn:process>', 1)),
    _p("unidentified-process-child", "the same class of element, WITHOUT an id",
       "S-ANNOT",
       lambda x: x.replace("</bpmn:process>", "  <bpmn:textAnnotation><bpmn:text>S-ANNOT</bpmn:text></bpmn:textAnnotation>\n  </bpmn:process>", 1)),
    _p("foreign-top-level-subtree", "a foreign sub-tree hanging off <definitions>",
       "S-TOP",
       lambda x: _c_vendor(x).replace("</bpmn:definitions>", "  <vendor:catalog>S-TOP</vendor:catalog>\n</bpmn:definitions>", 1)),
    _p("trailing-comment", "a comment after the last element (the doc slot is LEADING only)",
       "S-TRAILING-COMMENT",
       lambda x: x.replace("</bpmn:definitions>", "  <!-- S-TRAILING-COMMENT -->\n</bpmn:definitions>", 1)),
    _p("di-geometry", "BPMNDI layout — 832's T-340 position, where we emit aef:position",
       "S-DI-DIAGRAM",
       lambda x: x.replace("</bpmn:definitions>", _C_DI, 1)),
    # T-2884 / 832 rail 490. exporter= is neither foreign-ns nor on a node, so the
    # rows above did not cover it in either direction — and it is now the single
    # field 832's authorship test depends on, which makes this answer load-bearing
    # for a peer rather than merely informative.
    _p("exporter-attr-on-definitions",
       "exporter= — a STANDARD BPMN attribute on <definitions>",
       "aef-workflow-designer",
       lambda x: x.replace('<bpmn:definitions ',
                           '<bpmn:definitions exporter="aef-workflow-designer" ', 1)),
    _p("exporterVersion-attr-on-definitions",
       "its sibling — so the verdict is about the POSITION, not one attribute name",
       "0.9.0-probe",
       lambda x: x.replace('<bpmn:definitions ',
                           '<bpmn:definitions exporterVersion="0.9.0-probe" ', 1)),
    _p("name-attr-on-definitions",
       "an unrelated standard attribute in the same position, as a third point",
       "S-DEFS-NAME",
       lambda x: x.replace('<bpmn:definitions ',
                           '<bpmn:definitions name="S-DEFS-NAME" ', 1)),
]

CORPUS_POSITIVE_CONTROLS: list[Probe] = [
    _p("control-node-name", "a node's @name — unambiguously read", "",
       lambda x: x.replace('name="Read handover, choose first action (human-only)"',
                           'name="CONTROL RENAMED"', 1)),
]

CORPUS_NULL_CONTROL = _p("null-unused-xmlns", "an xmlns declaration nothing uses", "", _c_vendor)


def _roundtrip(xml: str) -> tuple[str, str]:
    """(status, payload). status is 'ok' with the emitted XML, or 'refused'."""
    try:
        return "ok", cs.emit_map(cs.parse_map(xml))
    except SystemExit as e:
        return "refused", str(e)


def _classify_rt(base_out: str, xml: str, sentinel: str) -> str:
    status, out = _roundtrip(xml)
    if status == "refused":
        return REFUSED
    if sentinel and sentinel in out:
        return PRESERVED
    if out != base_out:
        return CONSUMED
    return DROPPED_SILENT


@pytest.fixture(scope="module")
def corpus_baseline():
    return open(CORPUS_FIXTURE).read()


def measure_corpus(baseline_xml: str) -> dict[str, str]:
    status, base_out = _roundtrip(baseline_xml)
    assert status == "ok", f"baseline does not round-trip: {base_out[:200]}"
    out = {}
    for probe in CORPUS_PROBES:
        mutated = probe.mutate(baseline_xml)
        assert mutated != baseline_xml, f"{probe.name}: mutation was a no-op"
        out[probe.name] = _classify_rt(base_out, mutated, probe.sentinel)
    return out


def test_corpus_baseline_round_trips(corpus_baseline):
    """SMOKE — and it is 832's own corpus diagram (their T-214), so this doubles
    as a cross-validation that we can read what they author."""
    status, out = _roundtrip(corpus_baseline)
    assert status == "ok"
    assert cs.canonical(corpus_baseline) == cs.canonical(out)


def test_corpus_positive_controls_move_the_output(corpus_baseline):
    _, base_out = _roundtrip(corpus_baseline)
    for probe in CORPUS_POSITIVE_CONTROLS:
        mutated = probe.mutate(corpus_baseline)
        assert mutated != corpus_baseline, f"{probe.name}: mutation was a no-op"
        assert _roundtrip(mutated)[1] != base_out, f"{probe.name} did not move the output"


def test_corpus_null_control_does_not_move_the_output(corpus_baseline):
    _, base_out = _roundtrip(corpus_baseline)
    assert _roundtrip(CORPUS_NULL_CONTROL.mutate(corpus_baseline))[1] == base_out


# Measured 2026-08-09. Unlike the projection above, this importer answers all THREE
# of 832's options depending on where the content sits — which is the same shape
# their own rail-486 brief arrived at after expecting one uniform answer.
CORPUS_MEASURED_2026_08_09 = {
    # (a) preserve verbatim — T-2614 built this deliberately
    "unknown-aef-ext-child": PRESERVED,
    "foreign-ns-ext-child": PRESERVED,
    "non-ext-child-of-flow": PRESERVED,
    # (c) refuse — T-2614 again: losing a node while keeping its flows is worse
    "unsupported-identified-process-child": REFUSED,
    # (b) drop, silently
    "foreign-attr-on-node": DROPPED_SILENT,
    "text-in-node": DROPPED_SILENT,
    "documentation-child-of-node": DROPPED_SILENT,
    "unidentified-process-child": DROPPED_SILENT,
    "foreign-top-level-subtree": DROPPED_SILENT,
    "trailing-comment": DROPPED_SILENT,
    "di-geometry": DROPPED_SILENT,
    # T-2884: not attribute-specific — the emitter reconstructs <definitions> from
    # the spec's two recorded fields, so every other attribute in that position goes.
    "exporter-attr-on-definitions": DROPPED_SILENT,
    "exporterVersion-attr-on-definitions": DROPPED_SILENT,
    "name-attr-on-definitions": DROPPED_SILENT,
}


def test_definitions_attributes_survive_only_by_being_reconstructed(corpus_baseline):
    """T-2884 — the <definitions> verdict is positional, and we stamp no producer id.

    `id` and `targetNamespace` come back because the emitter writes them from the
    spec, not because anything preserved them. Nothing else in that position
    survives, which is why probing three different attributes matters: an answer
    true for `exporter` alone would be a coincidence, not a property of the seam.

    T-2891 changed the second half, and the obligation this test carried is what
    caught it: the previous version asserted `"exporter" not in dst.attrib` with a
    message saying that if we ever stamped one, 832 had to be told. Adding the
    stamp turned it red on the first run. Recorded because the test did the job a
    test is for — it held a measured fact and refused to let it go quietly false.

    We now stamp `exporter="aef-corpus-spec"`. The reason is not attribution:
    832's T-406 fix suppresses an imported doc comment unless the document
    positively names a DIFFERENT producer, so an anonymous document — which is
    what we used to emit — loses its authored rationale on their import.

    The positional finding is unchanged and is what the first assertion still
    pins. `<definitions>` is reconstructed, not preserved-and-filtered: the source
    document's attribute set does not reach the output, and what appears there
    appears because `emit_map` writes it. That is why the stamp works at all.
    """
    import xml.etree.ElementTree as ET

    _, out = _roundtrip(corpus_baseline)
    src = ET.fromstring(corpus_baseline)
    dst = ET.fromstring(out)
    assert set(src.attrib) == {"id", "targetNamespace"}
    # reconstructed: the output's attribute set is the emitter's, not the source's
    assert set(dst.attrib) == {"id", "targetNamespace", "exporter"}
    assert dst.attrib["exporter"] == "aef-corpus-spec"
    # 832's suppression check keys on the producer being DIFFERENT from theirs.
    # A collision would silently reintroduce the defect their T-406 fix closed,
    # and it would do so invisibly — the document would still name a producer.
    assert dst.attrib["exporter"] != "aef-workflow-designer"


def test_workflow_ref_survives_the_round_trip():
    """T-2891 — 832 asked, at 492, whether our workflowRef uuids survive our own
    round-trip, flagging them as the candidate for carrying ORIGIN as a fact
    distinct from production. Neither side had measured it.

    They do survive. Recorded here rather than in a rail post alone, because the
    claim 832 would be leaning on is "they survive", not "they survived once on
    2026-08-09", and an unpinned measurement of a mutable code path decays into
    folklore — which is the exact failure this whole harness exists to prevent.

    Fixture note, and it is the more uncomfortable half: NONE of the five
    fixtures the corpus census already ran over carries a workflowRef. Zero, all
    five. So every fidelity verdict measured so far was measured on documents
    with no cross-map links in them at all, and "workflowRef is preserved" would
    have read as a green census result while resting on nothing. This fixture is
    a real document from our own corpus (aef-task-lifecycle v3), not a synthesised
    one — 832's PROVENANCE.md names the alternative as "a population built by
    imagining what real input looks like", and it is right.
    """
    import re

    path = os.path.join(
        _ROOT, "tests", "fixtures", "aef-bpmn", "task-lifecycle-with-workflowref.bpmn"
    )
    with open(path) as fh:
        src = fh.read()
    refs_in = re.findall(r'workflowRef="([^"]+)"', src)

    # Positive control on the INPUT: a document with no workflowRef would make
    # "in == out" trivially true and the verdict would mean nothing.
    assert refs_in, "fixture no longer carries a workflowRef — the probe is inert"

    _, out = _roundtrip(src)
    refs_out = re.findall(r'workflowRef="([^"]+)"', out)
    assert refs_out == refs_in


def test_corpus_measured_verdicts_have_not_moved(corpus_baseline):
    assert measure_corpus(corpus_baseline) == CORPUS_MEASURED_2026_08_09


# --- the two findings this census produced ---------------------------------
# Both are pinned as tests rather than prose so that fixing either turns a test red
# and forces the answer we gave 832 to be updated with it.


def test_node_edge_asymmetry_is_real(corpus_baseline):
    """FINDING 1. The same class of content survives on an edge and dies on a node.

    T-2614 added verbatim passthrough for a sequenceFlow's non-extension children
    (`raw_children`) and for unrecognised extensionElements children (`ext_raw`), but
    never for a NODE's non-extension children. So <bpmn:documentation> on an edge
    round-trips and the identical element on a task is destroyed silently.

    Not asserted as correct — asserted as CURRENT, so that closing the asymmetry is
    a deliberate act with a red test attached rather than a quiet drift.
    """
    verdicts = measure_corpus(corpus_baseline)
    assert verdicts["non-ext-child-of-flow"] == PRESERVED
    assert verdicts["documentation-child-of-node"] == DROPPED_SILENT


def test_the_hard_error_is_gated_on_having_an_id(corpus_baseline):
    """FINDING 2. T-2614's refusal only fires for elements that carry an id.

    Same tag, same content, same position — with an id it is a hard error, without
    one it vanishes without a word. The guard that makes unsupported elements loud
    has a hole exactly the size of an unidentified element, and BPMN's annotation
    and association elements are commonly authored without ids.
    """
    verdicts = measure_corpus(corpus_baseline)
    assert verdicts["unsupported-identified-process-child"] == REFUSED
    assert verdicts["unidentified-process-child"] == DROPPED_SILENT


def test_di_drop_has_a_competing_carrier(corpus_baseline):
    """PL-114 check. The DI drop is not loss — we emit our own carrier for geometry.

    832's T-340 ruled CONSUME on exactly this position because preserving DI
    alongside their emitted position would export two contradictory geometries.
    We reached the same ruling independently: aef:position is emitted, DI is not,
    and there is therefore no second carrier to contradict it.
    """
    _, out = _roundtrip(corpus_baseline)
    assert "aef:position" in out, "no competing carrier — the DI drop would be pure loss"
    assert "BPMNDiagram" not in out
    assert measure_corpus(corpus_baseline)["di-geometry"] == DROPPED_SILENT
