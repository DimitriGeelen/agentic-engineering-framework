"""T-2688: lane-overflow rule pinned both ways (fires on overflow, silent on fitting).

Authorised by the T-2687 GO. The class: a lane whose own members span more than its
declared aef:laneMeta height, so the band cannot contain its content. Orthogonal to
lane-geometry, which compares lanes against each other and is structurally blind to
this — the blindness itself is pinned below, because "we added a rule for a class the
old rule already caught" is the failure mode worth guarding against.

Threshold is derived from half-open band semantics (T-2687 F1): containment needs
span < height, so overflow is span >= height. Both sides of that boundary are pinned;
an off-by-one there is the difference between catching the equality case and waving it
through.

Fixtures are built through corpus_spec.emit_map so they exercise the real emitter shape.
"""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_lint  # noqa: E402
import corpus_spec  # noqa: E402


def _spec(lanes, nodes):
    """lanes: [(id, height)] in declaration order. nodes: [(id, lane, y)]."""
    return {
        "spec_version": 1, "id": "fixture", "title": "Fixture", "schema_version": 2,
        "tier_default": 1, "pool_name": "Fixture",
        "lanes": [{"id": lid, "name": lid.title(), "abbr": lid[:3],
                   "authority": "initiative", "height": h} for lid, h in lanes],
        "nodes": [{"id": nid, "lane": lane, "type": "service", "name": nid,
                   "uid": f"u_{nid}", "pos": [100.0 + 40 * i, float(y)]}
                  for i, (nid, lane, y) in enumerate(nodes)],
        "flows": [],
    }


def _findings(lanes, nodes, spec_mutator=None):
    spec = _spec(lanes, nodes)
    if spec_mutator:
        spec_mutator(spec)
    return corpus_lint.lane_overflow("fixture@v1", corpus_spec.emit_map(spec))


# ── fires ────────────────────────────────────────────────────────────────────

def test_overflowing_lane_fires():
    f = _findings([("agent", 100)], [("a1", "agent", 0), ("a2", "agent", 300)])
    assert len(f) == 1
    assert f[0]["rule"] == "lane-overflow"
    assert f[0]["origin"] == "T-2687 GO / T-2688"


def test_finding_names_span_height_shortfall_and_both_extremal_nodes():
    """An author must be able to act without opening the map."""
    f = _findings([("agent", 100)], [("a_top", "agent", 0), ("a_bot", "agent", 300)])
    d = f[0]["detail"]
    assert "height=100" in d
    assert "span 300px" in d
    # Reported as pixels OVER the declared height (span - height), matching the 253px
    # figure already in the T-2687 artifact and the 832 rail thread. The alternative
    # ("pixels needed to fit", span - height + 1) is equally correct arithmetic but
    # would have put a second, off-by-one-looking number into a record that already
    # quotes 253 in three places.
    assert "exceeding it by 200px" in d
    assert f[0]["node"] == "a_top, a_bot"
    assert "a_top at y=0" in d and "a_bot at y=300" in d


def test_message_names_both_fixes_and_prescribes_neither():
    """T-2687 IW-4: the rule localises the defect but cannot make the authoring call."""
    f = _findings([("agent", 100)], [("a1", "agent", 0), ("a2", "agent", 300)])
    d = f[0]["detail"]
    assert "raise" in d and "height" in d
    assert "compress the node placement" in d
    assert "authoring call" in d


def test_span_exactly_equal_to_height_fires():
    """Derived threshold: half-open bands make span == height an overflow, because a
    node whose top sits on the band's bottom edge is already outside [O, O+h)."""
    f = _findings([("agent", 200)], [("a1", "agent", 0), ("a2", "agent", 200)])
    assert len(f) == 1, "span == height must fire (half-open semantics)"


def test_each_overflowing_lane_reported_separately():
    f = _findings([("agent", 50), ("framework", 50)],
                  [("a1", "agent", 0), ("a2", "agent", 200),
                   ("f1", "framework", 500), ("f2", "framework", 800)])
    assert sorted(x["node"] for x in f) == ["a1, a2", "f1, f2"]


# ── silent ───────────────────────────────────────────────────────────────────

def test_span_one_below_height_is_silent():
    """The other side of the derived boundary. Off-by-one here would either miss the
    equality case or flag every exactly-fitting lane."""
    f = _findings([("agent", 200)], [("a1", "agent", 0), ("a2", "agent", 199)])
    assert f == []


def test_comfortably_fitting_lane_is_silent():
    f = _findings([("agent", 300)], [("a1", "agent", 100), ("a2", "agent", 180)])
    assert f == []


def test_single_node_lane_is_silent():
    """A lone node has zero span and cannot overflow any positive height."""
    f = _findings([("agent", 10)], [("a1", "agent", 999)])
    assert f == []


# ── skips (must not report clean, must not blind other lanes) ────────────────

def test_unpopulated_lane_is_skipped():
    f = _findings([("agent", 100), ("empty", 1)], [("a1", "agent", 0)])
    assert f == []


def test_lane_with_an_unpositioned_member_skips_only_that_lane():
    """Per-lane evaluation: one unplaced node must not hide a second lane's overflow."""
    def drop_pos(spec):
        del spec["nodes"][0]["pos"]
    f = _findings([("agent", 50), ("framework", 50)],
                  [("a1", "agent", 0), ("a2", "agent", 400),
                   ("f1", "framework", 600), ("f2", "framework", 900)],
                  spec_mutator=drop_pos)
    assert [x["node"] for x in f] == ["f1, f2"], (
        "the agent lane is unevaluable and must skip, but framework must still report")


def test_malformed_xml_defers_to_lint_map():
    assert corpus_lint.lane_overflow("fixture@v1", "<not-xml") == []


# ── orthogonality: the reason this rule exists at all ────────────────────────

def test_lane_geometry_is_blind_to_the_class_this_rule_catches():
    """The T-2687 F3 proof, pinned. A lane overflowing its own height while lane
    ordering is perfectly correct: lane-geometry sees nothing, lane-overflow catches it.
    If this test ever fails because lane-geometry started firing, the two rules have
    stopped being orthogonal and the overlap needs re-deciding, not silencing."""
    lanes = [("agent", 100), ("framework", 100)]
    nodes = [("a1", "agent", 0), ("a2", "agent", 90),
             ("f1", "framework", 110), ("f2", "framework", 300)]
    xml = corpus_spec.emit_map(_spec(lanes, nodes))
    assert corpus_lint.lane_geometry("fixture@v1", xml) == [], "ordering is correct here"
    assert len(corpus_lint.lane_overflow("fixture@v1", xml)) == 1


# ── integration + live corpus ────────────────────────────────────────────────

def test_rule_reaches_lint_map_output():
    xml = corpus_spec.emit_map(_spec([("agent", 100)],
                                     [("a1", "agent", 0), ("a2", "agent", 300)]))
    findings, _typed = corpus_lint.lint_map(
        "fixture@v1", xml, {"by_uuid": {}, "by_id": {}}, set(),
        editor_resolves_uuid=True)
    assert [f["rule"] for f in findings] == ["lane-overflow"]


def test_fires_on_the_live_knowledge_leveling_overflow():
    """The instance that justified the rule (T-2687 F3): agent lane spans 513px inside
    height=260. Lives here rather than in the shared baseline test because the default
    scan skips draft-* maps, so this finding is only reachable by naming the draft."""
    import json
    d = REPO_ROOT / ".context/designer/projects/draft-knowledge-leveling"
    latest = json.loads((d / "meta.json").read_text())["latest"]
    f = corpus_lint.lane_overflow("draft-knowledge-leveling", (d / f"v{latest}.bpmn").read_text())
    assert len(f) == 1, f
    detail = f[0]["detail"]
    assert 'lane "agent"' in detail
    assert "height=260" in detail
    assert "span 513px" in detail
    # two extremal member nodes named, whatever they are called — asserting a node-id
    # prefix here was a guess (the ids are agt_*, not kl_*) and guessing is the habit
    # this session keeps paying for
    assert len(f[0]["node"].split(", ")) == 2


def test_rule_is_documented_in_module_docstring():
    assert "lane-overflow" in corpus_lint.__doc__
    assert "T-2688" in corpus_lint.__doc__
    # the deferred H leg must be named, so the next reader knows this is a subset.
    # Substring chosen to survive the catalogue's line wrapping — "node box height H"
    # is split across lines in the docstring even though it reads contiguously.
    assert "node box height" in corpus_lint.__doc__
    assert "CONSERVATIVE SUBSET" in corpus_lint.__doc__
