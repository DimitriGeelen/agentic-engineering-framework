"""T-2688/T-2689: lane-overflow pinned both ways (fires on spill, silent on contained).

Authorised by the T-2687 GO; re-based in T-2689 onto 832's rail-340 occupancy table.

The class: a lane whose own members occupy more vertical room than its declared
aef:laneMeta height, so the band cannot contain its content. Orthogonal to
lane-geometry, which compares lanes against each other and is structurally blind to
this — the blindness itself is pinned below, because "we added a rule for a class the
old rule already caught" is the failure mode worth guarding against.

WHAT CHANGED IN T-2689 AND WHY. T-2688 shipped this rule on node top-y with threshold
`span >= height`, derived from half-open band MEMBERSHIP (which lane does laneAtY put a
node in). That was the wrong question: the rule claims the band cannot CONTAIN its
content, which is about where the drawn box ends. 832's rail 340 supplied botOf, so the
containment question is now answered exactly rather than approximated conservatively —
`extent = max(botOf) - min(y)`, overflow iff `extent > height`, strict because a box
whose bottom edge lands on the band edge is contained.

One expectation below legitimately FLIPS as a result (`span == height - 1` was silent
under top-y and spills under occupancy). It is renamed and carries its reason inline,
because a changed expectation has to read as a decision rather than as a test edited to
match new output.

Fixtures are built through corpus_spec.emit_map so they exercise the real emitter shape.
"""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_lint  # noqa: E402
import corpus_spec  # noqa: E402

# occupancy of the fixture default type, so the arithmetic in each test is legible
# rather than a magic number smuggled in from the implementation
SERVICE = 64
GATEWAY = 66
EVENT = 54


def _spec(lanes, nodes):
    """lanes: [(id, height)] in declaration order. nodes: [(id, lane, y)] or
    [(id, lane, y, type)] when the node type matters to the arithmetic."""
    return {
        "spec_version": 1, "id": "fixture", "title": "Fixture", "schema_version": 2,
        "tier_default": 1, "pool_name": "Fixture",
        "lanes": [{"id": lid, "name": lid.title(), "abbr": lid[:3],
                   "authority": "initiative", "height": h} for lid, h in lanes],
        "nodes": [{"id": n[0], "lane": n[1], "type": (n[3] if len(n) > 3 else "service"),
                   "name": n[0], "uid": f"u_{n[0]}",
                   "pos": [100.0 + 40 * i, float(n[2])]}
                  for i, n in enumerate(nodes)],
        "flows": [],
    }


def _findings(lanes, nodes, spec_mutator=None):
    spec = _spec(lanes, nodes)
    if spec_mutator:
        spec_mutator(spec)
    return corpus_lint.lane_overflow("fixture@v1", corpus_spec.emit_map(spec))


# ── the occupancy table itself ───────────────────────────────────────────────

def test_every_spec_type_has_an_occupancy_entry():
    """No silent gap. A lane holding an unmapped type SKIPS (see below), which is the
    safe behaviour but an invisible one — if someone adds a palette type to
    TYPE_TO_TAG without an occupancy, this rule would quietly stop evaluating whole
    lanes forever. Fail loudly here instead."""
    missing = set(corpus_spec.TYPE_TO_TAG) - set(corpus_lint.NODE_OCCUPANCY)
    assert missing == set(), f"types with no occupancy entry: {sorted(missing)}"


def test_occupancy_is_not_ordered_by_shape_size():
    """832's inversion, pinned because it is the counterintuitive part of their table
    and the reason a per-type table built from raw height gets tight lanes wrong: a
    36px event occupies 54 and a 48px gateway occupies 66 — MORE than a 64px task."""
    occ = corpus_lint.NODE_OCCUPANCY
    assert occ["gateway"] > occ["service"], "gateway (48+18 label) outranks task (64)"
    assert occ["start"] < occ["service"]
    assert occ["start"] == occ["end"] == occ["catch"] == occ["throw"] == EVENT


# ── fires ────────────────────────────────────────────────────────────────────

def test_overflowing_lane_fires():
    f = _findings([("agent", 100)], [("a1", "agent", 0), ("a2", "agent", 300)])
    assert len(f) == 1
    assert f[0]["rule"] == "lane-overflow"
    assert "T-2689" in f[0]["origin"]


def test_finding_names_extent_spill_fitted_height_and_both_extremal_nodes():
    """An author must be able to act without opening the map."""
    f = _findings([("agent", 100)], [("a_top", "agent", 0), ("a_bot", "agent", 300)])
    d = f[0]["detail"]
    extent = 300 + SERVICE - 0          # 364
    assert "height=100" in d
    assert f"occupy {extent}px" in d
    assert f"spilling {extent - 100}px" in d          # 264
    # the Clean fixpoint 832 named: content + LANE_FIT_MARGIN at both edges
    assert f"height to {extent + 24}" in d           # 388
    assert f[0]["node"] == "a_top, a_bot"
    assert "a_top at y=0" in d
    # the lowest node is named WITH its type and occupancy, because the reader
    # otherwise cannot reproduce the arithmetic
    assert f"a_bot (service, y=300 + {SERVICE}px occupancy)" in d


def test_message_names_both_fixes_and_prescribes_neither():
    """T-2687 IW-4: the rule localises the defect but cannot make the authoring call."""
    f = _findings([("agent", 100)], [("a1", "agent", 0), ("a2", "agent", 300)])
    d = f[0]["detail"]
    assert "raise" in d and "height" in d
    assert "compress the node placement" in d
    assert "authoring call" in d


def test_each_overflowing_lane_reported_separately():
    f = _findings([("agent", 50), ("framework", 50)],
                  [("a1", "agent", 0), ("a2", "agent", 200),
                   ("f1", "framework", 500), ("f2", "framework", 800)])
    assert sorted(x["node"] for x in f) == ["a1, a2", "f1, f2"]


def test_tight_lane_missed_by_the_top_y_form_now_fires():
    """THE EXPECTATION THAT FLIPPED, and the whole point of the T-2689 re-base.

    Under T-2688's top-y form this was the pinned SILENT case: span 199 < height 200.
    Under occupancy the bottom node's box ends at 199+64=263, so the lane spills 63px.
    The old form was not wrong about its own question (membership), it was answering
    the wrong question — see the module docstring. This is exactly the tight-lane
    class 832 predicted at rail 340."""
    f = _findings([("agent", 200)], [("a1", "agent", 0), ("a2", "agent", 199)])
    assert len(f) == 1
    assert f"spilling {199 + SERVICE - 200}px" in f[0]["detail"]   # 63


def test_lone_node_taller_than_its_lane_fires():
    """Zero span, real spill: a 64px task cannot fit a 60px lane (832's floor). The
    top-y form could never see this class at all — span is 0 for any single node."""
    f = _findings([("agent", 60)], [("a1", "agent", 0)])
    assert len(f) == 1
    assert f"spilling {SERVICE - 60}px" in f[0]["detail"]          # 4


def test_lowest_node_is_by_drawn_edge_not_by_largest_y():
    """The discriminating pair. A gateway one pixel ABOVE a task still ends one pixel
    BELOW it (199+66=265 vs 200+64=264), so the node that actually defines the spill is
    the one with the smaller y. A largest-y sort — the obvious implementation, and what
    the T-2688 top-y form effectively did — names the wrong node here."""
    f = _findings([("agent", 100)],
                  [("a_top", "agent", 0), ("a_task", "agent", 200, "service"),
                   ("a_gw", "agent", 199, "gateway")])
    assert f[0]["node"] == "a_top, a_gw", "gateway ends 1px lower despite the smaller y"
    assert f"spilling {199 + GATEWAY - 100}px" in f[0]["detail"]          # 165

    # control: widen the gap and the ordering flips back, so the assertion above is
    # discriminating rather than accidentally true for this fixture shape
    f2 = _findings([("agent", 100)],
                   [("a_top", "agent", 0), ("a_task", "agent", 200, "service"),
                    ("a_gw", "agent", 190, "gateway")])
    assert f2[0]["node"] == "a_top, a_task", "190+66=256 < 200+64=264"


# ── silent ───────────────────────────────────────────────────────────────────

def test_content_exactly_filling_the_lane_is_silent():
    """Strict `>`: a box whose bottom edge lands exactly on the band's bottom edge is
    contained, not spilling. This is the containment boundary — distinct from the
    membership boundary the T-2688 form used, where equality DID fire."""
    f = _findings([("agent", 264)], [("a1", "agent", 0), ("a2", "agent", 200)])
    assert f == [], "extent 264 == height 264 is contained"


def test_one_pixel_over_fires():
    """The other side of that boundary, so an off-by-one cannot hide in either
    direction."""
    f = _findings([("agent", 263)], [("a1", "agent", 0), ("a2", "agent", 200)])
    assert len(f) == 1
    assert "spilling 1px" in f[0]["detail"]


def test_comfortably_fitting_lane_is_silent():
    f = _findings([("agent", 300)], [("a1", "agent", 100), ("a2", "agent", 180)])
    assert f == []


def test_lane_below_the_clean_fixpoint_but_containing_is_silent():
    """The margin-advisory class, deliberately NOT gated (T-2689 AC-9). Content extent
    144 fits height 150, but 832's Clean fixpoint wants 144+24=168. The lane is one
    Clean away from tidy, not broken — firing here would report tidiness as breakage.
    Two live lanes sit in this band (aef-task-lifecycle agent 6px slack,
    aef-inception-flow agent 16px) and they are recorded as an observation, not here."""
    f = _findings([("agent", 150)], [("a1", "agent", 0), ("a2", "agent", 80)])
    assert f == [], "contained with less than the fit margin is not a spill"


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


def test_lane_with_an_unknown_node_type_skips_only_that_lane():
    """Skip-not-pass for the occupancy table too. The alternative — defaulting the
    height — is a guessed renderer constant, which is the T-2684 band-model error.

    Simulated by removing an entry rather than inventing a type, because the emitter
    validates against TYPE_TO_TAG and will not serialise an unknown one. That is the
    right shape anyway: the reachable failure is TYPE_TO_TAG growing a palette type
    while NODE_OCCUPANCY does not, which is precisely this condition."""
    from unittest.mock import patch
    table = {k: v for k, v in corpus_lint.NODE_OCCUPANCY.items() if k != "service"}
    with patch.object(corpus_lint, "NODE_OCCUPANCY", table):
        f = _findings([("agent", 50), ("framework", 50)],
                      [("a1", "agent", 0), ("a2", "agent", 400),          # service
                       ("f1", "framework", 600, "gateway"),
                       ("f2", "framework", 900, "gateway")])
    assert [x["node"] for x in f] == ["f1, f2"], (
        "agent holds an unmapped type and must skip; framework must still report")


def test_malformed_xml_defers_to_lint_map():
    assert corpus_lint.lane_overflow("fixture@v1", "<not-xml") == []


# ── the superset proof (T-2689 AC-4) ─────────────────────────────────────────

def test_occupancy_form_is_a_strict_superset_of_the_shipped_top_y_form():
    """T-2687 forced this claim to be earned rather than asserted: the identical
    "strictly stronger" claim about the ORDERING rule was false, shipped to 832 at
    rail 336 before it was checked, and had to be retracted at 338. This one is a
    one-line proof over positive numbers — span >= height implies extent > height,
    because extent = span + occupancy(lowest) and occupancy is always positive — so
    it is pinned by exhaustive check rather than by a docstring sentence."""
    for height in (40, 100, 137, 200, 301):
        for span in range(0, 400, 7):
            old_fires = span >= height
            new_fires = bool(_findings([("agent", height)],
                                       [("a1", "agent", 0), ("a2", "agent", span)]))
            if old_fires:
                assert new_fires, f"regression: old caught span={span} h={height}, new missed"
    # and strictly stronger: a witness the old form was silent on
    assert not (150 >= 200)                      # old predicate, silent
    assert _findings([("agent", 200)], [("a1", "agent", 0), ("a2", "agent", 150)])


# ── orthogonality: the reason this rule exists at all ────────────────────────

def test_lane_geometry_is_blind_to_the_class_this_rule_catches():
    """The T-2687 F3 proof, pinned. A lane overflowing its own height while lane
    ordering is perfectly correct: lane-geometry sees nothing, lane-overflow catches it.
    If this test ever fails because lane-geometry started firing, the two rules have
    stopped being orthogonal and the overlap needs re-deciding, not silencing."""
    lanes = [("agent", 300), ("framework", 100)]
    nodes = [("a1", "agent", 0), ("a2", "agent", 90),
             ("f1", "framework", 110), ("f2", "framework", 300)]
    xml = corpus_spec.emit_map(_spec(lanes, nodes))
    assert corpus_lint.lane_geometry("fixture@v1", xml) == [], "ordering is correct here"
    f = corpus_lint.lane_overflow("fixture@v1", xml)
    assert [x["node"] for x in f] == ["f1, f2"], "agent contains its content, framework does not"


# ── integration + live corpus ────────────────────────────────────────────────

def test_rule_reaches_lint_map_output():
    xml = corpus_spec.emit_map(_spec([("agent", 100)],
                                     [("a1", "agent", 0), ("a2", "agent", 300)]))
    findings, _typed = corpus_lint.lint_map(
        "fixture@v1", xml, {"by_uuid": {}, "by_id": {}}, set(),
        editor_resolves_uuid=True)
    assert [f["rule"] for f in findings] == ["lane-overflow"]


def test_fires_on_both_live_knowledge_leveling_overflows():
    """The instance that justified the rule (T-2687 F3) plus the one only occupancy
    can see. The agent lane was already caught by the top-y form; the framework lane
    has 18px of top-y headroom and overflows against ANY node type, since the smallest
    occupancy in the table is 54 — 832 called this one at rail 340 before we measured
    it. Lives here rather than in the shared baseline test because the default scan
    skips draft-* maps, so these findings are only reachable by naming the draft."""
    import json
    d = REPO_ROOT / ".context/designer/projects/draft-knowledge-leveling"
    latest = json.loads((d / "meta.json").read_text())["latest"]
    f = corpus_lint.lane_overflow("draft-knowledge-leveling", (d / f"v{latest}.bpmn").read_text())
    by_lane = {x["detail"].split('"')[1]: x["detail"] for x in f}
    assert set(by_lane) == {"agent", "framework"}, f
    assert "height=260" in by_lane["agent"] and "occupy 567px" in by_lane["agent"]
    assert "spilling 307px" in by_lane["agent"]
    assert "height=380" in by_lane["framework"] and "occupy 416px" in by_lane["framework"]
    assert "spilling 36px" in by_lane["framework"]


def test_fires_on_the_live_session_lifecycle_spill():
    """A CANONICAL map, not a draft — this is why the default lint baseline moved from
    3 to 4 in T-2689. 6px is small enough to look like noise and is a real spill by the
    renderer's own containment function; the lowest node is a gateway (66px occupancy),
    which the top-y form and a height-only table would both have got wrong."""
    d = REPO_ROOT / ".context/designer/projects/aef-session-lifecycle"
    import json
    latest = json.loads((d / "meta.json").read_text())["latest"]
    f = corpus_lint.lane_overflow("aef-session-lifecycle", (d / f"v{latest}.bpmn").read_text())
    assert len(f) == 1
    assert "spilling 6px" in f[0]["detail"]
    assert f"(gateway, y=300 + {GATEWAY}px occupancy)" in f[0]["detail"]


def test_rule_is_documented_in_module_docstring():
    doc = corpus_lint.__doc__
    assert "lane-overflow" in doc
    assert "T-2689" in doc
    assert "FULL-OCCUPANCY" in doc
    # the provenance of the constants must be findable from the catalogue alone
    assert "rail 340" in doc
