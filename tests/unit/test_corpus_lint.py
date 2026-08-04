"""T-2604: corpus lint rules pinned both ways (fire on defective, silent on clean).

Each rule cites its observed-defect origin (T-2602 S3 discipline); the fixtures
here are minimal synthetic maps exercising exactly one class each.
"""

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import corpus_lint  # noqa: E402

LIVE_UUID = "11111111-1111-4111-8111-111111111111"
GHOST_UUID = "22222222-2222-4222-8222-222222222222"
DANGLER_UUID = "33333333-3333-4333-8333-333333333333"

HEAD = (
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" '
    'xmlns:aef="http://anchorpoint.framework/aef/extensions" id="Definitions_x" '
    'targetNamespace="https://aef.anchorpoint.dev/workflows">'
    '<bpmn:process id="Process_x" isExecutable="true">'
)
TAIL = "</bpmn:process></bpmn:definitions>"


def _throw(nid, link_attrs, outgoing=None, extra_ext=""):
    out = f"<bpmn:outgoing>{outgoing}</bpmn:outgoing>" if outgoing else ""
    return (
        f'<bpmn:intermediateThrowEvent id="{nid}">'
        f"<bpmn:extensionElements><aef:link {link_attrs}/>{extra_ext}"
        f"</bpmn:extensionElements><bpmn:incoming>f_in</bpmn:incoming>{out}"
        f"</bpmn:intermediateThrowEvent>"
    )


def _catch_typed(nid, binding, seam_pending=False):
    meta = '<aef:meta seamPending="T-XXXX will emit"/>' if seam_pending else ""
    return (
        f'<bpmn:intermediateCatchEvent id="{nid}">'
        f'<bpmn:extensionElements><aef:eventDef kind="message" binding="{binding}"/>'
        f"{meta}</bpmn:extensionElements></bpmn:intermediateCatchEvent>"
    )


def _throw_typed(nid, binding):
    return (
        f'<bpmn:intermediateThrowEvent id="{nid}">'
        f'<bpmn:extensionElements><aef:eventDef kind="message" binding="{binding}"/>'
        f"</bpmn:extensionElements></bpmn:intermediateThrowEvent>"
    )


def _store(tmp_path, registry_ghosts=()):
    store = tmp_path / "projects"
    d = store / "live-map"
    d.mkdir(parents=True)
    (d / "meta.json").write_text(json.dumps({"id": "live-map", "uuid": LIVE_UUID, "latest": 0}))
    if registry_ghosts:
        (store / "registry.yaml").write_text(
            "ghosts:\n" + "".join(f"- uuid: {u}\n" for u in registry_ghosts))
    return store


def _store_multi(tmp_path):
    """Store with one map whose v1 carries a legacy-ref finding and whose
    latest (v2) is clean — so all-versions mode sees a finding the default
    (latest-only) sweep does not."""
    store = tmp_path / "projects"
    d = store / "multi-map"
    d.mkdir(parents=True)
    (d / "meta.json").write_text(json.dumps({
        "id": "multi-map", "uuid": LIVE_UUID, "latest": 2,
        "versions": [{"v": 1}, {"v": 2}],
    }))
    (d / "v1.bpmn").write_text(HEAD + _throw("n1", 'targetWorkflow="live-map" linkId=""') + TAIL)
    (d / "v2.bpmn").write_text(HEAD + TAIL)
    return store


def _lint(xml_body, store, name="m", editor_resolves_uuid=True):
    # editor_resolves_uuid=True keeps the pre-T-2612 rule fixtures hermetic from
    # the repo's live pin state; the editor-unbindable tests pass False explicitly.
    idx = corpus_lint.store_index(store)
    ghosts = corpus_lint._registry_ghost_uuids(store)
    findings, typed = corpus_lint.lint_map(
        name, HEAD + xml_body + TAIL, idx, ghosts,
        editor_resolves_uuid=editor_resolves_uuid)
    findings.extend(corpus_lint.cross_map_typed_events(typed))
    return findings


def _rules(findings):
    return sorted({f["rule"] for f in findings})


# ── legacy-ref (origin T-2600) ────────────────────────────────────────────────

def test_legacy_ref_fires_on_targetworkflow_form(tmp_path):
    store = _store(tmp_path)
    f = _lint(_throw("n1", 'targetWorkflow="live-map" linkId=""'), store)
    assert _rules(f) == ["legacy-ref"], f


def test_legacy_ref_silent_on_uuid_form(tmp_path):
    store = _store(tmp_path)
    f = _lint(_throw("n1", f'workflowRef="{LIVE_UUID}" linkId=""'), store)
    assert f == [], f


# ── handoff-wiring (origin T-2600/T-2601) ─────────────────────────────────────

def test_wiring_fires_on_non_terminal_throw(tmp_path):
    store = _store(tmp_path)
    f = _lint(_throw("n1", f'workflowRef="{LIVE_UUID}"', outgoing="f_out"), store)
    assert _rules(f) == ["handoff-wiring"], f


def test_wiring_fires_on_duplicate_same_target_throws(tmp_path):
    store = _store(tmp_path)
    body = _throw("n1", f'workflowRef="{LIVE_UUID}"') + _throw(
        "n2", f'workflowRef="{LIVE_UUID}"')
    f = _lint(body, store)
    assert _rules(f) == ["handoff-wiring"], f
    assert "n1, n2" in f[0]["node"]


def test_wiring_silent_on_terminal_distinct_targets(tmp_path):
    store = _store(tmp_path, registry_ghosts=[GHOST_UUID])
    body = _throw("n1", f'workflowRef="{LIVE_UUID}"') + _throw(
        "n2", f'workflowRef="{GHOST_UUID}"')
    f = _lint(body, store)
    assert f == [], f


# ── emitterless-typed-event (origin T-2551) ───────────────────────────────────

def test_emitterless_fires_without_emitter(tmp_path):
    store = _store(tmp_path)
    f = _lint(_catch_typed("n1", "bus:task-channel"), store)
    assert _rules(f) == ["emitterless-typed-event"], f


def test_emitterless_silent_with_cross_map_emitter(tmp_path):
    store = _store(tmp_path)
    idx = corpus_lint.store_index(store)
    fa, ta = corpus_lint.lint_map("a", HEAD + _catch_typed("n1", "bus:x") + TAIL, idx, set())
    fb, tb = corpus_lint.lint_map("b", HEAD + _throw_typed("n2", "bus:x") + TAIL, idx, set())
    cross = corpus_lint.cross_map_typed_events(ta + tb)
    assert fa == fb == cross == []


def test_emitterless_silent_with_seam_marker(tmp_path):
    store = _store(tmp_path)
    f = _lint(_catch_typed("n1", "bus:task-channel", seam_pending=True), store)
    assert f == [], f


# ── editor-unbindable (origin T-2612) ─────────────────────────────────────────

def test_unbindable_fires_on_uuid_only_link_when_pin_cannot_resolve(tmp_path):
    store = _store(tmp_path)
    f = _lint(_throw("n1", f'workflowRef="{LIVE_UUID}" linkId=""'), store,
              editor_resolves_uuid=False)
    assert _rules(f) == ["editor-unbindable"], f


def test_unbindable_silent_with_dual_form_alias(tmp_path):
    store = _store(tmp_path)
    f = _lint(_throw("n1", f'targetWorkflow="live-map" workflowRef="{LIVE_UUID}" linkId=""'),
              store, editor_resolves_uuid=False)
    assert f == [], f


def test_unbindable_silent_when_pin_resolves_uuid(tmp_path):
    store = _store(tmp_path)
    f = _lint(_throw("n1", f'workflowRef="{LIVE_UUID}" linkId=""'), store,
              editor_resolves_uuid=True)
    assert f == [], f


def test_unbindable_exempts_registered_ghost_refs(tmp_path):
    store = _store(tmp_path, registry_ghosts=[GHOST_UUID])
    f = _lint(_throw("n1", f'workflowRef="{GHOST_UUID}" linkId=""'), store,
              editor_resolves_uuid=False)
    assert f == [], f


# ── dangling-flow-ref (origin T-2614) ─────────────────────────────────────────

def test_dangling_flow_ref_fires_on_missing_endpoint(tmp_path):
    store = _store(tmp_path)
    body = ('<bpmn:serviceTask id="n1" name="a"/>'
            '<bpmn:sequenceFlow id="f1" sourceRef="n1" targetRef="GONE_NODE"/>')
    f = _lint(body, store)
    assert _rules(f) == ["dangling-flow-ref"], f
    assert "GONE_NODE" in f[0]["detail"]


def test_dangling_flow_ref_silent_on_attached_graph(tmp_path):
    store = _store(tmp_path)
    body = ('<bpmn:serviceTask id="n1" name="a"/>'
            '<bpmn:subProcess id="n2" name="b"/>'
            '<bpmn:sequenceFlow id="f1" sourceRef="n1" targetRef="n2"/>')
    f = _lint(body, store)
    assert f == [], f


# ── ghost-ref (origin T-2584) ─────────────────────────────────────────────────

def test_ghost_ref_fires_on_silent_dangler(tmp_path):
    store = _store(tmp_path)
    f = _lint(_throw("n1", f'workflowRef="{DANGLER_UUID}"'), store)
    assert _rules(f) == ["ghost-ref"], f


def test_ghost_ref_silent_on_registered_ghost(tmp_path):
    store = _store(tmp_path, registry_ghosts=[GHOST_UUID])
    f = _lint(_throw("n1", f'workflowRef="{GHOST_UUID}"'), store)
    assert f == [], f


# ── map@vN addressing + all-versions sweep (origin T-2694) ────────────────────

def test_versioned_target_resolves_named_version(tmp_path):
    store = _store_multi(tmp_path)
    targets = corpus_lint.collect_targets(["multi-map@v1"], store)
    assert [n for n, _ in targets] == ["multi-map@v1"]
    idx = corpus_lint.store_index(store)
    ghosts = corpus_lint._registry_ghost_uuids(store)
    findings, _ = corpus_lint.lint_map("multi-map@v1", targets[0][1], idx, ghosts)
    assert _rules(findings) == ["legacy-ref"], findings


def test_versioned_target_resolves_a_different_version_than_latest(tmp_path):
    store = _store_multi(tmp_path)
    v1 = corpus_lint.collect_targets(["multi-map@v1"], store)[0][1]
    v2 = corpus_lint.collect_targets(["multi-map@v2"], store)[0][1]
    assert v1 != v2


def test_versioned_target_unknown_version_fails_loudly(tmp_path):
    import pytest
    store = _store_multi(tmp_path)
    with pytest.raises(SystemExit) as exc:
        corpus_lint.collect_targets(["multi-map@v99"], store)
    assert exc.value.code == 2


def test_versioned_target_unknown_map_fails_loudly(tmp_path):
    import pytest
    store = _store_multi(tmp_path)
    with pytest.raises(SystemExit) as exc:
        corpus_lint.collect_targets(["nope@v1"], store)
    assert exc.value.code == 2


def test_default_sweep_excludes_versioned_form_findings(tmp_path):
    """The default (latest-only) sweep must not see the v1-only finding —
    proves the two modes are genuinely separate lenses, not one relabeled."""
    store = _store_multi(tmp_path)
    targets = corpus_lint.collect_targets([], store)
    assert [n for n, _ in targets] == ["multi-map@v2"]


def test_all_versions_finds_what_default_sweep_does_not(tmp_path):
    store = _store_multi(tmp_path)
    default_targets = corpus_lint.collect_targets([], store)
    all_targets = corpus_lint.collect_all_versions(store)
    assert [n for n, _ in all_targets] == ["multi-map@v1", "multi-map@v2"]

    idx = corpus_lint.store_index(store)
    ghosts = corpus_lint._registry_ghost_uuids(store)

    default_findings = []
    for name, xml_text in default_targets:
        f, _ = corpus_lint.lint_map(name, xml_text, idx, ghosts)
        default_findings.extend(f)
    assert default_findings == []

    all_findings = []
    for name, xml_text in all_targets:
        f, _ = corpus_lint.lint_map(name, xml_text, idx, ghosts)
        all_findings.extend(f)
    assert _rules(all_findings) == ["legacy-ref"]
    assert all_findings[0]["map"] == "multi-map@v1"


def test_all_versions_includes_drafts(tmp_path):
    store = tmp_path / "projects"
    d = store / "draft-x"
    d.mkdir(parents=True)
    (d / "meta.json").write_text(json.dumps({
        "id": "draft-x", "uuid": LIVE_UUID, "latest": 1, "versions": [{"v": 1}],
    }))
    (d / "v1.bpmn").write_text(HEAD + TAIL)
    # excluded from the default sweep (T-2623)...
    assert corpus_lint.collect_targets([], store) == []
    # ...but included in the all-versions sweep (T-2694 decision — see
    # collect_all_versions docstring + task Decisions section)
    assert [n for n, _ in corpus_lint.collect_all_versions(store)] == ["draft-x@v1"]


# ── live-corpus expectations (as-served today; updated by T-2605 recreate) ────

def test_live_corpus_current_findings():
    """As-served reality after the T-2605 first recreate (aef-dispatch-loop)
    and the T-2609 rollout (aef-task-lifecycle, aef-inception-flow): every
    corpus map's own legacy-ref was resolved by identity-preserving
    regeneration via `fw corpus prove` (contract v0 uuid workflowRef form,
    uuids preserved). Two findings remain BY DESIGN:
    - t2584-scratch legacy-ref: fixture map whose ghost-target ref exists to
      exercise the T-2584 ghost registry — not recreated on purpose.
    - agt_msg_result emitterless-typed-event: PERMANENT by decision — T-2551
      consumption NO-GO (operator-recorded 2026-07-22): AEF has no consumer
      for trigger annotations (resolver reads 6 frontmatter fields, none
      trigger-shaped); the no-silent-drop guarantee is covered by the T-2552
      compile WARN. Revisit condition: flip only if AEF grows a
      trigger-consuming execution engine — then this catch gets an emitter
      and this pin shrinks.
    Update this pin deliberately when either of those moves.

    T-2612: this test runs lint against the LIVE pin capability flag
    (resolves_workflow_ref) — so it also asserts the served corpus stays
    bindable by the pinned editor: while the flag is false, every corpus
    handoff must carry the targetWorkflow compat alias (dual-form), else
    editor-unbindable appears here and the assert names the regressed map."""
    store = REPO_ROOT / ".context" / "designer" / "projects"
    idx = corpus_lint.store_index(store)
    ghosts = corpus_lint._registry_ghost_uuids(store)
    targets = corpus_lint.collect_targets([], store)
    findings, typed = [], []
    for name, xml_text in targets:
        f, t = corpus_lint.lint_map(name, xml_text, idx, ghosts)
        findings.extend(f)
        typed.extend(t)
    findings.extend(corpus_lint.cross_map_typed_events(typed))
    pinned = sorted((f["rule"], f["map"].split("@")[0]) for f in findings)
    assert pinned == [
        ("emitterless-typed-event", "aef-dispatch-loop"),
        ("lane-geometry", "aef-session-lifecycle"),
        ("lane-overflow", "aef-session-lifecycle"),
        ("legacy-ref", "t2584-scratch"),
    ], (
        "live-corpus lint drifted from the T-2609 post-rollout baseline — a new "
        "legacy-ref means a map regressed to a legacy-form save; a missing "
        "finding means t2584-scratch or T-2551 moved (update deliberately)",
        findings,
    )
    # T-2684 deliberate baseline move (2 → 3): the lane-geometry rule shipped and
    # immediately found a real disagreement in a PROMOTED map — aef-session-lifecycle
    # declares `human` above `agent` while 3 agent-declared nodes are drawn inside the
    # human band, so the diagram and flowNodeRef disagree about who owns those steps.
    # Reconciling it is an authority call reserved for the operator (see T-2684
    # Context), so this entry is expected to stand until that decision lands — at
    # which point it should DISAPPEAR, not be re-pinned. The default scan skips
    # `draft-*`; three drafts also disagree and surface when named explicitly.
    #
    # T-2689 deliberate baseline move (3 → 4): the lane-overflow rule's occupancy leg
    # landed and found a SECOND, independent defect in the same promoted map. Same map,
    # different class — lane-geometry (above) says human/agent membership and geometry
    # disagree; this one says the agent band is 6px too short to contain its own
    # content, measured with 832's own botOf (rail 340). A 6px spill is small enough to
    # read as noise, which is exactly why it is pinned: it is a real render defect by
    # the renderer's own containment function, and the lowest node is a gateway (66px
    # occupancy, more than a 64px task), so neither the top-y form nor a height-only
    # table would have found it. Also expected to stand until the operator's authority
    # call on this map, and to DISAPPEAR then rather than be re-pinned.


def test_live_corpus_all_versions_census():
    """T-2694 first census, pinned: 32 stored versions across the live store
    (including drafts), 14 carrying findings — the default (latest-only)
    sweep above sees only 4. This is the count that motivated the task: most
    of the 14 were never judged by the current rule set before this mode
    existed. Update deliberately when the store grows or a rule changes.

    T-2786 deliberate baseline move (28 → 32 versions, findings held at 14),
    2026-08-04. The four added versions are `draft-arc-lifecycle` v1–v4, and
    every one of them is clean — which is why the version count moved and the
    findings count did not.

    The load-bearing check was NOT that both numbers were re-derived; it was
    that "14 then" and "14 now" are the SAME 14 rather than two changes that
    cancelled. `tools/corpus_lint.py` had changed (+72/-4) since the pin, so
    a rule-driven swap was live as a hypothesis. Ruled out by evidence, not
    assumption: over that range every `.bpmn` change under the store is an
    ADD (no M, no D — pre-existing bytes are untouched), and the corpus_lint
    diff is purely additive reporting surface (`census_rows`, `_print_census`,
    `--summary`) with no rule predicate touched. Same bytes through the same
    rules yield the same verdicts, so the pre-existing 28 cannot have moved.

    If you are updating this pin again: re-derive all three values, enumerate
    the added versions by NAME, and if the findings count moves — especially
    if a version DROPS out of the flagged set — stop. A drop means a rule
    changed and is a different investigation, not a corpus-growth story."""
    store = REPO_ROOT / ".context" / "designer" / "projects"
    idx = corpus_lint.store_index(store)
    ghosts = corpus_lint._registry_ghost_uuids(store)
    targets = corpus_lint.collect_all_versions(store)
    assert len(targets) == 32, [n for n, _ in targets]

    findings, typed = [], []
    for name, xml_text in targets:
        f, t = corpus_lint.lint_map(name, xml_text, idx, ghosts)
        findings.extend(f)
        typed.extend(t)
    findings.extend(corpus_lint.cross_map_typed_events(typed))

    versions_with_findings = sorted({f["map"] for f in findings})
    assert len(versions_with_findings) == 14, versions_with_findings
    # the independently-confirmed headline witness (832 rail 342/343): the
    # pinned promotion candidate's v3 ancestor was never judged by us before
    # this mode existed, and reproduces their wholesale-inversion report
    # witness-for-witness.
    v3 = sorted(f["rule"] for f in findings if f["map"] == "draft-knowledge-leveling@v3")
    assert v3 == ["lane-geometry", "lane-overflow", "lane-overflow"], v3


def test_knowledge_leveling_overflow_was_repaired_then_regressed():
    """T-2695 — pins the CORRECTED timeline, because the first narrative
    written from this data was wrong in a way the data itself refutes.

    Rail 344 reported the spill as entering at v6 and being inherited
    unchanged by v7/v8. Both halves are false: v2/v3 already spill, v4/v5 are
    overflow-free, and v7/v8 spill at different magnitudes than v6. 832
    caught it at rail 345 from the numbers we had reported to them.

    The absence at v4/v5 is the load-bearing assertion. It is what makes v6 a
    REGRESSION — someone fixed this once and the fix did not survive a
    re-authoring — rather than a property the map has always had. That
    distinction is what the operator's pending v8 promotion turns on, so a
    future re-narration that contradicts it should go red here.
    """
    store = REPO_ROOT / ".context" / "designer" / "projects"
    idx = corpus_lint.store_index(store)
    ghosts = corpus_lint._registry_ghost_uuids(store)

    def rules_at(v):
        name = f"draft-knowledge-leveling@v{v}"
        xml = (store / "draft-knowledge-leveling" / f"v{v}.bpmn").read_text()
        f, _ = corpus_lint.lint_map(name, xml, idx, ghosts)
        return sorted(x["rule"] for x in f)

    overflow = {v: rules_at(v).count("lane-overflow") for v in range(2, 9)}
    assert overflow == {2: 2, 3: 2, 4: 0, 5: 0, 6: 2, 7: 2, 8: 2}, overflow

    # v7/v8 do not "inherit" v6's spill — different witnesses, so a reader
    # comparing only counts would call these the same defect.
    def overflow_witnesses(v):
        name = f"draft-knowledge-leveling@v{v}"
        xml = (store / "draft-knowledge-leveling" / f"v{v}.bpmn").read_text()
        f, _ = corpus_lint.lint_map(name, xml, idx, ghosts)
        return sorted(x["node"] for x in f if x["rule"] == "lane-overflow")

    assert overflow_witnesses(6) != overflow_witnesses(7), overflow_witnesses(6)

    # …and the geometry finding changes CLASS at v7: wholesale inversion
    # through v6, two-node subset call at v7/v8. Same rule, different repair,
    # different owner — this is the axis the operator is being asked about.
    def geometry_detail(v):
        name = f"draft-knowledge-leveling@v{v}"
        xml = (store / "draft-knowledge-leveling" / f"v{v}.bpmn").read_text()
        f, _ = corpus_lint.lint_map(name, xml, idx, ghosts)
        return next(x["detail"] for x in f if x["rule"] == "lane-geometry")

    assert "wholesale inversion" in geometry_detail(6)
    assert "wholesale inversion" not in geometry_detail(8)
    assert "subset crosses" in geometry_detail(8)


def test_census_summary_prints_clean_versions_and_carries_witnesses():
    """T-2695 — the summary must express an ABSENCE and an IDENTITY.

    Absence: if clean versions were omitted, the roll-up could not say
    "repaired at v4", which is the whole finding. Identity: a tally cannot
    tell v3's wholesale inversion from v8's authority call (832 rail 345), so
    every row carries its witness.
    """
    targets = [("m@v1", ""), ("m@v2", "")]
    findings = [{"map": "m@v2", "rule": "lane-overflow", "node": "a, b"}]
    skips = [{"map": "m@v1", "rule": "lane-overflow-skip", "detail": "x"}]
    rows = corpus_lint.census_rows(targets, findings, skips)

    assert [r["map"] for r in rows] == ["m@v1", "m@v2"]
    assert rows[0]["rules"] == [] and rows[0]["skipped_lanes"] == 1
    assert rows[1]["rules"] == [{"rule": "lane-overflow", "witness": "a, b"}]
