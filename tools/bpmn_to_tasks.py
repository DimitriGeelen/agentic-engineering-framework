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
    """
    result: list[str] = []
    seen: set[str] = set()

    def walk(nid: str) -> None:
        for s in rev.get(nid, []):
            if s in seen:
                continue
            seen.add(s)
            if s in task_ids:
                if s not in result:
                    result.append(s)
            else:
                walk(s)

    walk(node_id)
    return result


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
            # O-3 (graduated v1.1, 832 T-195 / rail offset 47): an inception's go/no-go
            # boundary MUST be sovereignty-laned — assert and FAIL FAST on a malformed
            # one (machine-checkable G-3). This supersedes the pre-graduation
            # force-human+WARN (rail offset 39). A lane resolves to human either via the
            # authority-of-record (authority="sovereignty", preferred) or — for diagrams
            # predating laneMeta — a lane whose NAME indicates human (accepted with a
            # conformance WARN). Anything else (agent/initiative lane, or no sovereignty
            # signal at all) is a structural defect: raise.
            if lane_owner != "human":
                raise MalformedInceptionError(node_id, authority, lane_name)
            owner = "human"
            if authority != "sovereignty":
                warnings.append(
                    f"inception subProcess {node_id!r} is laned human by NAME only "
                    f"({lane_name!r}) with no <aef:laneMeta authority=\"sovereignty\"> — "
                    f"accepted for pre-laneMeta compatibility, but add the "
                    f"authority-of-record for v1.1 conformance"
                )
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
