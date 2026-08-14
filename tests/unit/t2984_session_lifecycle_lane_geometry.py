"""T-2984: the session-lifecycle map's lane bands stay honest.

This is the map the onboarding seeds route a first-time operator to
(``existing-project/T-001`` → ``fw corpus explain aef-session-lifecycle``). It carried two
lint findings for roughly four weeks: ``agt_9_session`` — an agent-owned terminal state,
"session closed" — sat at ``y=100``, the human row. Because the render follows geometry
while ``flowNodeRef`` follows membership, the diagram and ``fw corpus explain`` disagreed
about who owned that step, in the first diagram a new operator is told to open.

**What is pinned here is the invariant, not the coordinate.** The fix moved one node to
``y=380``, but asserting ``y == 380`` would fail any future re-layout that keeps the bands
honest — and would pass a re-layout that broke them differently. So the tests ask the
question the rule asks: does every agent-lane node sit below every human-lane node, and does
each lane's declared height contain its own members.

Two of the four tests delegate straight to ``corpus_lint``. That is deliberate: the geometry
model (per-type occupancy — events 54, gateways 66, tasks 64, per L-529 / rail 340) lives in
one place and is not worth restating here, where a copy would drift from the rule it claims
to guard. The remaining two assert the human-readable form of the same property and the
structural no-op, which a caller of ``lane_geometry`` alone would not catch.
"""

import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_lint  # noqa: E402

MAP_ID = "aef-session-lifecycle"
MAP_PATH = REPO_ROOT / ".context/designer/projects" / MAP_ID / "v1.bpmn"
BPMN = "{http://www.omg.org/spec/BPMN/20100524/MODEL}"
AEF = "{http://anchorpoint.framework/aef/extensions}"


def _xml():
    return MAP_PATH.read_text()


def _lane_members():
    """{lane_id: [node_id, ...]} straight from flowNodeRef — the membership side."""
    proc = ET.fromstring(_xml()).find(BPMN + "process")
    return {
        lane.get("id"): [r.text for r in lane.findall(BPMN + "flowNodeRef")]
        for lane in proc.iter(BPMN + "lane")
    }


def _positions():
    """{node_id: y} from aef:position — the geometry side."""
    proc = ET.fromstring(_xml()).find(BPMN + "process")
    out = {}
    for el in proc:
        pos = el.find(f"{BPMN}extensionElements/{AEF}position")
        if pos is not None and el.get("id"):
            out[el.get("id")] = float(pos.get("y"))
    return out


def test_no_lane_geometry_crossing():
    """The rule itself, not a restatement of it — see module docstring."""
    findings = corpus_lint.lane_geometry(MAP_ID, _xml())
    assert not findings, (
        "lane membership and node geometry disagree again:\n  "
        + "\n  ".join(str(f) for f in findings)
    )


def test_no_lane_overflow():
    """Declared lane height must contain the lane's own members."""
    findings = corpus_lint.lane_overflow(MAP_ID, _xml())
    assert not findings, (
        "a lane's members spill past its declared height:\n  "
        + "\n  ".join(str(f) for f in findings)
    )


def test_every_agent_node_sits_below_every_human_node():
    """The human-readable form of the invariant the fix restored.

    `human` is declared first in the laneSet, so it is the top band. Stated this way the
    assertion survives a re-layout: it constrains the relationship between the bands, not
    where either one happens to be. The failure message names the offender because the
    interesting question when this breaks is always *which* node moved.
    """
    members, y = _lane_members(), _positions()
    human = {n: y[n] for n in members["human"] if n in y}
    agent = {n: y[n] for n in members["agent"] if n in y}
    assert human and agent, "lane membership went missing — this test can no longer judge"

    lowest_human = max(human.values())
    intruders = {n: v for n, v in agent.items() if v <= lowest_human}
    assert not intruders, (
        f"agent-lane node(s) {sorted(intruders)} are drawn at y={sorted(intruders.values())}, "
        f"at or above the lowest human-lane node (y={lowest_human}). The render would place "
        f"an agent-owned step inside the human band while flowNodeRef still calls it agent — "
        f"the diagram and `fw corpus explain` then disagree about who owns it. Either move "
        f"the node back below the human band, or — if the step genuinely became human-owned — "
        f"change its flowNodeRef membership too, so both sides say the same thing."
    )


def test_the_fix_was_positional_only():
    """A coordinate repair must not quietly restructure the map (T-2614 data-loss class).

    Compares against the committed baseline rather than hard-coded counts, so this keeps
    working as the map legitimately grows.
    """
    rel = MAP_PATH.relative_to(REPO_ROOT)
    head = subprocess.run(
        ["git", "show", f"HEAD:{rel}"],
        cwd=REPO_ROOT, capture_output=True, text=True,
    )
    if head.returncode != 0:
        import pytest

        pytest.skip("map not in HEAD yet (first commit of this fix)")

    def shape(src):
        proc = ET.fromstring(src).find(BPMN + "process")
        return (
            sorted(e.get("id") for e in proc if e.get("id")),
            {
                lane.get("id"): sorted(r.text for r in lane.findall(BPMN + "flowNodeRef"))
                for lane in proc.iter(BPMN + "lane")
            },
        )

    before_ids, before_lanes = shape(head.stdout)
    after_ids, after_lanes = shape(_xml())
    assert before_ids == after_ids, "node/flow set changed — this was meant to be a move"
    assert before_lanes == after_lanes, (
        "lane membership changed. T-2984's diagnosis was that membership was already "
        "correct and only the coordinate was stale; editing membership encodes the "
        "opposite conclusion and should be its own task with its own reasoning."
    )
