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

Exit codes: 0 clean, 1 findings, 2 usage/environment error.

Scans the live store's latest versions by default; pass map ids and/or .bpmn
file paths to scan a subset. Read-only — never writes the store.
"""

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from corpus_spec import (  # noqa: E402
    BPMN_NS, STORE, UUID_RE, _ext, _q, parse_map, store_index,
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

    findings.extend(lane_geometry(map_name, xml_text))
    findings.extend(lane_overflow(map_name, xml_text))
    return findings, typed


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
    try:
        spec = parse_map(xml_text)
    except Exception:
        return []  # malformed XML is already reported by lint_map
    members: dict = {}
    for n in spec.get("nodes") or []:
        members.setdefault(n.get("lane"), []).append(n)
    findings = []
    for lane in spec.get("lanes") or []:
        lane_id = lane.get("id")
        nodes = members.get(lane_id) or []
        height = lane.get("height")
        # skip-not-pass: nothing to contain, no declared height, or an unplaced member
        if not nodes or not height or any(not n.get("pos") for n in nodes):
            continue
        # ...or a type whose occupancy we do not know. Skipping is the loud option:
        # the alternative is a default height, which is a guessed renderer constant.
        if any(n.get("type") not in NODE_OCCUPANCY for n in nodes):
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
    return findings


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


def collect_targets(args_targets: list, store: Path) -> list:
    """[(name, xml_text)] — store map ids at latest version, or file paths."""
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
        d = store / t
        if d.is_dir():
            meta = json.loads((d / "meta.json").read_text())
            v = int(meta.get("latest") or 0)
            out.append((f"{t}@v{v}", (d / f"v{v}.bpmn").read_text()))
            continue
        print(f"corpus lint: not a file and not a store map id: {t}", file=sys.stderr)
        raise SystemExit(2)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(prog="fw corpus lint")
    ap.add_argument("targets", nargs="*",
                    help="map ids and/or .bpmn files (default: whole store, latest versions)")
    ap.add_argument("--store", default=None, help="override store path (tests)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    store = Path(args.store) if args.store else STORE
    idx = store_index(store)
    ghost_uuids = _registry_ghost_uuids(store)
    targets = collect_targets(args.targets, store)

    findings = []
    typed_all = []
    for name, xml_text in targets:
        f, typed = lint_map(name, xml_text, idx, ghost_uuids)
        findings.extend(f)
        typed_all.extend(typed)
    findings.extend(cross_map_typed_events(typed_all))

    if args.json:
        print(json.dumps({"scanned": [n for n, _ in targets],
                          "findings": findings}, indent=2))
    else:
        print(f"corpus lint: scanned {len(targets)} map(s)")
        for f in findings:
            print(f"  [{f['rule']}] {f['map']} :: {f['node']} — {f['detail']} "
                  f"(origin {f['origin']})")
        print(f"{'CLEAN' if not findings else f'{len(findings)} finding(s)'}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
