#!/usr/bin/env python3
"""Child-2 forward compiler (first slice): BPMN process diagram -> AEF task skeletons.

Reads a BPMN 2.0 `.bpmn` file and emits one AEF task-skeleton frontmatter block per
task node (userTask / serviceTask / scriptTask). The stable task identity is the
`aef:uid` carried in each node's `<bpmn:extensionElements>` (IW-1 keystone, ratified
2026-07-11; 832 proved the seam round-trips both ways via T-187/T-188).

Design inputs (settled — see docs/reports/T-2522-bpmn-aef-mapping-contract.md and the
T-2523 DM rail):
  - IW-1: aef:uid lives in <extensionElements>; it is the modify/create discriminator.
  - IW-7: Lane = authority-of-record for who-performs. owner is compiled FROM the lane.
  - IW-9 (832 T-189 draft, pending Dimitri graduation): two orthogonal axes only —
    Lane (WHO) and workflow_type (KIND). Node-level `owner` override is REMOVED; a
    node's owner IS its lane. This compiler already honours that: it reads owner from
    the lane and ignores any node-level owner meta.
  - Ratified rulings: tier default = 1; AC-seeding = a real [NEEDS-FILL] skeleton,
    never a template placeholder.
  - O-1 (open, operator call): a serviceTask in a human lane resolves Lane-wins + WARN
    (antifragile — emit from the lane, warn, never refuse the whole diagram).

Slice 3 (T-2534): inception subProcess mapping. A <subProcess> bearing
<aef:meta workflowType="inception"> compiles to a skeleton with workflow_type:inception
and owner:human. The go/no-go is IMPLIED at the boundary (ratified G-3) — phase-1
collapsed subProcesses carry NO child gateway, so we synthesize the decision from the
marker, never by parsing a child <exclusiveGateway>. Owner comes from the lane's
authority-of-record (<aef:laneMeta authority="sovereignty"> ⇒ human). Per O-3 (graduated
v1.1, 832 T-195, rail offset 47), an inception's go/no-go boundary MUST be
sovereignty-laned: a mis-laned inception is malformed and the compiler FAILS FAST
(MalformedInceptionError) rather than silently forcing owner=human (the pre-graduation
interim, T-2537). The subProcess's <aef:constituents> steps surface as an AC-seed comment.
(Contract: 832 rail offset 32/34; scopeOf is the T-081 composition back-ref, NOT the
inception signal.)

Scope note: parse one .bpmn, extract task nodes + inception subProcesses + aef:uid +
lane, emit valid AEF task-skeleton frontmatter to stdout. Reverse direction
(tasks->diagram) is 832's, out of scope.

Namespace note: the compiler matches BPMN and aef elements by LOCAL NAME (namespace
prefix/URI agnostic), so it is forward-compatible with 832's actual `aef:` namespace
URI once the vendored corpus lands.
"""
from __future__ import annotations

import hashlib
import heapq
import os
import sys
import xml.etree.ElementTree as ET

TASK_TAGS = {"userTask", "serviceTask", "scriptTask"}
START_TAGS = {"startEvent"}
# Node-type -> the owner it *implies* (used only to WARN when it disagrees with the lane).
TYPE_OWNER = {"userTask": "human", "serviceTask": "agent", "scriptTask": "agent"}
# Flow-order tier -> AEF horizon (slice 2). Tier >=3 falls through to "later".
HORIZON_BY_TIER = {1: "now", 2: "next"}
# Slice 3 (T-2534): inception mapping. 832's ratified contract (rail offset 32/34):
#   - The inception marker is `workflowType="inception"` on a <bpmn:subProcess>'s
#     <aef:meta> (a scalar metaKey → serialized as a meta ATTRIBUTE, NOT scopeOf,
#     which is the T-081 composition back-ref). A subProcess WITH it ⇒ inception; a
#     plain collapsed subProcess WITHOUT it ⇒ ordinary composite (not emitted here).
#   - Phase-1 collapsed subProcesses emit NO child gateway — the go/no-go is IMPLIED
#     at the boundary (ratified G-3). We synthesize workflow_type:inception + owner
#     from the marker, never by parsing a child <exclusiveGateway>.
#   - Owner is derived from the lane's authority-of-record (IW-7/IW-9): a lane with
#     <aef:laneMeta authority="sovereignty"> ⇒ human. An inception go/no-go is a
#     sovereign decision (G-3/O-3), so owner is forced human even if mis-laned (warn).
INCEPTION_WORKFLOW_TYPE = "inception"
# Lane authority-of-record (aef:laneMeta authority=...) -> owner. Explicit and
# authoritative; preferred over the lane-name heuristic in _lane_owner.
AUTHORITY_OWNER = {"sovereignty": "human", "initiative": "agent"}
# OBS-118 / T-2717: values that ARE part of the AEF lane dialect but legitimately carry
# no owner. "authority" is the Framework lane (CLAUDE.md authority model:
# Framework=AUTHORITY / Agent=INITIATIVE / Human=SOVEREIGNTY) — the framework is the
# executor, so there is no human/agent owner to derive.
#
# BEHAVIOUR IS UNCHANGED from T-2567 (agent fallback, 832-ratified rail offset 95:
# "the executor is still the agent; what's lost is provenance"; no synthetic "framework"
# owner). Only the REPORTING splits. Before this, a known dialect value and a typo
# ("overlord") produced the same word — "unrecognized" — at the same severity, so the
# line fired on EVERY compile of any map with a Framework lane and could no longer
# distinguish anything (L-527: a signal that always fires stops meaning anything).
AUTHORITY_NO_OWNER = {"authority"}
# The full dialect, so an out-of-dialect value can be told what the valid set is.
AUTHORITY_DIALECT = set(AUTHORITY_OWNER) | AUTHORITY_NO_OWNER


class MalformedInceptionError(ValueError):
    """An inception subProcess is not sovereignty(human)-laned (O-3 / G-3, v1.1).

    Graduated 2026-07-12 (832 T-195, rail offset 47; Dimitri sovereign): an inception's
    go/no-go boundary MUST sit in a sovereignty lane. This is machine-checkable G-3 — a
    mis-laned inception is a structural defect the diagram author must fix, so the
    compiler fails fast rather than silently forcing owner=human (the pre-graduation
    interim behaviour, rail offset 39). Distinct from O-1 (task-type vs lane is
    presentational → lane wins + warn); a sovereign decision in a non-sovereign lane is
    structural, not presentational.
    """

    def __init__(self, node_id: str, authority: str | None, lane_name: str | None) -> None:
        self.node_id = node_id
        self.authority = authority
        self.lane_name = lane_name
        loc = authority or lane_name or "no lane"
        super().__init__(
            f"malformed inception: subProcess {node_id!r} carries "
            f'workflowType="inception" but sits in {loc!r}, not a sovereignty lane. '
            f"An inception go/no-go boundary MUST be sovereignty(human)-laned "
            f"(O-3/G-3, v1.1). Fix: move it to a lane with "
            f'<aef:laneMeta authority="sovereignty">.'
        )


def _local(tag: str) -> str:
    """Strip an XML namespace, returning the bare local name."""
    return tag.rsplit("}", 1)[-1] if "}" in tag else tag


def _lane_owner(lane_name: str) -> str | None:
    """Map a lane's display name to an owner, or None if the name is not indicative."""
    n = (lane_name or "").lower()
    if "human" in n or "user" in n or "operator" in n:
        return "human"
    if "agent" in n or "service" in n or "system" in n or "bot" in n:
        return "agent"
    return None


def _find_uid(node: ET.Element) -> str | None:
    """Return the aef:uid from a node's <extensionElements>, matched by local name.

    Two serializations are supported (T-2536 — cross-validation against 832's real
    corpus showed the ATTRIBUTE form is what ships; the text form was an AEF-twin
    assumption that silently masked the mismatch):
      - attribute (832 canonical): <aef:uid value="n_inception"/>
      - text:                       <aef:uid>n_inception</aef:uid>
    The `value` attribute is matched namespace-agnostically for robustness.
    """
    for ext in node:
        if _local(ext.tag) != "extensionElements":
            continue
        for child in ext.iter():
            if _local(child.tag) != "uid":
                continue
            # Attribute form (832 canonical) takes precedence.
            v = child.get("value")
            if v is None:
                for k, val in child.attrib.items():
                    if _local(k) == "value":
                        v = val
                        break
            if v and v.strip():
                return v.strip()
            # Text form (AEF twin fixtures).
            if (child.text or "").strip():
                return child.text.strip()
    return None


def _meta_attr(node: ET.Element, attr: str) -> str | None:
    """Return an attribute of the node's <aef:meta> element (scalar metaKeys serialize
    as attributes of the single <aef:meta>, per 832 rail offset 32). Matched by local
    name so it is namespace-agnostic — `workflowType`, `scopeOf`, etc."""
    for ext in node:
        if _local(ext.tag) != "extensionElements":
            continue
        for child in ext.iter():
            if _local(child.tag) != "meta":
                continue
            if attr in child.attrib:
                return child.attrib[attr]
            # Defensive: a namespaced attribute expands to `{uri}local` in ElementTree.
            for k, v in child.attrib.items():
                if _local(k) == attr:
                    return v
    return None


def _event_def(node: ET.Element) -> tuple[str, dict[str, str]] | None:
    """Return (kind, bindings) for a node bearing an <aef:eventDef>, else None.

    832's typed-event encoding (their T-204 Slice 1, rail offset 79): error/timer/message
    carried as <aef:eventDef kind="..." .../> on a NEUTRAL intermediateCatchEvent — no
    native bpmn:*EventDefinition. `kind` is the event class; every other attribute (e.g.
    errorStatus / timerSpec / busTopic) is returned as a binding. Matched by local name,
    consistent with _find_uid / _meta_attr, so it fires on 832's real aef: URI too.

    AEF does not CONSUME typed events yet — consumption semantics is scoped in T-2551.
    This helper exists so parse_bpmn can WARN that the annotation was seen but not applied,
    rather than silently dropping it (T-2552).
    """
    for ext in node:
        if _local(ext.tag) != "extensionElements":
            continue
        for child in ext.iter():
            if _local(child.tag) != "eventDef":
                continue
            kind = child.get("kind")
            if kind is None:
                for k, v in child.attrib.items():
                    if _local(k) == "kind":
                        kind = v
                        break
            bindings = {
                _local(k): v for k, v in child.attrib.items() if _local(k) != "kind"
            }
            return (kind or "unknown", bindings)
    return None


def _is_inception_subprocess(node: ET.Element) -> bool:
    """True iff node is a <subProcess> bearing <aef:meta workflowType="inception">.

    This is the ratified inception signal (rail offset 32) — NOT scopeOf, which is the
    T-081 composition back-ref. A plain collapsed subProcess (no such marker) is an
    ordinary composite and is not treated as an inception task here.
    """
    return (
        _local(node.tag) == "subProcess"
        and _meta_attr(node, "workflowType") == INCEPTION_WORKFLOW_TYPE
    )


def _constituents(node: ET.Element) -> list[str]:
    """Return the constituent labels from <aef:constituents><aef:constituent .../>.

    Phase-1 collapsed inception subProcesses list their steps as constituents (siblings,
    not embedded flow nodes) — e.g. gather evidence / assess criteria / record decision.
    We surface them as a traceability comment in the emitted skeleton (AC-seed hint).
    """
    out: list[str] = []
    for desc in node.iter():
        if _local(desc.tag) != "constituent":
            continue
        label = desc.get("name") or desc.get("ref") or desc.get("id")
        if label:
            out.append(label.strip())
    return out


def _lane_map(root: ET.Element) -> dict[str, str]:
    """Build nodeId -> lane-name from every <lane><flowNodeRef> in the document."""
    mapping: dict[str, str] = {}
    for lane in root.iter():
        if _local(lane.tag) != "lane":
            continue
        lane_name = lane.get("name") or lane.get("id") or ""
        for ref in lane:
            if _local(ref.tag) == "flowNodeRef" and (ref.text or "").strip():
                mapping[ref.text.strip()] = lane_name
    return mapping


def _lane_authority(root: ET.Element) -> dict[str, str]:
    """Build nodeId -> lane authority-of-record from <aef:laneMeta authority="..."> .

    IW-7/IW-9: a lane's authority (`sovereignty`/`initiative`) is the explicit
    who-performs signal. This is preferred over the lane-name heuristic (_lane_owner).
    """
    mapping: dict[str, str] = {}
    for lane in root.iter():
        if _local(lane.tag) != "lane":
            continue
        authority: str | None = None
        for desc in lane.iter():
            if _local(desc.tag) == "laneMeta" and desc.get("authority"):
                authority = desc.get("authority")
        if authority is None:
            continue
        for ref in lane:
            if _local(ref.tag) == "flowNodeRef" and (ref.text or "").strip():
                mapping[ref.text.strip()] = authority
    return mapping


def _node_types(root: ET.Element) -> dict[str, str]:
    """Map every element id -> its bare local tag name."""
    return {n.get("id"): _local(n.tag) for n in root.iter() if n.get("id")}


def _flows(root: ET.Element) -> tuple[dict[str, list[str]], dict[str, list[str]]]:
    """Build forward (source->targets) and reverse (target->sources) sequenceFlow maps."""
    fwd: dict[str, list[str]] = {}
    rev: dict[str, list[str]] = {}
    for f in root.iter():
        if _local(f.tag) != "sequenceFlow":
            continue
        src, tgt = f.get("sourceRef"), f.get("targetRef")
        if src and tgt:
            fwd.setdefault(src, []).append(tgt)
            rev.setdefault(tgt, []).append(src)
    return fwd, rev


def _task_tier(node_id: str, fwd, task_ids, starts) -> int | None:
    """Min number of task-nodes on any path from a start event to node_id (inclusive).

    0-1 shortest path: stepping INTO an emitted task node costs 1, into anything else
    (event, gateway, plain composite) costs 0. `task_ids` is the set of node ids that
    become AEF tasks — task tags PLUS inception subProcesses (slice 3), so an inception
    subProcess is counted in flow-order like any other task. Returns None if unreachable.
    """
    inf = float("inf")
    dist: dict[str, float] = {}
    pq: list[tuple[float, str]] = []
    for s in starts:
        d0 = 1 if s in task_ids else 0
        if d0 < dist.get(s, inf):
            dist[s] = d0
            heapq.heappush(pq, (d0, s))
    while pq:
        d, u = heapq.heappop(pq)
        if d > dist.get(u, inf):
            continue
        for v in fwd.get(u, []):
            w = 1 if v in task_ids else 0
            nd = d + w
            if nd < dist.get(v, inf):
                dist[v] = nd
                heapq.heappush(pq, (nd, v))
    val = dist.get(node_id)
    return int(val) if val is not None else None


def _nearest_task_preds(node_id: str, rev, task_ids) -> list[str]:
    """Nearest emitted-task predecessor ids, transiting non-task nodes (events/gateways).

    `task_ids` includes inception subProcesses (slice 3), so a task downstream of an
    inception decision links back to it via related_tasks.

    T-2562: a node reached back through its OWN self-loop (A → gateway → A) is not a
    predecessor — a task never lists itself in related_tasks. Distinct-node back-edges
    (B → gateway → A, B ≠ A) still link normally; the walk also does not transit
    through the origin, so a pure self-loop contributes nothing.
    """
    result: list[str] = []
    seen: set[str] = set()

    def walk(nid: str) -> None:
        for s in rev.get(nid, []):
            if s in seen or s == node_id:
                continue
            seen.add(s)
            if s in task_ids:
                if s not in result:
                    result.append(s)
            else:
                walk(s)

    walk(node_id)
    return result


def _designer_store() -> str | None:
    """Designer store root: FW_DESIGNER_STORE override, else cwd-relative default.

    Same resolution convention as _stage_dir. Returns None when the directory
    does not exist — off-page-ref resolution is then undecidable and Pass 5
    emits ONE aggregate note instead of per-ref WARNs (T-2570 FP discipline:
    a compile outside any project must not spray unverifiable dangling-WARNs).
    """
    p = os.environ.get("FW_DESIGNER_STORE") or os.path.join(
        ".context", "designer", "projects"
    )
    return p if os.path.isdir(p) else None


def _store_identities(store: str) -> tuple[dict[str, str], set[str]]:
    """(uuid -> project slug, {slug}) from every meta.json in the designer store.

    Stdlib-only twin of web.designer_registry._known — the compiler stays
    dependency-free (no yaml, no web import path) and a consumer running the
    vendored CLI gets identical resolution semantics.
    """
    import json

    uuids: dict[str, str] = {}
    slugs: set[str] = set()
    try:
        entries = sorted(os.listdir(store))
    except OSError:
        return uuids, slugs
    for d in entries:
        mp = os.path.join(store, d, "meta.json")
        if not os.path.isfile(mp):
            continue
        try:
            with open(mp) as f:
                m = json.load(f)
        except (OSError, ValueError):
            continue
        slugs.add(d)
        if m.get("uuid"):
            uuids[m["uuid"]] = d
    return uuids, slugs


def parse_bpmn(path: str) -> tuple[list[dict], list[str]]:
    """Parse a .bpmn file into a list of task-skeleton dicts and a list of warnings."""
    tree = ET.parse(path)
    root = tree.getroot()
    lanes = _lane_map(root)
    lane_auth = _lane_authority(root)
    ntypes = _node_types(root)
    fwd, rev = _flows(root)
    starts = [nid for nid, t in ntypes.items() if t in START_TAGS]
    warnings: list[str] = []

    # Pass 1: extract emitted nodes — task tags PLUS inception-marked subProcesses
    # (slice 3). Record node_id -> uid for linking and owner resolution.
    raw: list[dict] = []
    uid_by_node: dict[str, str] = {}
    # T-2567: authority values outside AUTHORITY_OWNER (e.g. "authority" on a
    # Framework lane) are semantically lossy — the lane's authority provenance has
    # no owner in the AEF task model, so nodes fall back to name/type derivation.
    # Collect the folds per (authority, lane) and surface ONE aggregated WARN each
    # after the loop (WARN-first discipline; fallback behavior itself unchanged).
    # Design ratified by 832 (rail offset 95): agent-fallback + WARN, no synthetic
    # "framework" owner — the executor is still the agent; what's lost is provenance.
    unknown_auth: dict[tuple[str, str], list[str]] = {}
    for node in root.iter():
        ntype = _local(node.tag)
        is_inception = _is_inception_subprocess(node)
        if ntype not in TASK_TAGS and not is_inception:
            continue
        node_id = node.get("id") or ""
        name = node.get("name") or node_id
        uid = _find_uid(node)
        if not uid:
            uid = node_id
            warnings.append(f"node {node_id!r} has no aef:uid — falling back to node id")

        lane_name = lanes.get(node_id)
        authority = lane_auth.get(node_id)
        # Authority-of-record (aef:laneMeta) is explicit and wins over the name heuristic.
        auth_owner = AUTHORITY_OWNER.get(authority) if authority else None
        lane_owner = auth_owner or (
            _lane_owner(lane_name) if lane_name is not None else None
        )

        constituents: list[str] = []
        if is_inception:
            workflow_type = INCEPTION_WORKFLOW_TYPE
            constituents = _constituents(node)
            # O-3 (v1.1, VETO-tightened per 832 rail offset 49/50): an inception's go/no-go
            # boundary MUST be sovereignty-laned, and <aef:laneMeta authority> is the SOLE
            # authority-of-record (mapping-v1 §3, IW-9). Only authority="sovereignty" satisfies
            # it. A lane NAME ("Human") is NOT an authority carrier — so name-only-Human,
            # no-lane, laneMeta-without-@authority, and any non-sovereignty authority ALL fail
            # §7 identically. Fail fast (machine-checkable G-3). This supersedes T-2537's
            # pre-laneMeta accept+WARN ramp, which forked conformance against 832's reference
            # validator: the compat case it protected provably cannot arise (every conformant
            # editor emits @authority; the importer defaults missing→'none', never name-derived).
            # This is an EXISTENCE rule — it must fire HARDEST on absent input (contrast O-1
            # below, a comparison that correctly no-ops on absence). Keying off `authority`
            # directly (not the name-folded `lane_owner`) structurally excludes the name
            # heuristic from the sovereignty gate. See PL-035 / T-2540 RCA.
            if authority != "sovereignty":
                raise MalformedInceptionError(node_id, authority, lane_name)
            owner = "human"
        else:
            workflow_type = "build"  # KIND axis (ratified default for ordinary task nodes)
            type_owner = TYPE_OWNER.get(ntype)
            if lane_owner is not None:
                owner = lane_owner
                # O-1: Lane wins, but warn when the node type implies a different executor.
                if type_owner and type_owner != lane_owner:
                    warnings.append(
                        f"node {node_id!r} ({ntype}) sits in lane "
                        f"{authority or lane_name!r} (owner={lane_owner}); type implies "
                        f"{type_owner} — Lane wins (O-1)"
                    )
            else:
                owner = type_owner or "agent"
                if lane_name is None:
                    warnings.append(
                        f"node {node_id!r} is in no lane — owner defaulted from type "
                        f"({owner})"
                    )
            if authority is not None and auth_owner is None:
                unknown_auth.setdefault((authority, lane_name or node_id), []).append(
                    f"{uid}→{owner}"
                )

        raw.append(
            {
                "node_id": node_id,
                "uid": uid,
                "name": name,
                "owner": owner,
                "workflow_type": workflow_type,
                "constituents": constituents,
            }
        )
        uid_by_node[node_id] = uid

    # OBS-118 / T-2717: split the ONE channel T-2567 created into two messages. A
    # dialect value with no owner is EXPECTED; a value outside the dialect is a defect.
    # Both stay in `warnings` (signature unchanged, "surfaced not silent" preserved) —
    # what changes is that they no longer read identically.
    for (auth_val, lname), entries in unknown_auth.items():
        if auth_val in AUTHORITY_NO_OWNER:
            warnings.append(
                f"lane {lname!r} carries aef:laneMeta authority={auth_val!r} — the "
                f"framework is the executor, so there is no human/agent owner to derive "
                f"(expected, not a defect). Nodes fall back to name/type derivation: "
                f"{', '.join(entries)} (T-2567 behaviour, 832-ratified rail 95; message "
                f"split OBS-118/T-2717) — authority provenance is not representable in "
                f"task skeletons; surfaced here, not folded silently"
            )
        else:
            valid = ", ".join(sorted(AUTHORITY_DIALECT))
            warnings.append(
                f"lane {lname!r} carries unrecognized aef:laneMeta authority={auth_val!r} "
                f"— not a value in the AEF lane dialect ({valid}); this is very likely a "
                f"typo or an out-of-band value. AEF owner derivation knows "
                f"sovereignty→human / initiative→agent only; affected nodes fell back to "
                f"name/type derivation: {', '.join(entries)} (T-2567) — authority "
                f"provenance is not representable in task skeletons; surfaced here, not "
                f"folded silently"
            )

    task_ids = set(uid_by_node)

    # Pass 2: derive flow-order horizon + related_tasks (slice 2) and finalise skeletons.
    skeletons: list[dict] = []
    for r in raw:
        tier = _task_tier(r["node_id"], fwd, task_ids, starts)
        horizon = HORIZON_BY_TIER.get(tier, "later") if tier is not None else "now"
        related = [
            uid_by_node[p]
            for p in _nearest_task_preds(r["node_id"], rev, task_ids)
            if p in uid_by_node
        ]
        skeletons.append(
            {
                "uid": r["uid"],
                "name": r["name"],
                "owner": r["owner"],
                "workflow_type": r["workflow_type"],
                "tier": 1,  # ratified default (BVP/effort tier, distinct from flow-order tier)
                "horizon": horizon,
                "related_tasks": related,
                "constituents": r["constituents"],
            }
        )

    # Pass 3: surface typed-event annotations (T-2552). 832's T-204 Slice 1 encodes
    # error/timer/message as <aef:eventDef> on a neutral intermediateCatchEvent. Pass 2's
    # flow-walk TRANSITS these events (they feed related_tasks) but does NOT read the
    # eventDef — so its kind/binding would be dropped SILENTLY, indistinguishable from the
    # namespace-agnostic parse's intended forward-compat tolerance of unknown tags. AEF
    # does not consume typed events yet (scoped in T-2551); WARN so the annotation is never
    # silently lost. Detection is local-name-based, so it fires on 832's real aef: URI.
    for node in root.iter():
        ed = _event_def(node)
        if ed is None:
            continue
        kind, bindings = ed
        node_id = node.get("id") or "<anon>"
        bind_str = (
            " (" + ", ".join(f"{k}={v}" for k, v in sorted(bindings.items())) + ")"
            if bindings
            else ""
        )
        # T-2560: when the carrier is a boundaryEvent, the attachment IS the
        # semantics — which host it guards, whether it interrupts (cancelActivity,
        # BPMN default true when absent), and the perimeter position. 832 sanctioned
        # consuming attachedToRef/cancelActivity/aef:boundaryPos for WARN context
        # (rail, Spike-2 follow-up). Non-boundary carriers keep the exact prior text.
        boundary_str = ""
        if _local(node.tag) == "boundaryEvent":
            host = node.get("attachedToRef") or "<unattached>"
            interrupting = node.get("cancelActivity", "true")
            bpos = None
            for desc in node.iter():
                if _local(desc.tag) == "boundaryPos" and desc.get("value"):
                    bpos = desc.get("value")
            boundary_str = (
                f" [boundary: attached to {host!r}, "
                f"{'interrupting' if interrupting != 'false' else 'non-interrupting'}"
                + (f", boundaryPos={bpos}" if bpos else "")
                + "]"
            )
        warnings.append(
            f"node {node_id!r} carries a typed-event annotation (aef:eventDef "
            f"kind={kind}){bind_str}{boundary_str} — AEF does not consume typed events "
            f"yet (T-2551); surfaced here, not applied"
        )

    # Pass 4: surface gateway decision semantics (T-2557, arc-014 D1 finding). Pass 2's
    # flow-walk TRANSITS gateways (they shape related_tasks edges) but the DECISION itself —
    # which branch fires, and the branch-condition labels on the outgoing flows — has no
    # representation in the emitted skeletons. Same silent-loss class as Pass 3: without a
    # WARN, a dropped decision is indistinguishable from forward-compat tolerance.
    flow_names: dict[str, tuple[str, str]] = {}
    cond_flows: set[str] = set()  # flows carrying a conditionExpression (T-2570)
    for f in root.iter():
        if _local(f.tag) != "sequenceFlow":
            continue
        fid = f.get("id")
        if fid:
            flow_names[fid] = (f.get("name") or "", f.get("targetRef") or "")
            if any(_local(c.tag) == "conditionExpression" for c in f):
                cond_flows.add(fid)
    parallel_roles: list[str] = []  # "fork"/"join" per non-noop parallelGateway
    for node in root.iter():
        tag = _local(node.tag)
        if not tag.endswith("Gateway"):
            continue
        node_id = node.get("id") or "<anon>"
        gw_name = node.get("name") or ""
        branches = []
        for child in node:
            if _local(child.tag) != "outgoing":
                continue
            label, target = flow_names.get((child.text or "").strip(), ("", ""))
            branches.append(f"{label or '<unlabeled>'} → {target or '?'}")
        name_str = f" ({gw_name!r})" if gw_name else ""
        branch_str = "; ".join(branches) if branches else "<no outgoing flows>"
        # T-2569/T-2570 (832 taxonomy, rail offset 103 / their T-217): a
        # parallelGateway carries CONCURRENCY semantics, not decision semantics —
        # and a clean balanced fork/join round-trips faithfully (sibling
        # related_tasks + fan-in), so WARNing on it is a false positive at the
        # WARN level, not just wrong vocabulary. Occasion split:
        #   - condition on a fork edge  -> WARN (the CONDITION is ignored —
        #     "did you mean exclusiveGateway?"; W-PGW-CONDITION analogue)
        #   - no-op (in<=1 and out<=1)  -> WARN (W-PGW-NOOP analogue)
        #   - fork/join imbalance is a DIAGRAM-level smell, handled after the loop
        #   - balanced fork/join        -> silent (clean, matches 832's validator)
        # Choice gateways (exclusive/inclusive/complex) keep the T-2557 text.
        if tag == "parallelGateway":
            n_in = sum(1 for c in node if _local(c.tag) == "incoming")
            n_out = sum(1 for c in node if _local(c.tag) == "outgoing")
            conditioned = [
                b
                for c in node
                if _local(c.tag) == "outgoing"
                and (c.text or "").strip() in cond_flows
                for b in [flow_names.get((c.text or "").strip(), ("", ""))[1] or "?"]
            ]
            if conditioned:
                warnings.append(
                    f"node {node_id!r} is a parallelGateway{name_str} with a "
                    f"condition on fork edge(s) toward [{', '.join(conditioned)}] — "
                    f"a parallel fork takes all branches, so the condition is "
                    f"ignored — did you mean exclusiveGateway? (T-2570)"
                )
            if n_in <= 1 and n_out <= 1:
                warnings.append(
                    f"node {node_id!r} is a parallelGateway{name_str} with "
                    f"{n_in} incoming and {n_out} outgoing — neither forks nor "
                    f"joins (no-op) (T-2570)"
                )
            else:
                parallel_roles.append("fork" if n_out > 1 else "join")
        else:
            warnings.append(
                f"node {node_id!r} is a {tag}{name_str} with branches [{branch_str}] — "
                f"decision semantics are not representable in AEF task skeletons "
                f"(T-2557); surfaced here, not applied"
            )

    # T-2570 (W-PGW-UNBALANCED analogue): forks without any join (or vice versa)
    # mean parallel branches never reconverge — a diagram-level smell. Balanced
    # sets (>=1 fork AND >=1 join, or no parallel gateways at all) stay silent.
    if parallel_roles:
        forks = parallel_roles.count("fork")
        joins = parallel_roles.count("join")
        if forks and not joins:
            warnings.append(
                f"{forks} parallel fork(s) with no parallel join — branches never "
                f"reconverge (T-2570)"
            )
        elif joins and not forks:
            warnings.append(
                f"{joins} parallel join(s) with no parallel fork — nothing forked "
                f"to reconverge (T-2570)"
            )

    # Pass 5: off-page connector refs (T-2576, T-2571 S3). <aef:link> carries a
    # cross-workflow reference (contract v0, rail offsets 107-111): workflowRef=
    # <uuid> is the stable identity; legacy targetWorkflow=<slug> resolves by name
    # only. Neither is representable in task skeletons, so the compile-time
    # contract is WARN-per-defect resolved against the designer store — and
    # SILENT on cleanly resolved refs (T-2570 taxonomy discipline: a resolved
    # workflowRef round-trips faithfully; WARNing on it would be an FP). Matched
    # by local name like every other pass. WARN-only — skeleton output unchanged.
    links = [
        el
        for el in root.iter()
        if _local(el.tag) == "link"
        and (el.get("workflowRef") or el.get("targetWorkflow") or el.get("name"))
    ]
    if links:
        store = _designer_store()
        if store is None:
            warnings.append(
                f"{len(links)} off-page workflow ref(s) (aef:link) present but no "
                f"designer store found — resolution not checked (set "
                f"FW_DESIGNER_STORE or run from the project root) (T-2576)"
            )
        else:
            uuids, slugs = _store_identities(store)
            parent_of = {c: p for p in root.iter() for c in p}
            for link in links:
                host, cur = None, link
                while cur is not None:
                    cur = parent_of.get(cur)
                    if cur is not None and cur.get("id"):
                        host = cur
                        break
                hid = host.get("id") if host is not None else "<anon>"
                hname = (host.get("name") or "") if host is not None else ""
                href = f"node {hid!r}" + (f" ({hname!r})" if hname else "")
                wref = link.get("workflowRef")
                target = link.get("targetWorkflow") or link.get("name") or ""
                display = link.get("name") or target or "<unnamed>"
                if wref:
                    if wref in uuids:
                        continue  # resolved by uuid — clean, silent
                    warnings.append(
                        f"{href} references off-page workflow {display!r} via "
                        f"workflowRef {wref} — no live workflow owns that uuid "
                        f"(pending ghost) — create the workflow, then bind: "
                        f"fw bpmn claim {wref} <project> (T-2576)"
                    )
                elif target in slugs:
                    tuuid = next((u for u, s in uuids.items() if s == target), None)
                    hint = (
                        f'migrate the connector to workflowRef="{tuuid}" for '
                        f"stable identity"
                        if tuuid
                        else "target has no uuid yet — open+save it in the "
                        "designer to mint one, then migrate to workflowRef"
                    )
                    warnings.append(
                        f"{href} references off-page workflow {target!r} by legacy "
                        f"targetWorkflow slug — resolves by name today; {hint} "
                        f"(T-2576)"
                    )
                else:
                    warnings.append(
                        f"{href} references off-page workflow {display!r} by name "
                        f"only — no live workflow matches (pending ghost); see the "
                        f"gallery's unmapped-references markers (T-2576)"
                    )

    return skeletons, warnings


def render_skeleton(sk: dict) -> str:
    """Render one skeleton dict as an AEF task-skeleton frontmatter block."""
    # Emitted as real frontmatter with a [NEEDS-FILL] AC skeleton (never a template stub).
    name = sk["name"].replace('"', "'")
    related = sk.get("related_tasks", [])
    related_yaml = "[" + ", ".join(related) + "]" if related else "[]"
    # Inception constituents (aef:constituents) surface as an AC-seed hint — the
    # phase-1 collapsed go/no-go lists its steps here, not as embedded flow nodes.
    constituents = sk.get("constituents", [])
    constituents_line = ""
    if constituents:
        joined = ", ".join(constituents)
        constituents_line = (
            f"# constituents: [{joined}] — inception steps (aef:constituents); "
            f"seed as Agent/Human ACs\n"
        )
    return (
        "---\n"
        f"id: {sk['uid']}\n"
        f'name: "{name}"\n'
        f"owner: {sk['owner']}\n"
        f"workflow_type: {sk['workflow_type']}\n"
        f"tier: {sk['tier']}\n"
        f"horizon: {sk.get('horizon', 'now')}\n"
        f"related_tasks: {related_yaml}\n"
        "status: captured\n"
        f"{constituents_line}"
        "# acceptance_criteria: [NEEDS-FILL] — seed T-193 Agent/Human split before start\n"
        "---\n"
    )


def compile_to_tasks(path: str) -> tuple[str, list[str]]:
    """Compile a .bpmn to a string of concatenated skeleton blocks + warnings."""
    skeletons, warnings = parse_bpmn(path)
    return "\n".join(render_skeleton(s) for s in skeletons), warnings


# ── Write-out staging (T-2539, T-2538 GO candidate C) ────────────────────────
# The compiler stages skeletons as uid-keyed *proposals* — NOT tasks. Nothing is
# written under .tasks/, no T-ID is allocated, and the task gate is never invoked
# (C1). Promotion (proposals -> real tasks via `fw task create`, recording the
# uid<->T-ID cross-ref) is the SEPARATE slice gated on 832's id-mapping contract
# (IW-2). Proposals live under <stage_dir>/<diagram-stem>/ and upsert by uid so a
# re-compiled diagram never duplicates (C3, on IW-1 stable identity).
PROPOSAL_MARKER = (
    "# PROPOSAL — staged by `fw bpmn compile --write`; NOT a task. Promote via the "
    "gated task path (fw bpmn promote, T-2540) — never hand-copy into .tasks/."
)


def _stage_dir() -> str:
    """Root staging dir: FW_BPMN_STAGE_DIR override, else .context/bpmn-staged/."""
    return os.environ.get("FW_BPMN_STAGE_DIR") or os.path.join(".context", "bpmn-staged")


def _content_sha(text: str) -> str:
    """Short content hash for manifest change-detection."""
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def _yaml_q(s: str) -> str:
    """Double-quote + escape a scalar for safe manifest emission."""
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def render_proposal(sk: dict) -> str:
    """Render a skeleton as a STAGED PROPOSAL — `status: proposal` (a non-lifecycle
    marker, NOT a framework task status) plus the promote marker, so a proposal can
    never be mistaken for — or promoted as — a governed task without going through
    the gate."""
    body = render_skeleton(sk)
    return body.replace(
        "status: captured\n", "status: proposal\n" + PROPOSAL_MARKER + "\n"
    )


def write_proposals(
    skeletons: list[dict], diagram_path: str, stage_dir: str | None = None
) -> str:
    """Write uid-keyed proposals + a manifest to <stage_dir>/<diagram-stem>/. Idempotent.

    Upsert by uid: proposals for currently-emitted uids are (over)written; proposals whose
    uid is no longer emitted are pruned. Returns the output directory. NEVER writes under
    .tasks/ and never allocates a T-ID (C1) — proposals are proposals until promoted.
    """
    stage_dir = stage_dir or _stage_dir()
    stem = os.path.splitext(os.path.basename(diagram_path))[0]
    out_dir = os.path.join(stage_dir, stem)
    os.makedirs(out_dir, exist_ok=True)

    current_uids: set[str] = set()
    entries: list[tuple[str, dict, str]] = []
    for sk in skeletons:
        uid = sk["uid"]
        current_uids.add(uid)
        text = render_proposal(sk)
        with open(os.path.join(out_dir, f"{uid}.md"), "w", encoding="utf-8") as fh:
            fh.write(text)
        entries.append((uid, sk, _content_sha(text)))

    # Prune stale proposals — uids no longer emitted (node removed from the diagram).
    for fname in os.listdir(out_dir):
        if fname == "manifest.yaml" or not fname.endswith(".md"):
            continue
        if fname[:-3] not in current_uids:
            os.remove(os.path.join(out_dir, fname))

    lines = [
        f"diagram: {_yaml_q(os.path.basename(diagram_path))}",
        f"generated_from: {_yaml_q(diagram_path)}",
        "proposals:",
    ]
    for uid, sk, sha in sorted(entries):
        lines.append(f"  {uid}:")
        lines.append(f"    name: {_yaml_q(sk['name'])}")
        lines.append(f"    owner: {sk['owner']}")
        lines.append(f"    workflow_type: {sk['workflow_type']}")
        lines.append(f"    horizon: {sk.get('horizon', 'now')}")
        lines.append(f"    sha: {sha}")
    with open(os.path.join(out_dir, "manifest.yaml"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return out_dir


def main(argv: list[str]) -> int:
    write = False
    positional: list[str] = []
    for a in argv[1:]:
        if a == "--write":
            write = True
        else:
            positional.append(a)
    if len(positional) != 1:
        sys.stderr.write("usage: bpmn_to_tasks.py [--write] <path-to.bpmn>\n")
        return 2
    path = positional[0]
    try:
        skeletons, warnings = parse_bpmn(path)
    except MalformedInceptionError as e:
        # O-3 fail-fast (v1.1): a malformed inception is a structural diagram defect —
        # refuse the compile with an actionable message, exit non-zero.
        sys.stderr.write(f"ERROR: {e}\n")
        return 3
    for w in warnings:
        sys.stderr.write(f"WARN: {w}\n")
    if write:
        # Stage uid-keyed proposals (NOT tasks — no .tasks/ write, no gate). T-2539.
        out_dir = write_proposals(skeletons, path)
        sys.stderr.write(f"staged {len(skeletons)} proposal(s) -> {out_dir}/\n")
    # stdout emission is always preserved (default behaviour, --write is additive).
    out = "\n".join(render_skeleton(s) for s in skeletons)
    sys.stdout.write(out)
    if out and not out.endswith("\n"):
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
