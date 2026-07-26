#!/usr/bin/env python3
"""T-2621: map-conformance rail — corpus map edges vs the enforced state machine.

First selective spec-conformance leg (T-2619 GO: mirror-first + selective
conformance, task-lifecycle only). Answers structurally: does the
aef-task-lifecycle corpus map assert the same status transitions that
update-task.sh actually enforces (status-transitions.yaml via lib/enums.sh)?

Extraction convention (deterministic):
  - A node whose ``aef:meta`` carries ``state=<status>`` is a STATE CARRIER.
    Multiple nodes may carry the same state (e.g. start + do-work + review all
    hold ``started-work``).
  - From each carrier, walk outgoing flows through NON-carrier nodes
    (gateways, service tasks, events); the first carrier reached on a path
    terminates that walk and asserts the transition ``from.state -> to.state``.
    Walks never pass THROUGH a carrier.
  - Same-state pairs are ignored (parked->start is captured->started-work's
    business, not a transition of its own).
  - Maps with zero carriers are SKIPPED (INFO) — the rail only judges maps
    that opted into machine-readable state annotation.
  - Canonical set: status-transitions.yaml ``transitions:`` minus entries
    flagged ``legacy: true`` (compat shims, not process).

Divergence in either direction is reported and exits 1:
  - map-asserts / code-refuses: the diagram documents a transition the
    framework would reject.
  - code-allows / map-lacks: enforcement permits a transition the diagram
    does not show.

Exit codes: 0 aligned (or skipped), 1 divergent, 2 load/parse error.
"""

import argparse
import json
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import corpus_spec  # noqa: E402


def load_latest_spec(root: Path, map_id: str) -> dict:
    d = root / ".context/designer/projects" / map_id
    meta = json.loads((d / "meta.json").read_text())
    xml = (d / f"v{meta['latest']}.bpmn").read_text()
    return corpus_spec.parse_map(xml)


def asserted_transitions(spec: dict) -> set:
    """Collapse the flow graph to state-carrier transition pairs."""
    carriers = {
        n["id"]: n["meta"]["state"]
        for n in spec["nodes"]
        if (n.get("meta") or {}).get("state")
    }
    adj = {}
    for f in spec["flows"]:
        adj.setdefault(f["from"], []).append(f["to"])
    out = set()
    for src, s_state in carriers.items():
        seen = set()
        frontier = list(adj.get(src, []))
        while frontier:
            nid = frontier.pop()
            if nid in seen:
                continue
            seen.add(nid)
            if nid in carriers:
                if carriers[nid] != s_state:
                    out.add((s_state, carriers[nid]))
                continue  # carriers terminate the walk on this path
            frontier.extend(adj.get(nid, []))
    return out


def carrier_count(spec: dict) -> int:
    return sum(1 for n in spec["nodes"] if (n.get("meta") or {}).get("state"))


def canonical_transitions(root: Path) -> set:
    doc = yaml.safe_load((root / "status-transitions.yaml").read_text())
    return {
        (t["from"], t["to"])
        for t in doc.get("transitions", [])
        if not t.get("legacy")
    }


def main() -> int:
    ap = argparse.ArgumentParser(prog="corpus_conformance")
    ap.add_argument("--map", default="aef-task-lifecycle", dest="map_id")
    ap.add_argument("--root", default=str(REPO_ROOT), type=Path)
    args = ap.parse_args()

    try:
        spec = load_latest_spec(args.root, args.map_id)
        canon = canonical_transitions(args.root)
    except Exception as e:  # noqa: BLE001 — audit consumer needs the message, not a traceback
        print(f"conformance: load error for {args.map_id}: {e}", file=sys.stderr)
        return 2

    if carrier_count(spec) == 0:
        print(f"conformance: SKIP — {args.map_id} has no state-carrier nodes "
              "(aef:meta state=); rail only judges annotated maps")
        return 0

    asserted = asserted_transitions(spec)
    map_only = sorted(asserted - canon)
    code_only = sorted(canon - asserted)

    if not map_only and not code_only:
        print(f"conformance: PASS — {args.map_id} asserts exactly the "
              f"{len(canon)} enforced transitions")
        return 0

    print(f"conformance: DIVERGENT — {args.map_id}")
    for a, b in map_only:
        print(f"  map-asserts/code-refuses: {a} -> {b}")
    for a, b in code_only:
        print(f"  code-allows/map-lacks:    {a} -> {b}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
