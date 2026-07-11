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

Scope of THIS slice: parse one .bpmn, extract task nodes + aef:uid + lane, emit valid
AEF task-skeleton frontmatter to stdout. No CLI route / Watchtower page / write-back —
later Child-2 slices. Reverse direction (tasks->diagram) is 832's, out of scope.

Namespace note: the compiler matches BPMN and aef elements by LOCAL NAME (namespace
prefix/URI agnostic), so it is forward-compatible with 832's actual `aef:` namespace
URI once the vendored corpus lands.
"""
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET

TASK_TAGS = {"userTask", "serviceTask", "scriptTask"}
# Node-type -> the owner it *implies* (used only to WARN when it disagrees with the lane).
TYPE_OWNER = {"userTask": "human", "serviceTask": "agent", "scriptTask": "agent"}


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
    """Return the aef:uid text from a node's <extensionElements>, matched by local name."""
    for ext in node:
        if _local(ext.tag) != "extensionElements":
            continue
        for child in ext.iter():
            if _local(child.tag) == "uid" and (child.text or "").strip():
                return child.text.strip()
    return None


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


def parse_bpmn(path: str) -> tuple[list[dict], list[str]]:
    """Parse a .bpmn file into a list of task-skeleton dicts and a list of warnings."""
    tree = ET.parse(path)
    root = tree.getroot()
    lanes = _lane_map(root)
    warnings: list[str] = []
    skeletons: list[dict] = []

    for node in root.iter():
        ntype = _local(node.tag)
        if ntype not in TASK_TAGS:
            continue
        node_id = node.get("id") or ""
        name = node.get("name") or node_id
        uid = _find_uid(node)
        if not uid:
            uid = node_id
            warnings.append(f"node {node_id!r} has no aef:uid — falling back to node id")

        lane_name = lanes.get(node_id)
        lane_owner = _lane_owner(lane_name) if lane_name is not None else None
        type_owner = TYPE_OWNER.get(ntype)

        if lane_owner is not None:
            owner = lane_owner
            # O-1: Lane wins, but warn when the node type implies a different executor.
            if type_owner and type_owner != lane_owner:
                warnings.append(
                    f"node {node_id!r} ({ntype}) sits in lane {lane_name!r} "
                    f"(owner={lane_owner}); type implies {type_owner} — Lane wins (O-1)"
                )
        else:
            owner = type_owner or "agent"
            if lane_name is None:
                warnings.append(
                    f"node {node_id!r} is in no lane — owner defaulted from type ({owner})"
                )

        skeletons.append(
            {
                "uid": uid,
                "name": name,
                "owner": owner,
                "workflow_type": "build",  # KIND axis; typed-event/inception mapping is a later slice
                "tier": 1,  # ratified default
            }
        )
    return skeletons, warnings


def render_skeleton(sk: dict) -> str:
    """Render one skeleton dict as an AEF task-skeleton frontmatter block."""
    # Emitted as real frontmatter with a [NEEDS-FILL] AC skeleton (never a template stub).
    name = sk["name"].replace('"', "'")
    return (
        "---\n"
        f"id: {sk['uid']}\n"
        f'name: "{name}"\n'
        f"owner: {sk['owner']}\n"
        f"workflow_type: {sk['workflow_type']}\n"
        f"tier: {sk['tier']}\n"
        "status: captured\n"
        "# acceptance_criteria: [NEEDS-FILL] — seed T-193 Agent/Human split before start\n"
        "---\n"
    )


def compile_to_tasks(path: str) -> tuple[str, list[str]]:
    """Compile a .bpmn to a string of concatenated skeleton blocks + warnings."""
    skeletons, warnings = parse_bpmn(path)
    return "\n".join(render_skeleton(s) for s in skeletons), warnings


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        sys.stderr.write("usage: bpmn_to_tasks.py <path-to.bpmn>\n")
        return 2
    out, warnings = compile_to_tasks(argv[1])
    for w in warnings:
        sys.stderr.write(f"WARN: {w}\n")
    sys.stdout.write(out)
    if out and not out.endswith("\n"):
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
