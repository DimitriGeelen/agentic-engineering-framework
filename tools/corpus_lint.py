#!/usr/bin/env python3
"""corpus_lint — per-map + cross-map lint for the designer corpus (T-2604).

Every rule cites the observed defect class it exists to catch (T-2602 S3
discipline: no speculative rules — each one has a task-traceable origin).

  legacy-ref              aef:link carries targetWorkflow with no workflowRef.
                          Origin: T-2600 (the defective fix was authored in the
                          legacy form the same week the uuid contract was
                          ratified) + the as-served corpus itself.
  handoff-wiring          (a) a throw-handoff node with outgoing sequence flows —
                          throw handoffs are branch terminals (T-2571 wiring
                          invariant); (b) two+ throw-handoffs from one map
                          resolving to the same target workflow — the duplicate
                          glyph defect. Origin: T-2600/T-2601.
  emitterless-typed-event cross-map: a typed catch (aef:eventDef) whose binding
                          has no typed throw with the same binding anywhere in
                          the scanned corpus and no explicit seam marker
                          (aef:meta seamPending="..."). Origin: T-2551 gap —
                          agt_msg_result had no emitter and nothing noticed.
  ghost-ref               workflowRef uuid resolving to neither a store map nor
                          a pending-ref registry ghost. Registered ghosts are
                          deliberate (T-2584 flow) and NOT flagged.
  dangling-flow-ref       a sequenceFlow sourceRef/targetRef naming no element in
                          the map — renders as a disconnected graph (editor drops
                          the edge silently). Origin: T-2614 — the T-2609 recreate
                          dropped aef-inception-flow's subProcess (unknown tag,
                          silent parse skip) while keeping both flows through it.
  editor-unbindable       a workflowRef-only link to a resolvable store map while
                          the pinned designer build cannot auto-resolve uuid refs
                          (policy/designer-pin.yaml resolves_workflow_ref is
                          false/absent — 832 T-240 unlanded). The editor renders
                          "Target workflow — none —" and disables the jump: the
                          operator-surface handoff is dead even though the ref is
                          valid. Origin: T-2612 — the T-2605/T-2609 recreates
                          migrated the corpus to uuid form ahead of the consumer
                          capability and every corpus jump regressed. Fix: emit
                          the targetWorkflow compat alias (fw corpus generate does
                          this while the pin flag is false), or flip the pin flag
                          after a T-240-capable re-pin. Ghost refs are exempt (no
                          store slug exists to bind).
  lane-geometry           declared lane membership (flowNodeRef) contradicts node
                          geometry (aef:position y). The designer draws lane bands in
                          laneSet document order and places nodes at their stored
                          position without reconciling the two, so a disagreeing map
                          renders one authority assignment while flowNodeRef — what
                          `fw corpus explain` and every conformance rail read — reports
                          another. Lane membership is the authority axis in this
                          dialect, so that is a "who owns this step" misread, not a
                          cosmetic one. It also arms the write side: laneAtY(centerY)
                          rewrites membership from pixels on drag (832 T-310), so
                          touching a disagreeing map silently rewrites it. Detection is
                          deliberately origin-free (see lane_geometry). Origin: T-2684
                          / 832 T-310 — survey found 4 of 11 store maps disagreeing,
                          incl. one promoted map and two drafts in the taste queue.
  lane-overflow           a lane's own members occupy more vertical room than its
                          declared aef:laneMeta height, so the band cannot contain its
                          content and the render spills past the band edge. Sibling to
                          lane-geometry and deliberately orthogonal to it:
                          lane-geometry compares lanes AGAINST EACH OTHER and is
                          therefore structurally blind to this class — ordering can be
                          perfectly correct while a single lane overflows. Proven by
                          construction in T-2687 (a lane spanning 190px inside
                          height=100 is CLEAN under lane-geometry, caught here).
                          Origin: T-2687 GO / T-2688 — draft-knowledge-leveling's agent
                          lane spans 513px inside height=260, a 253px overflow on the
                          v8 promotion candidate that lane-geometry never named.
                          FULL-OCCUPANCY since T-2689: measures the drawn extent
                          max(botOf) - min(y) against the declared height, using 832's
                          own per-type constants (rail 340, answering our rail-338
                          question) rather than a guessed uniform box height. Occupancy
                          is events 54, gateways 66, tasks 64 — note that a gateway
                          takes more room than a task despite the smaller shape, so the
                          lowest node is not always the largest-y one. Supersedes the
                          T-2688 top-y form, which asked a MEMBERSHIP question
                          (span >= height) of a CONTAINMENT problem and was silent on
                          tight lanes; strictly stronger by arithmetic, pinned as a
                          test. A lane holding a type with no occupancy entry SKIPS
                          rather than defaulting — guessing a renderer constant is what
                          T-2684's band model cost (7 phantom findings on a clean map).
                          Those skips are PRINTED as exit-code-neutral NOTE lines
                          (T-2690, adopting 832's SKIP-not-PASS severity from rail 342):
                          with only present/absent, "evaluated and clean" reads exactly
                          like "never evaluated", which is the G-071 false green. Lanes
                          with no members or no declared height make no containment
                          claim and stay silent — out of scope, not unevaluable.
  unread-node-prose       a node extension child outside _KNOWN_EXT carrying non-empty
                          TEXT. Every reader of per-node annotation in this dialect is
                          attribute-based — corpus_spec._ext() builds from
                          dict(c.attrib), and the pinned designer's metaKeys vocabulary
                          is attributes too — so text in a child element is authored
                          content that no surface will ever display. It is not lost:
                          T-2614 added ext_raw so unrecognised children survive
                          round-trip verbatim. That is exactly what makes it silent —
                          the map is well-formed, lints clean under every other rule,
                          saves and reloads losslessly, and teaches nobody anything.
                          Nothing looks in ext_raw, so nothing ever says so.
                          ATTRIBUTE-only unknown children (aef:contextReads paths="…",
                          aef:artifactsWrites, aef:endpoint) are a legitimate in-use
                          shape and do NOT fire — the rule keys on text content, not on
                          the tag being unrecognised. Origin: T-2974 — ~8KB of operator
                          prose sat in aef:description children on
                          aef-greenfield-onboarding v1, invisible in both /designer and
                          fw corpus explain, and surfaced only as an operator saying the
                          diagram looked "pretty limited". Sibling to editor-unbindable:
                          same question (can the pinned reader show this?), asked of
                          prose instead of links. Fix is always the same — move it to
                          aef:meta note="…", encoding newlines as &#10;.

Exit codes: 0 clean, 1 findings, 2 usage/environment error.

Scans the live store's latest versions by default; pass map ids and/or .bpmn
file paths to scan a subset, `map@vN` to name a specific stored version
directly (unknown version fails loudly, never falls back to latest), or
--all-versions to sweep every stored version of every project (including
drafts) — off by default so the standing baseline never moves. Read-only —
never writes the store. Origin: T-2694 — the default sweep only ever judges
`latest`, so a version that passed under a weaker rule set is never
re-examined when the rules get stronger.
"""

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from corpus_spec import (  # noqa: E402
    BPMN_NS, STORE, UUID_RE, _ext, _KNOWN_EXT, _q, parse_map, store_index,
)

REPO_ROOT = Path(__file__).resolve().parent.parent


def _registry_ghost_uuids(store: Path) -> set:
    reg = store / "registry.yaml"
    if not reg.is_file():
        return set()
    # registry.yaml is small, flat, and written by the store; a targeted scan
    # avoids a yaml dependency mismatch with its writer.
    try:
        import yaml
        data = yaml.safe_load(reg.read_text()) or {}
    except Exception:
        return set()
    out = set()
    for g in data.get("ghosts", []) or []:
        u = g.get("uuid")
        if u:
            out.add(u)
    for c in data.get("claims", []) or []:
        u = c.get("uuid")
        if u:
            out.add(u)
    return out


def _pin_resolves_workflow_ref() -> bool:
    """policy/designer-pin.yaml `resolves_workflow_ref` — capability flag of the
    pinned editor build. False/absent until a T-240-capable release is pinned."""
    pin = REPO_ROOT / "policy" / "designer-pin.yaml"
    try:
        import yaml
        return bool((yaml.safe_load(pin.read_text()) or {}).get("resolves_workflow_ref"))
    except Exception:
        return False


def _iter_flow_nodes(proc):
    for el in proc:
        if isinstance(el.tag, str) and el.tag.startswith("{" + BPMN_NS):
            yield el


def lint_map(map_name: str, xml_text: str, idx: dict, ghost_uuids: set,
             editor_resolves_uuid: bool | None = None) -> tuple[list, list]:
    """Per-map findings + this map's typed-event contributions for the
    cross-map pass: (findings, [(kind, binding, direction, node_id), ...]).

    editor_resolves_uuid: None → read policy/designer-pin.yaml (live behavior);
    tests pass an explicit bool to stay hermetic from the repo's pin state."""
    if editor_resolves_uuid is None:
        editor_resolves_uuid = _pin_resolves_workflow_ref()
    findings = []
    typed = []
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError as e:
        return [{"rule": "malformed-xml", "map": map_name, "node": None,
                 "detail": str(e), "origin": "T-2564"}], typed
    proc = root.find(_q("process"))
    if proc is None:
        return findings, typed

    throw_targets = {}
    for el in _iter_flow_nodes(proc):
        local = el.tag.split("}")[-1]
        nid = el.get("id")
        ext = _ext(el)

        link = ext.get("link")
        if link is not None:
            wref = link.get("workflowRef")
            if not wref and link.get("targetWorkflow"):
                findings.append({
                    "rule": "legacy-ref", "map": map_name, "node": nid,
                    "detail": f'targetWorkflow="{link["targetWorkflow"]}" — legacy '
                              f"name-ref; contract v0 requires workflowRef uuid "
                              f"(regenerate via fw corpus, or re-author)",
                    "origin": "T-2600",
                })
            if wref:
                if not UUID_RE.match(wref):
                    findings.append({
                        "rule": "ghost-ref", "map": map_name, "node": nid,
                        "detail": f'workflowRef="{wref}" is not a uuid',
                        "origin": "T-2584",
                    })
                elif wref not in idx["by_uuid"] and wref not in ghost_uuids:
                    findings.append({
                        "rule": "ghost-ref", "map": map_name, "node": nid,
                        "detail": f'workflowRef="{wref}" resolves to neither a '
                                  f"store map nor a registered ghost (silent dangler)",
                        "origin": "T-2584",
                    })
                elif (not editor_resolves_uuid and wref in idx["by_uuid"]
                        and not link.get("targetWorkflow")):
                    findings.append({
                        "rule": "editor-unbindable", "map": map_name, "node": nid,
                        "detail": f'workflowRef-only link to '
                                  f'"{idx["by_uuid"][wref]}" — the pinned designer '
                                  f"build cannot bind a uuid-only target (jump "
                                  f"disabled; 832 T-240 unlanded). Regenerate via "
                                  f"fw corpus to emit the targetWorkflow compat "
                                  f"alias, or flip resolves_workflow_ref in "
                                  f"policy/designer-pin.yaml after a T-240-capable "
                                  f"re-pin",
                        "origin": "T-2612",
                    })
            if local == "intermediateThrowEvent":
                # wiring invariant (a): throw handoffs are branch terminals
                if el.find(_q("outgoing")) is not None:
                    findings.append({
                        "rule": "handoff-wiring", "map": map_name, "node": nid,
                        "detail": "throw-handoff has outgoing sequence flow(s) — "
                                  "handoff throws are branch terminals (T-2571)",
                        "origin": "T-2600/T-2601",
                    })
                target = wref or link.get("targetWorkflow") or ""
                target = idx["by_id"].get(target, target)  # normalize slug→uuid
                throw_targets.setdefault(target, []).append(nid)

        ev = ext.get("eventDef")
        if ev is not None:
            direction = ("catch" if local in ("intermediateCatchEvent", "boundaryEvent")
                         else "throw" if local == "intermediateThrowEvent" else local)
            seam = bool((ext.get("meta") or {}).get("seamPending"))
            typed.append({"map": map_name, "node": nid, "kind": ev.get("kind"),
                          "binding": ev.get("binding"), "direction": direction,
                          "seam_pending": seam})

    # wiring invariant (b): duplicate same-target throws in one map
    for target, nids in throw_targets.items():
        if target and len(nids) > 1:
            findings.append({
                "rule": "handoff-wiring", "map": map_name, "node": ", ".join(nids),
                "detail": f"{len(nids)} throw-handoffs target the same workflow "
                          f"({target}) — duplicate handoff glyphs",
                "origin": "T-2600/T-2601",
            })

    # dangling-flow-ref (T-2614): a sequenceFlow endpoint naming no element in
    # the map. This is exactly what renders as "the workflow is disconnected" —
    # the editor keeps the nodes it has and silently drops the dangling edges.
    # Origin: T-2609 recreate dropped aef-inception-flow's subProcess node
    # (parse didn't know the tag) while both flows through it survived.
    node_ids = {el.get("id") for el in proc
                if isinstance(el.tag, str) and el.get("id")
                and el.tag.split("}")[-1] != "sequenceFlow"}
    for el in proc:
        if isinstance(el.tag, str) and el.tag.split("}")[-1] == "sequenceFlow":
            for attr in ("sourceRef", "targetRef"):
                ref = el.get(attr)
                if ref and ref not in node_ids:
                    findings.append({
                        "rule": "dangling-flow-ref", "map": map_name,
                        "node": el.get("id"),
                        "detail": f'{attr}="{ref}" names no element in this map '
                                  f"— the edge will not render and the graph "
                                  f"falls apart (usually a dropped node; see "
                                  f"T-2614 parse data-loss class)",
                        "origin": "T-2614",
                    })

    findings.extend(unread_node_prose(map_name, proc))
    findings.extend(lane_geometry(map_name, xml_text))
    findings.extend(lane_overflow(map_name, xml_text))
    return findings, typed


def unread_node_prose(map_name: str, proc) -> list:
    """unread-node-prose: text in an extension child no reader reads.

    The trigger is TEXT, not the tag being unrecognised. Unknown children are
    normal and load-bearing in this dialect — ``aef:contextReads paths="…"``,
    ``aef:artifactsWrites``, ``aef:endpoint`` all live outside ``_KNOWN_EXT`` and
    round-trip through ``ext_raw`` by design. What no surface can render is
    *character data* on such a child: ``_ext()`` builds from ``dict(c.attrib)``,
    and the pinned designer's per-node vocabulary is attributes too, so the text
    reaches neither ``fw corpus explain`` nor the inspector panel.

    ``aef:endpoint`` is the deliberate exception: ``corpus_spec`` emits it as a
    text-bearing child (``<aef:endpoint>path</aef:endpoint>``) and the designer
    reads it back the same way, so its text is on a channel that does work.
    """
    findings = []
    for el in proc:
        if not isinstance(el.tag, str):
            continue
        if el.tag.split("}")[-1] in ("laneSet", "extensionElements"):
            continue
        ee = el.find(_q("extensionElements"))
        if ee is None:
            continue
        for child in ee:
            if not isinstance(child.tag, str):
                continue
            local = child.tag.split("}")[-1]
            if local in _KNOWN_EXT or local in _TEXT_BEARING_EXT:
                continue
            text = "".join(child.itertext()).strip()
            if not text:
                continue
            preview = " ".join(text.split())[:60]
            findings.append({
                "rule": "unread-node-prose", "map": map_name, "node": el.get("id"),
                "detail": f'<aef:{local}> carries {len(text)} chars of text '
                          f'("{preview}…") — every per-node reader in this dialect '
                          f"is attribute-based, so this renders in neither "
                          f"fw corpus explain nor the designer inspector. It is "
                          f"preserved verbatim (T-2614 ext_raw), which is what makes "
                          f'the loss silent. Move it to <aef:meta note="…"/>, '
                          f"encoding newlines as &#10; (a literal newline in an "
                          f"attribute value normalises to a space, XML 1.0 §3.3.3)",
                "origin": "T-2974",
            })
    return findings


#: Unknown-to-``_KNOWN_EXT`` children whose TEXT is genuinely read somewhere, so
#: text on them is not a finding. Kept separate from ``_KNOWN_EXT`` because that
#: set means "the parser lifts this into the spec", a different question.
_TEXT_BEARING_EXT = {"endpoint"}


def lane_geometry(map_name: str, xml_text: str) -> list:
    """lane-geometry: declared lane membership must agree with node geometry.

    The invariant, stated so it needs nothing the map does not carry: for lanes in
    laneSet **declaration order**, the y-ranges of their member nodes must be
    strictly ordered and non-overlapping. Declaration order is what the designer
    draws top-to-bottom, so an out-of-order or overlapping range means at least one
    node renders in a band other than the lane that claims it.

    Deliberately does NOT compute band boundaries from lane heights. That needs a
    band origin the map does not store, and guessing one (e.g. the topmost node)
    produces phantom findings — validated during T-2684 against the origin-free
    check, which it contradicted on draft-trigger-handling (7 phantom mismatches on
    a map whose spans are cleanly ordered). Heights tile the *canvas*, not
    necessarily the nodes.

    Reports one finding per violating lane pair, naming the **extremal witness
    pair**: the upper lane's lowest-drawn node and the lower lane's highest-drawn
    node. Those two are the minimal provable witness of the crossing under this
    invariant — no origin needed. On draft-knowledge-leveling v8 the pair resolves
    to exactly kl_healing + kl_dormant, independently matching 832's account of the
    two nodes their operator never dragged.

    Skips (rather than passing) when the invariant is not evaluable: fewer than two
    populated lanes, or any node missing a position. A silent pass on an
    unevaluable map is the G-071 failure shape this rule exists to avoid.
    """
    try:
        spec = parse_map(xml_text)
    except Exception:
        return []  # malformed XML is already reported by lint_map
    all_nodes = spec.get("nodes") or []
    lanes = [l.get("id") for l in (spec.get("lanes") or []) if l.get("id")]
    placed = [n for n in all_nodes if n.get("pos")]
    if len(lanes) < 2 or not placed or len(placed) != len(all_nodes):
        return []

    by_lane: dict = {}
    for n in placed:
        by_lane.setdefault(n.get("lane"), []).append(n)
    ordered = [l for l in lanes if by_lane.get(l)]
    if len(ordered) < 2:
        return []

    findings = []
    for upper, lower in zip(ordered, ordered[1:]):
        up, lo = by_lane[upper], by_lane[lower]
        u_last = max(up, key=lambda n: n["pos"][1])   # upper lane, drawn lowest
        l_first = min(lo, key=lambda n: n["pos"][1])  # lower lane, drawn highest
        if u_last["pos"][1] < l_first["pos"][1]:
            continue
        n_up = sum(1 for n in up if n["pos"][1] >= l_first["pos"][1])
        n_lo = sum(1 for n in lo if n["pos"][1] <= u_last["pos"][1])
        wholesale = n_up == len(up) and n_lo == len(lo)
        shape = (
            " Every node on both sides is on the wrong side — this is a wholesale "
            "inversion, so the likely defect is laneSet ordering, not node placement "
            "(reordering the laneSet is zero-semantic: canonical compare sorts lanes "
            "by id)." if wholesale else
            " A subset crosses, so the likely defect is node placement or a stale "
            "membership on the named nodes — that is an authority call, not a layout "
            "one."
        )
        findings.append({
            "rule": "lane-geometry", "map": map_name,
            "node": f'{u_last["id"]}, {l_first["id"]}',
            "detail": f'lane "{upper}" is declared above "{lower}" but their node '
                      f'geometry crosses: {u_last["id"]} (y={u_last["pos"][1]:.0f}, '
                      f'declared {upper}) is drawn at/below {l_first["id"]} '
                      f'(y={l_first["pos"][1]:.0f}, declared {lower}). '
                      f"{n_up}/{len(up)} {upper}-nodes and {n_lo}/{len(lo)} "
                      f"{lower}-nodes sit on the wrong side of the crossing.{shape} "
                      f"The render follows geometry while flowNodeRef follows "
                      f"membership, so the diagram and fw corpus explain disagree "
                      f"about who owns these steps",
            "origin": "T-2684 / 832 T-310",
        })
    return findings


# 832 rail 340 (2026-07-30), answering the question we asked at rail 338. These are
# the designer's own constants and its own containment function, quoted rather than
# inferred — src/aef-workflow-designer.html NODE_DEFAULTS (1759) and botOf (6975):
#
#   botOf(n)      = n.y + h(type) + (labelBelow(type) ? 18 : 0)
#   labelBelow(t) = startEvent | endEvent | linkEventThrow | linkEventCatch
#                   | t.startsWith('event') | t.endsWith('Gateway')
#   h(type)       = events 36 | gateways 48 | tasks and subProcess 64
#
# Keyed by OUR spec type (the left-hand side of corpus_spec.TYPE_TO_TAG), because
# 832's palette keys are not our BPMN tag names: our `catch`/`throw` serialise to
# intermediateCatchEvent/intermediateThrowEvent, which are their linkEventCatch /
# eventTimer / eventError family. Collapsing that family is safe for occupancy
# specifically — every event kind in their table is 36px with labelBelow true, so
# each occupies 54 regardless of which one a given node actually is.
#
# The inversion 832 flagged is exactly why this table stores occupancy and not h:
# a 36px EVENT occupies 54 and a 48px GATEWAY occupies 66, which is MORE than a
# 64px task. The smallest shapes are not the smallest occupants, so a per-type
# table built from h alone gets tight lanes wrong in the unsafe direction.
NODE_OCCUPANCY = {
    "start": 36 + 18, "end": 36 + 18,                  # events: name renders below
    "catch": 36 + 18, "throw": 36 + 18,
    "gateway": 48 + 18, "parallel-gateway": 48 + 18,   # *Gateway: name renders below
    "service": 64, "user": 64, "script": 64, "subprocess": 64,   # name inside the box
}

# 832: LANE_FIT_MARGIN = 12, applied at BOTH edges, so the height at which a lane is
# exactly Clean-fitted is content extent + 24. Advisory, deliberately NOT the
# threshold: a lane with less margin than this is not spilling, it is one Clean away
# from tidy. Gating on it would report tidiness as breakage.
LANE_FIT_MARGIN_BOTH_EDGES = 24


def lane_overflow(map_name: str, xml_text: str) -> list:
    """lane-overflow: a lane's declared height must be able to contain its own members.

    Orthogonal to lane_geometry, not a stronger version of it. lane_geometry compares
    lanes against EACH OTHER (are their spans ordered and disjoint?), which makes it
    structurally blind to a single lane whose content does not fit: ordering can be
    perfectly correct while one band overflows. T-2687 proved the blindness by
    construction — a lane spanning 190px inside height=100 is CLEAN under
    lane_geometry and caught here.

    **The basis changed in T-2689, and the reason matters more than the change.**
    T-2688 shipped this rule on node top-y with threshold ``span >= h``, derived from
    half-open band MEMBERSHIP: which lane does ``laneAtY(y)`` put a node in. That is
    the right question for ordering, and the wrong one here. What this rule actually
    claims is that the band cannot CONTAIN its content — a render question, answered
    by where the drawn box ends, not where its top-left corner sits. With 832's
    ``botOf`` (rail 340) that question is answerable exactly:

        extent = max(botOf(n)) - min(n.y)        overflow iff  extent > h

    Strict ``>``: a box whose bottom edge lands exactly on the band's bottom edge is
    contained, not spilling. This is the containment boundary, not the membership
    boundary — different question, different comparison, and conflating them is what
    made the first version conservative.

    **Strictly stronger, and this time by arithmetic rather than by survey.** Every
    map the top-y form caught is still caught: ``span >= h`` implies
    ``extent > h``, since ``extent = span + occupancy(lowest)`` and occupancy is
    always positive. The converse fails — a lane with ``span = h - 10`` and a 64px
    task at the bottom spills 54px and the old form was silent. T-2687 is the reason
    that sentence is phrased carefully: the identical "strictly stronger" claim about
    the ordering rule was FALSE, went out to 832 before it was checked, and had to be
    retracted at rail 338. The difference is that this one is a one-line proof over
    positive numbers, and it is pinned as a test rather than asserted in a docstring.

    **Occupancy is per-type and the ordering is not intuitive.** Events are 36px
    shapes that occupy 54 (their name renders below); gateways are 48px shapes that
    occupy 66; tasks are 64px shapes that occupy 64. So a gateway takes MORE vertical
    room than a task despite being the smaller shape, and the lowest-sitting node in a
    lane is not always the largest-y one. See NODE_OCCUPANCY above.

    Evaluates and skips PER LANE, not per map: one lane with an unpositioned member
    does not blind the rule to the others. An unevaluable lane skips rather than
    passing — a silent pass on something never checked is the G-071 shape. A node type
    with no occupancy entry is unevaluable for the same reason: we would have to guess
    its height, and guessing a renderer constant is the T-2684 band-model error that
    produced 7 phantom findings on a clean map.
    """
    return _lane_overflow_scan(map_name, xml_text)[0]


def lane_overflow_skips(map_name: str, xml_text: str) -> list:
    """Lanes that make a containment claim this rule could not judge.

    T-2690, adopting 832's SKIP-not-PASS severity (their rail 342): with only
    "finding" and "no finding", *evaluated and clean* is indistinguishable from
    *never evaluated* — the false green the rule exists to prevent, and the G-071
    shape exactly. They hit it first because their validator had only ERROR/WARN;
    ours has only present/absent, which is the same hole one notch narrower.

    Scope guard, also theirs and worth keeping: a lane with no members or no declared
    height makes NO containment claim, so it is out of scope rather than unevaluable
    and must not become permanent noise. Only a lane that claims a height AND holds
    content we cannot measure is reported here.

    Reported as exit-code-neutral notes, never as findings — a skip is an absence of
    judgement, and counting it as a defect would be its own kind of false signal.
    """
    return _lane_overflow_scan(map_name, xml_text)[1]


def _lane_overflow_scan(map_name: str, xml_text: str) -> tuple[list, list]:
    try:
        spec = parse_map(xml_text)
    except Exception:
        return [], []  # malformed XML is already reported by lint_map
    members: dict = {}
    for n in spec.get("nodes") or []:
        members.setdefault(n.get("lane"), []).append(n)
    findings: list = []
    skips: list = []
    for lane in spec.get("lanes") or []:
        lane_id = lane.get("id")
        nodes = members.get(lane_id) or []
        height = lane.get("height")
        # out of scope, not unevaluable: no members or no declared height means the
        # map makes no claim about this band's capacity. Silent on purpose.
        if not nodes or not height:
            continue
        # unevaluable WITH a claim -> visible skip, never a silent pass
        unplaced = [n["id"] for n in nodes if not n.get("pos")]
        unknown = sorted({n.get("type") for n in nodes
                          if n.get("pos") and n.get("type") not in NODE_OCCUPANCY})
        if unplaced or unknown:
            why = []
            if unplaced:
                why.append(f"{len(unplaced)} member(s) without aef:position "
                           f"({', '.join(unplaced[:3])}{'…' if len(unplaced) > 3 else ''})")
            if unknown:
                # a guessed default height is the T-2684 band-model error; skip instead
                why.append(f"node type(s) with no occupancy entry ({', '.join(unknown)})")
            skips.append({
                "rule": "lane-overflow-skip", "map": map_name, "lane": lane_id,
                "detail": f'lane "{lane_id}" declares height={height} but ' +
                          " and ".join(why) +
                          f" — this lane is SKIPPED by lane-overflow, not passed by it",
                "origin": "T-2690 (832 rail 342 SKIP-not-PASS)",
            })
            continue
        height = float(height)

        def _bot(n):
            return n["pos"][1] + NODE_OCCUPANCY[n["type"]]

        top = min(nodes, key=lambda n: n["pos"][1])
        # the LOWEST node by drawn bottom edge, which a largest-y sort would get wrong
        # whenever the bottom of the lane holds a task and a gateway sits just above it
        lowest = max(nodes, key=_bot)
        extent = _bot(lowest) - top["pos"][1]
        if extent <= height:
            continue
        fitted = extent + LANE_FIT_MARGIN_BOTH_EDGES
        findings.append({
            "rule": "lane-overflow", "map": map_name,
            "node": f'{top["id"]}, {lowest["id"]}',
            "detail": f'lane "{lane_id}" declares height={height:.0f} but its own members '
                      f'occupy {extent:.0f}px — from {top["id"]} at y={top["pos"][1]:.0f} '
                      f'down to the bottom edge of {lowest["id"]} '
                      f'({lowest["type"]}, y={lowest["pos"][1]:.0f} + '
                      f'{NODE_OCCUPANCY[lowest["type"]]}px occupancy) — spilling '
                      f'{extent - height:.0f}px past the band edge. flowNodeRef still '
                      f"claims every node, so membership reads correct while the render "
                      f"does not. Occupancy is per-type and not ordered by shape size "
                      f"(events 54, gateways 66, tasks 64), so the lowest node is not "
                      f"always the largest-y one. Two fixes, and choosing between them "
                      f'is an authoring call: raise "{lane_id}" height to {fitted:.0f} '
                      f"(content + the designer's 12px fit margin at both edges), or "
                      f"compress the node placement",
            "origin": "T-2687 GO / T-2688, occupancy leg T-2689 (832 rail 340)",
        })
    return findings, skips


def cross_map_typed_events(typed: list) -> list:
    """emitterless-typed-event: every catch binding needs a throw with the same
    binding somewhere in the scanned corpus, or an explicit seamPending marker."""
    findings = []
    emitted = {t["binding"] for t in typed if t["direction"] == "throw" and t["binding"]}
    for t in typed:
        if t["direction"] != "catch" or not t["binding"]:
            continue
        if t["binding"] in emitted or t["seam_pending"]:
            continue
        findings.append({
            "rule": "emitterless-typed-event", "map": t["map"], "node": t["node"],
            "detail": f'typed catch (kind={t["kind"]}, binding={t["binding"]}) has '
                      f"no typed throw with this binding in the scanned corpus and "
                      f'no seam marker (aef:meta seamPending="...")',
            "origin": "T-2551",
        })
    return findings


def _stored_versions(d: Path, meta: dict) -> list:
    """Sorted version ints this map has a .bpmn file for. Prefers the meta
    `versions` ledger; falls back to 1..latest for older meta shapes that
    predate it."""
    vs = sorted({int(e["v"]) for e in meta.get("versions") or [] if e.get("v")})
    if not vs:
        vs = list(range(1, int(meta.get("latest") or 0) + 1))
    return [v for v in vs if (d / f"v{v}.bpmn").is_file()]


def _resolve_versioned_target(t: str, store: Path):
    """`map@vN` → (name, xml_text), or None if `t` isn't that shape at all.

    Unknown version fails loudly (SystemExit(2)) rather than falling back to
    latest — that silent fallback is exactly the version-scope blind spot
    this addressing exists to close (T-2694)."""
    map_id, sep, vstr = t.rpartition("@v")
    if not sep or not vstr.isdigit():
        return None
    d = store / map_id
    mp = d / "meta.json"
    if not (d.is_dir() and mp.is_file()):
        print(f"corpus lint: not a file and not a store map id: {t}", file=sys.stderr)
        raise SystemExit(2)
    meta = json.loads(mp.read_text())
    v = int(vstr)
    available = _stored_versions(d, meta)
    if v not in available:
        print(f"corpus lint: {map_id} has no version v{v} — stored versions are "
              f"{available or '(none)'}", file=sys.stderr)
        raise SystemExit(2)
    return f"{map_id}@v{v}", (d / f"v{v}.bpmn").read_text()


def collect_targets(args_targets: list, store: Path) -> list:
    """[(name, xml_text)] — store map ids at latest version, `map@vN` at a
    named version, or file paths."""
    out = []
    if not args_targets:
        if not store.is_dir():
            raise SystemExit(2)
        for d in sorted(store.iterdir()):
            mp = d / "meta.json"
            if not (d.is_dir() and mp.is_file()):
                continue
            if d.name.startswith("draft-"):
                # T-2623 draft mode: drafts are the cheap iteration tier —
                # excluded from the corpus-wide baseline so sketch churn never
                # moves it. Lint a draft explicitly by naming it as a target.
                continue
            meta = json.loads(mp.read_text())
            v = int(meta.get("latest") or 0)
            f = d / f"v{v}.bpmn"
            if v >= 1 and f.is_file():
                out.append((f"{d.name}@v{v}", f.read_text()))
        return out
    for t in args_targets:
        p = Path(t)
        if p.is_file():
            out.append((str(p), p.read_text()))
            continue
        versioned = _resolve_versioned_target(t, store)
        if versioned is not None:
            out.append(versioned)
            continue
        d = store / t
        if d.is_dir():
            meta = json.loads((d / "meta.json").read_text())
            v = int(meta.get("latest") or 0)
            out.append((f"{t}@v{v}", (d / f"v{v}.bpmn").read_text()))
            continue
        print(f"corpus lint: not a file and not a store map id: {t}", file=sys.stderr)
        raise SystemExit(2)
    return out


def collect_all_versions(store: Path) -> list:
    """[(name@vN, xml_text)] for EVERY stored version of EVERY project.

    Includes drafts (T-2694 decision, recorded in the task's Decisions
    section): T-2623 excluded drafts from the default latest-only baseline so
    sketch churn never moves the gate — that is a baseline-stability
    decision. This mode is not the gate; it is an off-by-default lens for
    judging the corpus's whole history, and the census that motivated this
    function found its headline finding (a lane-overflow repair at v4 that
    regressed at v6 — see census_rows) inside a draft project. Excluding drafts here would hide exactly the
    blind spot this mode exists to close, so they stay in scope."""
    out = []
    if not store.is_dir():
        raise SystemExit(2)
    for d in sorted(store.iterdir()):
        mp = d / "meta.json"
        if not (d.is_dir() and mp.is_file()):
            continue
        meta = json.loads(mp.read_text())
        for v in _stored_versions(d, meta):
            out.append((f"{d.name}@v{v}", (d / f"v{v}.bpmn").read_text()))
    return out


def census_rows(targets: list, findings: list, skips: list) -> list:
    """One row per scanned version: its rule classes, each with its witness.

    Why this is machine-generated rather than written by hand (T-2695): the
    first all-versions census (T-2694) was correct, and the prose summary
    composed from scrolling its output was not. It claimed the
    knowledge-leveling spill "entered at v6", one paragraph below a table
    showing v2 and v3 already carrying it. The peer caught the contradiction
    from the numbers we had ourselves reported. Nothing could disagree with
    that summary because no summary existed except the sentence.

    Two shape decisions, both load-bearing:

    * Rows carry the WITNESS, not just a count. A tally cannot distinguish
      v3's wholesale inversion from v8's two-node authority call — both
      report 3 findings (832, rail 345).
    * Clean versions are PRINTED, not omitted. The census's most
      decision-relevant result was an absence: v4/v5 carry no overflow, which
      is what makes v6 a regression rather than an inherent property of the
      map. A summary that lists only offenders cannot express "repaired
      here", and repair-then-regress is a different conversation from
      never-fixed.

    Skips are carried per row for the same reason they are printed in the
    detail output (T-2690): a roll-up that silently drops them would rebuild
    the false green the skip channel exists to prevent.
    """
    by_map, skips_by_map = {}, {}
    for f in findings:
        by_map.setdefault(f["map"], []).append(f)
    for s in skips:
        skips_by_map[s["map"]] = skips_by_map.get(s["map"], 0) + 1
    rows = []
    for name, _ in targets:
        rows.append({
            "map": name,
            "rules": [{"rule": f["rule"], "witness": f["node"]}
                      for f in by_map.get(name, [])],
            "skipped_lanes": skips_by_map.get(name, 0),
        })
    return rows


def _print_census(rows: list) -> None:
    with_findings = sum(1 for r in rows if r["rules"])
    print(f"corpus lint: census — {len(rows)} version(s), "
          f"{with_findings} with finding(s)")
    width = max((len(r["map"]) for r in rows), default=0)
    for r in rows:
        parts = [f"{d['rule']}[{d['witness']}]" for d in r["rules"]] or ["clean"]
        if r["skipped_lanes"]:
            parts.append(f"+{r['skipped_lanes']} lane(s) skipped, not judged")
        print(f"  {r['map']:<{width}}  {'  '.join(parts)}")


def main(argv=None):
    ap = argparse.ArgumentParser(prog="fw corpus lint")
    ap.add_argument("targets", nargs="*",
                    help="map ids and/or .bpmn files (default: whole store, latest versions)")
    ap.add_argument("--store", default=None, help="override store path (tests)")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--all-versions", action="store_true",
                    help="judge EVERY stored version of every project (incl. drafts), "
                         "not just latest — off by default, whole-store only "
                         "(T-2694; does not combine with explicit targets)")
    ap.add_argument("--summary", action="store_true",
                    help="print one machine-generated row per scanned version "
                         "(rule classes + witnesses, clean versions included) "
                         "instead of the per-finding detail — T-2695")
    args = ap.parse_args(argv)

    store = Path(args.store) if args.store else STORE
    idx = store_index(store)
    ghost_uuids = _registry_ghost_uuids(store)
    if args.all_versions:
        if args.targets:
            print("corpus lint: --all-versions sweeps the whole store; it does not "
                  "combine with explicit targets", file=sys.stderr)
            raise SystemExit(2)
        targets = collect_all_versions(store)
    else:
        targets = collect_targets(args.targets, store)

    findings = []
    typed_all = []
    skips = []
    for name, xml_text in targets:
        f, typed = lint_map(name, xml_text, idx, ghost_uuids)
        findings.extend(f)
        typed_all.extend(typed)
        skips.extend(lane_overflow_skips(name, xml_text))
    findings.extend(cross_map_typed_events(typed_all))

    rows = census_rows(targets, findings, skips)

    if args.json:
        payload = {"scanned": [n for n, _ in targets],
                   "findings": findings, "skips": skips}
        if args.summary:
            payload["census"] = rows
        print(json.dumps(payload, indent=2))
    elif args.summary:
        _print_census(rows)
        print(f"{'CLEAN' if not findings else f'{len(findings)} finding(s)'}"
              f"{f' — {len(skips)} lane(s) skipped, not judged' if skips else ''}")
    else:
        print(f"corpus lint: scanned {len(targets)} map(s)")
        for f in findings:
            print(f"  [{f['rule']}] {f['map']} :: {f['node']} — {f['detail']} "
                  f"(origin {f['origin']})")
        # NOTE lines, deliberately after the findings and outside the count: a skip is
        # an absence of judgement, not a defect. Printed unconditionally rather than
        # behind a flag, because the whole point is that it must not be possible to
        # read a clean run as a complete one (832 rail 342, G-071 shape).
        for s in skips:
            print(f"  NOTE [{s['rule']}] {s['map']} :: {s['detail']} "
                  f"(origin {s['origin']})")
        print(f"{'CLEAN' if not findings else f'{len(findings)} finding(s)'}"
              f"{f' — {len(skips)} lane(s) skipped, not judged' if skips else ''}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
