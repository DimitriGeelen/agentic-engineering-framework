"""T-2684: lane-geometry rule pinned both ways (fires on disagreement, silent on clean).

Our half of 832's T-310. A map carries lane membership twice — structurally as
flowNodeRef, visually as each node's aef:position y. The designer draws bands in
laneSet document order and never reconciles the two, so a disagreeing map renders
one authority assignment while `fw corpus explain` and every conformance rail report
another.

Fixtures are built through corpus_spec.emit_map rather than hand-rolled XML, so they
exercise the real emitter shape the rule will meet in the store.
"""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_lint  # noqa: E402
import corpus_spec  # noqa: E402


def _spec(lanes, nodes):
    """lanes: [(id, abbr, height)] in declaration order. nodes: [(id, lane, y)]."""
    return {
        "spec_version": 1, "id": "fixture", "title": "Fixture", "schema_version": 2,
        "tier_default": 1, "pool_name": "Fixture",
        "lanes": [{"id": lid, "name": lid.title(), "abbr": abbr,
                   "authority": "initiative", "height": h}
                  for lid, abbr, h in lanes],
        "nodes": [{"id": nid, "lane": lane, "type": "service", "name": nid,
                   "uid": f"u_{nid}", "pos": [100.0 + 40 * i, float(y)]}
                  for i, (nid, lane, y) in enumerate(nodes)],
        "flows": [],
    }


def _xml(lanes, nodes):
    return corpus_spec.emit_map(_spec(lanes, nodes))


def _findings(lanes, nodes):
    return corpus_lint.lane_geometry("fixture@v1", _xml(lanes, nodes))


TWO = [("agent", "agt", 200), ("framework", "fw", 200)]


# ── fires ────────────────────────────────────────────────────────────────────

def test_wholesale_inversion_fires():
    """Declared order agent-then-framework, drawn framework-then-agent."""
    f = _findings(TWO, [("a1", "agent", 400), ("a2", "agent", 400),
                        ("f1", "framework", 100), ("f2", "framework", 100)])
    assert len(f) == 1
    assert f[0]["rule"] == "lane-geometry"
    assert f[0]["origin"] == "T-2684 / 832 T-310"


def test_wholesale_inversion_says_wholesale_and_points_at_laneset_order():
    """A 100%-both-sides crossing must be named as an ordering defect, because the
    zero-semantic fix (reorder the laneSet) differs from the subset case's fix."""
    f = _findings(TWO, [("a1", "agent", 400), ("f1", "framework", 100)])
    assert "wholesale inversion" in f[0]["detail"]
    assert "laneSet ordering" in f[0]["detail"]
    assert "2/2" not in f[0]["detail"]  # one node each side here
    assert "1/1 agent-nodes and 1/1 framework-nodes" in f[0]["detail"]


def test_subset_crossing_is_reported_as_an_authority_call():
    """Only one node out of place: the fix is a membership/placement decision on the
    named node, not a lane reorder. Mirrors draft-knowledge-leveling v8."""
    f = _findings(TWO, [("a1", "agent", 100), ("a2", "agent", 150),
                        ("a_stray", "agent", 600),
                        ("f1", "framework", 400), ("f2", "framework", 450)])
    assert len(f) == 1
    assert "authority call" in f[0]["detail"]
    assert "wholesale" not in f[0]["detail"]


def test_extremal_witness_pair_is_the_minimal_witness():
    """The reported pair is the upper lane's lowest-drawn node and the lower lane's
    highest-drawn node — provably the crossing pair, needing no band origin. This is
    the property that resolves v8 to exactly kl_healing + kl_dormant."""
    f = _findings(TWO, [("a_top", "agent", 100), ("a_stray", "agent", 600),
                        ("f_high", "framework", 300), ("f_low", "framework", 500)])
    assert f[0]["node"] == "a_stray, f_high"


def test_equal_y_counts_as_a_crossing():
    """Two nodes on the same row cannot be in different bands. Mirrors
    aef-session-lifecycle v1, where the witness pair share y=100."""
    f = _findings(TWO, [("a1", "agent", 100), ("f1", "framework", 100)])
    assert len(f) == 1


def test_three_lanes_reports_per_violating_pair():
    """agent/framework agree; framework/human cross. One finding, not three."""
    lanes = [("agent", "agt", 200), ("framework", "fw", 200), ("human", "hum", 200)]
    f = _findings(lanes, [("a1", "agent", 100), ("f1", "framework", 300),
                          ("h1", "human", 200)])
    assert len(f) == 1
    assert 'lane "framework" is declared above "human"' in f[0]["detail"]


# ── silent ───────────────────────────────────────────────────────────────────

def test_clean_map_is_silent():
    f = _findings(TWO, [("a1", "agent", 100), ("a2", "agent", 150),
                        ("f1", "framework", 400), ("f2", "framework", 450)])
    assert f == []


def test_wide_gap_between_bands_is_silent():
    """Lane heights do not have to tile the node placement — the rule must not
    reconstruct bands. draft-trigger-handling is the live map that proves this:
    cleanly ordered spans, but band arithmetic anchored at the topmost node
    reports 7 phantom mismatches."""
    f = _findings(TWO, [("a1", "agent", 111), ("a2", "agent", 194),
                        ("f1", "framework", 2000)])
    assert f == []


def test_touching_but_ordered_is_silent():
    """Adjacent rows with no overlap: strictly ordered, so no crossing."""
    f = _findings(TWO, [("a1", "agent", 100), ("f1", "framework", 101)])
    assert f == []


# ── skips (must not report clean) ────────────────────────────────────────────

def test_single_lane_is_skipped():
    f = _findings([("agent", "agt", 200)], [("a1", "agent", 100)])
    assert f == []


def test_second_lane_with_no_nodes_is_skipped():
    """Declared but unpopulated lane cannot disagree with anything (t2584-scratch)."""
    f = _findings(TWO, [("a1", "agent", 100), ("a2", "agent", 400)])
    assert f == []


def test_map_with_an_unpositioned_node_is_skipped_not_passed():
    """The invariant needs every member placed. Skipping is correct; silently
    passing an unevaluable map is the G-071 shape this rule exists to avoid."""
    spec = _spec(TWO, [("a1", "agent", 400), ("f1", "framework", 100)])
    del spec["nodes"][0]["pos"]
    f = corpus_lint.lane_geometry("fixture@v1", corpus_spec.emit_map(spec))
    assert f == []


def test_malformed_xml_defers_to_lint_map():
    """lint_map already emits malformed-xml; this rule must not double-report."""
    assert corpus_lint.lane_geometry("fixture@v1", "<not-xml") == []


# ── integration with the lint driver ─────────────────────────────────────────

def test_rule_reaches_lint_map_output():
    xml = _xml(TWO, [("a1", "agent", 400), ("f1", "framework", 100)])
    findings, _typed = corpus_lint.lint_map(
        "fixture@v1", xml, {"by_uuid": {}, "by_id": {}}, set(),
        editor_resolves_uuid=True)
    assert [f["rule"] for f in findings] == ["lane-geometry"]


def test_rule_is_documented_in_module_docstring():
    """T-2602 S3 discipline: every rule carries a task-traceable origin in the
    docstring, since that text is the operator-facing rule catalogue."""
    assert "lane-geometry" in corpus_lint.__doc__
    assert "T-2684" in corpus_lint.__doc__
