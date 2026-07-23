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
        ("legacy-ref", "t2584-scratch"),
    ], (
        "live-corpus lint drifted from the T-2609 post-rollout baseline — a new "
        "legacy-ref means a map regressed to a legacy-form save; a missing "
        "finding means t2584-scratch or T-2551 moved (update deliberately)",
        findings,
    )
