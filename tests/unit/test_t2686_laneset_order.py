"""T-2686: the two repaired drafts must keep declared lane order == drawn order.

Regression guard, not a one-off proof. The defect is re-armable by a single mouse
gesture: 832's designer reassigns a node's lane from its pixel position on drag
(their T-310, src laneAtY), and export writes flowNodeRef from that. So any future
designer round-trip on these maps can silently re-invert what this task repaired —
which is precisely how they got inverted in the first place.

Scoped to the two maps T-2686 repaired rather than the whole store on purpose: new
drafts are sketches and are meant to be free to be wrong until promotion, and
`fw corpus lint` is the surface that catches them. What this file pins is that a
*repaired* map stays repaired.

The feasibility assertion is the stronger of the two checks and is worth keeping
even though the shipped lint rule does not implement it — see the T-2686 Decisions
section for why it did not become a lint rule in this task.
"""

import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_lint  # noqa: E402
from corpus_spec import parse_map  # noqa: E402

STORE = REPO_ROOT / ".context/designer/projects"

# map id -> lane ids in the order they are DRAWN (top to bottom)
REPAIRED = {
    "draft-exception-handling": ["framework", "agent"],
    "draft-task-creation": ["framework", "agent", "human"],
}


def _latest(map_id):
    d = STORE / map_id
    latest = json.loads((d / "meta.json").read_text())["latest"]
    return (d / f"v{latest}.bpmn").read_text()


def _feasible_origin_interval(spec, order=None):
    """Widest interval of band origins O placing every node inside its own declared
    band, given cumulative aef:laneMeta heights. Interval algebra only — it assumes
    nothing about O's value, so it is origin-free in the same sense as the shipped
    lane-geometry rule, but strictly stronger: non-overlapping ordered spans are
    necessary for feasibility, not sufficient. An empty interval is a proof that no
    origin can satisfy the declaration.

    Reported in stored-y terms. 832's renderer resolves a node's band from its
    centre (laneAtY(centerY)), so a real origin sits offset from this interval by
    the node half-height; that shifts the interval, it cannot empty a non-empty one.
    """
    lanes = {l["id"]: l for l in spec["lanes"]}
    order = order or [l["id"] for l in spec["lanes"]]
    ys = {}
    for n in spec["nodes"]:
        ys.setdefault(n.get("lane"), []).append(n["pos"][1])
    lo, hi, top = float("-inf"), float("inf"), 0.0
    for lane_id in order:
        height = float(lanes[lane_id].get("height") or 0)
        for y in ys.get(lane_id, []):
            lo = max(lo, y - top - height)
            hi = min(hi, y - top)
        top += height
    return lo, hi


@pytest.mark.parametrize("map_id,drawn_order", sorted(REPAIRED.items()))
def test_declared_lane_order_matches_drawn_order(map_id, drawn_order):
    spec = parse_map(_latest(map_id))
    assert [l["id"] for l in spec["lanes"]] == drawn_order


@pytest.mark.parametrize("map_id", sorted(REPAIRED))
def test_repaired_draft_is_lane_geometry_clean(map_id):
    assert corpus_lint.lane_geometry(f"{map_id}@latest", _latest(map_id)) == []


@pytest.mark.parametrize("map_id", sorted(REPAIRED))
def test_some_band_origin_can_satisfy_the_declaration(map_id):
    """Pre-repair both maps had an EMPTY interval ([160,-80] and [120,-160]) — no
    origin at all could place their nodes in their declared bands. Post-repair both
    are feasible. This is the assertion that would have failed loudest before."""
    lo, hi = _feasible_origin_interval(parse_map(_latest(map_id)))
    assert lo <= hi, f"{map_id}: no feasible band origin (interval [{lo}, {hi}])"


def test_feasibility_detects_the_pre_repair_inversion():
    """Pins the checker itself against a known-bad arrangement, so a future edit
    cannot turn it into a function that always passes (the G-071 shape: a check
    whose world-assumption drifted still returns a confident verdict)."""
    spec = parse_map(_latest("draft-exception-handling"))
    inverted = list(reversed([l["id"] for l in spec["lanes"]]))
    lo, hi = _feasible_origin_interval(spec, order=inverted)
    assert lo > hi, "inverted lane order must be provably infeasible"
