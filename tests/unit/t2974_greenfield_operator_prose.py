"""T-2974: the greenfield onboarding map's operator prose must actually reach a reader.

Two things are pinned here, and they are separable failures:

1. **Channel.** Per-node prose belongs in the ``<aef:meta note="…"/>`` ATTRIBUTE.
   ``corpus_spec._ext()`` builds its dict from ``c.attrib``, and the pinned designer's
   ``metaKeys`` vocabulary is attributes too — so a text-bearing ``<aef:description>``
   child (what T-2972 v1 shipped) parses to ``{}`` and renders nowhere. The map looked
   correct in the file and read as bare boxes in both surfaces. Nothing was red.

2. **Rendering.** ``corpus_explain`` must keep a multi-line note nested under its node;
   flush-left continuation lines dissolve the walkthrough's structure at exactly the
   length where the prose becomes worth reading.

Newlines survive the attribute channel only as ``&#10;`` character references
(XML 1.0 §3.3.3 — a literal newline in an attribute value normalises to a space).
``test_literal_newline_in_attribute_collapses`` pins that as an executable statement
rather than a claim in a comment, because it is the reason the channel has a rule.
"""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_explain as ce  # noqa: E402
import corpus_spec  # noqa: E402

MAP_ID = "aef-greenfield-onboarding"

#: The five headings every T-001…T-005 node answers. The operator complaint that
#: opened this task was that the diagram said *what* happened and not *why it
#: mattered or what to do*; these are the sections that carry that.
SECTIONS = (
    "WHAT'S HAPPENING",
    "WHY IT MATTERS",
    "WHAT YOU CAN DO",
    "KEY LEARNING",
    "NEXT",
)

#: Curriculum task nodes — the start/end events carry prose too, but are not held
#: to the five-section shape (they frame the sequence rather than teach a step).
TASK_NODES = (
    "agt_1_orientation",
    "hum_2_goals",
    "agt_3_first_commit",
    "agt_4_lifecycle",
    "agt_5_handover",
)


def _spec():
    spec, _meta = ce.load_latest(REPO_ROOT, MAP_ID)
    return spec


def _notes():
    return {n["id"]: (n.get("meta") or {}).get("note", "") for n in _spec()["nodes"]}


def test_every_task_node_carries_all_five_operator_sections():
    notes = _notes()
    for nid in TASK_NODES:
        note = notes.get(nid, "")
        assert note, f"{nid} has no aef:meta note — prose is not on the readable channel"
        missing = [s for s in SECTIONS if s not in note]
        assert not missing, f"{nid} note is missing section(s): {missing}"


def test_prose_is_on_the_attribute_channel_not_a_child_element():
    """The v1 defect, stated as a test: description/note CHILD elements are unread.

    Checked against ``ext_raw`` — the parser's bucket for extension children it does
    not recognise — rather than against the raw file text, which also contains the
    doc comment explaining the defect and would match on the prose.
    """
    for n in _spec()["nodes"]:
        stray = [r for r in (n.get("ext_raw") or [])
                 if "description" in r[:40] or ":note" in r[:40]]
        assert not stray, f"{n['id']} still carries unread child prose: {stray}"


def test_notes_survive_as_multiline():
    """Newlines must reach the reader — a collapsed note is a silent quality loss."""
    notes = _notes()
    for nid in TASK_NODES:
        assert "\n" in notes[nid], (
            f"{nid} note is single-line: newlines were written literally instead of "
            "as &#10; and got normalised away on parse"
        )


def test_literal_newline_in_attribute_collapses():
    """Why the channel has a rule — pins the XML behaviour the encoding works around."""
    parsed = ET.fromstring('<a><b note="one\ntwo"/></a>')[0].get("note")
    assert parsed == "one two"
    escaped = ET.fromstring('<a><b note="one&#10;two"/></a>')[0].get("note")
    assert escaped == "one\ntwo"


def test_explain_indents_multiline_note_continuations(capsys):
    ce.explain(REPO_ROOT, MAP_ID)
    lines = capsys.readouterr().out.splitlines()
    heads = [i for i, l in enumerate(lines) if l.startswith("    note: ")]
    assert heads, "no note rendered — explain regressed off the meta channel"
    for i in heads:
        # The line after a note head is either blank, an indented continuation,
        # or the next structural line (-> / - ). Never flush-left prose.
        nxt = lines[i + 1]
        assert (not nxt.strip()
                or nxt.startswith("          ")
                or nxt.startswith("    ->")
                or nxt.startswith("- ")), f"unindented continuation: {nxt!r}"


def test_topology_unchanged_from_v1():
    """T-2974 enriches content; it must not have moved the process around."""
    d = REPO_ROOT / ".context/designer/projects" / MAP_ID
    v1 = corpus_spec.parse_map((d / "v1.bpmn").read_text())
    v2 = corpus_spec.parse_map((d / "v2.bpmn").read_text())
    assert {n["id"] for n in v1["nodes"]} == {n["id"] for n in v2["nodes"]}
    assert {(f["from"], f["to"]) for f in v1["flows"]} == \
           {(f["from"], f["to"]) for f in v2["flows"]}
    assert {(l["id"], l["authority"]) for l in v1["lanes"]} == \
           {(l["id"], l["authority"]) for l in v2["lanes"]}
