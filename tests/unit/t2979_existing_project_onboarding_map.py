"""T-2979: the existing-project onboarding map must stay in step with the seeds it explains.

Sibling to ``t2974_greenfield_operator_prose.py``, which pins the *channel* lesson for the
greenfield map. This file pins the two things that are specific to the existing-project map
and would otherwise rot silently:

1. **Coverage is derived, not declared.** The node set is checked against the seed directory
   on disk rather than a hard-coded list. If someone adds a seventh seeded task to
   ``lib/seeds/tasks/existing-project/`` and does not extend the map, this goes red. A
   hard-coded list would have gone green forever — and the failure it is guarding against
   (an operator walking a step the diagram does not know about) is exactly the kind nobody
   notices, because a diagram that is merely *incomplete* still renders perfectly.

2. **The unwired human node is deliberate.** ``hum_alongside`` has no incoming or outgoing
   sequence flows, because this path has no blocking human gate — the operator reads
   alongside and pushes back, and nothing waits for them. That is arc-017's headline
   mechanic drawn as geometry. It looks exactly like a bug (a disconnected node), so it is
   pinned here: a future author who "fixes" it by wiring it into the chain gets a red test
   and a paragraph explaining why the disconnection is the content.

The channel lesson itself is not re-litigated node by node — it is enforced by calling
``corpus_lint.unread_node_prose`` directly, which is the rule T-2976 shipped for the class.
"""

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_explain as ce  # noqa: E402
import corpus_lint  # noqa: E402
import corpus_spec  # noqa: E402

MAP_ID = "aef-existing-project-onboarding"
SEED_DIR = REPO_ROOT / "lib" / "seeds" / "tasks" / "existing-project"
MAP_PATH = REPO_ROOT / ".context" / "designer" / "projects" / MAP_ID / "v1.bpmn"

#: Same five headings the greenfield map answers. Held only against the six curriculum
#: nodes — start/end frame the sequence rather than teach a step, and the human node
#: answers a different question ("why does this box have no arrows").
SECTIONS = (
    "WHAT'S HAPPENING",
    "WHY IT MATTERS",
    "WHAT YOU CAN DO",
    "KEY LEARNING",
    "NEXT",
)

#: Curriculum nodes, in seeded order. Kept as a mapping so the coverage test can report
#: which SEED has no node rather than which node id is absent — the former is actionable.
SEED_TO_NODE = {
    "T-001": "agt_1_orientation",
    "T-002": "agt_2_first_commit",
    "T-003": "agt_3_fabric",
    "T-004": "agt_4_lifecycle",
    "T-005": "agt_5_handover",
    "T-006": "agt_6_learning",
}

HUMAN_NODE = "hum_alongside"


def _spec():
    spec, _meta = ce.load_latest(REPO_ROOT, MAP_ID)
    return spec


def _notes():
    return {n["id"]: (n.get("meta") or {}).get("note", "") for n in _spec()["nodes"]}


def _seed_ids():
    return sorted({m.group(1) for f in SEED_DIR.glob("T-0*.md")
                   if (m := re.match(r"(T-\d+)", f.name))})


def test_every_seeded_task_has_a_node():
    """Coverage derived from disk — a seventh seed with no node turns this red."""
    seeds = _seed_ids()
    assert seeds, f"no seeds found under {SEED_DIR} — test is looking in the wrong place"
    uncovered = [s for s in seeds if s not in SEED_TO_NODE]
    assert not uncovered, (
        f"seeded task(s) {uncovered} have no node in {MAP_ID}. The operator walks these "
        f"steps; the diagram does not know they exist. Add a node (and extend SEED_TO_NODE)."
    )
    stale = [s for s in SEED_TO_NODE if s not in seeds]
    assert not stale, f"{MAP_ID} maps seed(s) {stale} that no longer exist on disk"


def test_mapped_nodes_all_exist_in_the_map():
    ids = {n["id"] for n in _spec()["nodes"]}
    missing = {s: n for s, n in SEED_TO_NODE.items() if n not in ids}
    assert not missing, f"node id(s) named by SEED_TO_NODE absent from the map: {missing}"


def test_every_curriculum_node_carries_all_five_operator_sections():
    notes = _notes()
    for seed, nid in SEED_TO_NODE.items():
        note = notes.get(nid, "")
        assert note, f"{seed} ({nid}) has no aef:meta note — prose is not on a read channel"
        missing = [s for s in SECTIONS if s not in note]
        assert not missing, f"{seed} ({nid}) note is missing section(s): {missing}"


def test_notes_survive_as_multiline():
    """Newlines must reach the reader — see t2974 for why the encoding is &#10;."""
    notes = _notes()
    for seed, nid in SEED_TO_NODE.items():
        assert "\n" in notes[nid], (
            f"{seed} ({nid}) note is single-line: newlines were written literally instead "
            "of as &#10; and got normalised away on parse (XML 1.0 §3.3.3)"
        )


def test_no_prose_on_an_unread_extension_child():
    """The T-2976 rule applied to this map, rather than a hand-rolled restatement."""
    proc = ET.parse(MAP_PATH).getroot().find(f"{{{corpus_spec.BPMN_NS}}}process")
    assert proc is not None, "no bpmn:process element — map shape changed"
    findings = corpus_lint.unread_node_prose(MAP_ID, proc)
    assert not findings, f"prose on a channel no reader reads: {findings}"


def test_human_node_is_deliberately_unwired():
    """Not a dropped edge. See this module's docstring, point 2, before "fixing" it.

    The existing-project path has no blocking human gate: the project already exists, so
    the go/no-go the greenfield path stops for was settled before the framework arrived.
    The operator reads alongside and corrects; nothing waits. Wiring this node into the
    sequence chain would draw a gate that does not exist and would contradict the arc-017
    invariant that the curriculum never blocks.
    """
    spec = _spec()
    ids = {n["id"] for n in spec["nodes"]}
    assert HUMAN_NODE in ids, (
        f"{HUMAN_NODE} is gone — the human lane is what makes this map say something the "
        "seed prose does not. Removing it is a bigger change than it looks."
    )
    touching = [f for f in spec["flows"]
                if f["from"] == HUMAN_NODE or f["to"] == HUMAN_NODE]
    assert not touching, (
        f"{HUMAN_NODE} has been wired into the sequence chain by {touching}. That draws a "
        "blocking human gate this path does not have. If the curriculum genuinely gained "
        "one, change arc-017's invariant first — the diagram is downstream of it."
    )


def test_the_human_node_is_in_the_human_lane():
    node = next(n for n in _spec()["nodes"] if n["id"] == HUMAN_NODE)
    assert node["lane"] == "human", (
        f"{HUMAN_NODE} sits in lane {node['lane']!r} — an advisory node in the agent lane "
        "reads as work the agent does"
    )


def test_seed_routes_to_the_map():
    """Parity with greenfield/T-001, which has offered its map since T-2972."""
    t001 = next(SEED_DIR.glob("T-001*.md")).read_text()
    assert f"corpus explain {MAP_ID}" in t001, (
        f"existing-project/T-001 does not route to {MAP_ID}. An unreferenced map is one "
        "nobody opens — the asymmetry this task closed would silently reopen."
    )


def test_both_onboarding_paths_route_to_their_own_map():
    """The asymmetry itself, pinned: neither path may lose its diagram."""
    for kind, mid in (("greenfield", "aef-greenfield-onboarding"),
                      ("existing-project", MAP_ID)):
        seed_dir = REPO_ROOT / "lib" / "seeds" / "tasks" / kind
        t001 = next(seed_dir.glob("T-001*.md")).read_text()
        assert f"corpus explain {mid}" in t001, f"{kind}/T-001 no longer routes to {mid}"
