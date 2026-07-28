#!/usr/bin/env python3
"""Map-conformance rail — corpus map assertions vs the enforced state machine.

T-2621 shipped the first leg (aef-task-lifecycle vs status-transitions.yaml).
T-2654 (T-2652 GO slice 1) generalized it: which maps have a rail, and what
each conforms against, lives in ``tools/conformance-registry.yaml`` — the
checker dispatches on the entry's ``primitive``.

Primitives:
  transition-table  — collapse the map's ``aef:meta state=`` carrier nodes to
    transition pairs (walks pass through non-carriers, terminate at carriers,
    same-state pairs ignored) and compare against the source's
    ``transitions:`` list (``legacy: true`` entries excluded). This is the
    unchanged T-2621 behavior.
  vocabulary-set    — reserved (T-2652 slices 2-3). Registering a map with an
    unimplemented primitive is a load error (exit 2), not a silent skip: a
    registry entry is a claim that a rail exists.
  gate-referent     — reserved (T-2652 slices 2-3).

Modes:
  --map <id>   check one registry entry (default: aef-task-lifecycle,
               preserving the pre-T-2654 CLI contract for audit callers).
               A map absent from the registry is a load error.
  --all        iterate every registry entry; per-map verdict lines; exit is
               the worst individual result (0 aligned/skip, 1 divergent,
               2 load error).

Per-map results:
  PASS       — map asserts exactly the enforced set.
  SKIP       — map has zero carrier annotations (rail dormant, exit 0).
  DIVERGENT  — either direction: map-asserts/code-refuses (diagram documents
               a transition the framework rejects) or code-allows/map-lacks
               (enforcement permits a transition the diagram omits). Exit 1.

state= semantics are scoped per registry entry (T-2652 IW-4 working default):
different maps may carry different state kinds; the entry's primitive+source
define the meaning. Divergence is the finding, not a failure of the rail —
a map graduates to detail-authority only when its entry stays green (T-2619).
"""

import argparse
import json
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import corpus_spec  # noqa: E402

REGISTRY_REL = "tools/conformance-registry.yaml"
KNOWN_PRIMITIVES = ("transition-table",)  # vocabulary-set / gate-referent: T-2652 slices 2-3


class LoadError(Exception):
    """Registry/map/source could not be loaded — audit maps this to a WARN."""


def load_registry(root: Path) -> dict:
    reg_path = root / REGISTRY_REL
    if not reg_path.is_file():
        raise LoadError(f"registry not found: {REGISTRY_REL}")
    try:
        doc = yaml.safe_load(reg_path.read_text()) or {}
    except yaml.YAMLError as e:
        raise LoadError(f"registry unparseable: {e}") from e
    if not isinstance(doc, dict):
        raise LoadError("registry must be a mapping of map_id -> entry")
    for map_id, entry in doc.items():
        if not isinstance(entry, dict) or "primitive" not in entry or "source" not in entry:
            raise LoadError(
                f"registry entry '{map_id}' malformed: needs primitive + source keys"
            )
        if entry["primitive"] not in KNOWN_PRIMITIVES:
            raise LoadError(
                f"registry entry '{map_id}' names unknown primitive "
                f"'{entry['primitive']}' (known: {', '.join(KNOWN_PRIMITIVES)}); "
                "an entry is a claim that a rail exists — remove it or ship the extractor"
            )
        if not (root / entry["source"]).is_file():
            raise LoadError(
                f"registry entry '{map_id}' source missing: {entry['source']}"
            )
    return doc


def load_latest_spec(root: Path, map_id: str) -> dict:
    d = root / ".context/designer/projects" / map_id
    try:
        meta = json.loads((d / "meta.json").read_text())
        xml = (d / f"v{meta['latest']}.bpmn").read_text()
    except (OSError, ValueError, KeyError) as e:
        raise LoadError(f"map store unreadable for {map_id}: {e}") from e
    return corpus_spec.parse_map(xml)


# ── primitive: transition-table (T-2621 behavior, unchanged) ────────────────

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


def canonical_transitions(root: Path, source: str) -> set:
    try:
        doc = yaml.safe_load((root / source).read_text())
    except (OSError, yaml.YAMLError) as e:
        raise LoadError(f"source unreadable: {source}: {e}") from e
    return {
        (t["from"], t["to"])
        for t in (doc or {}).get("transitions", [])
        if not t.get("legacy")
    }


def check_transition_table(root: Path, map_id: str, entry: dict) -> int:
    """Returns 0 pass/skip, 1 divergent. Raises LoadError on load problems."""
    spec = load_latest_spec(root, map_id)
    canon = canonical_transitions(root, entry["source"])

    if carrier_count(spec) == 0:
        print(f"conformance: SKIP — {map_id} has no state-carrier nodes "
              "(aef:meta state=); rail only judges annotated maps")
        return 0

    asserted = asserted_transitions(spec)
    map_only = sorted(asserted - canon)
    code_only = sorted(canon - asserted)

    if not map_only and not code_only:
        print(f"conformance: PASS — {map_id} asserts exactly the "
              f"{len(canon)} enforced transitions")
        return 0

    print(f"conformance: DIVERGENT — {map_id}")
    for a, b in map_only:
        print(f"  map-asserts/code-refuses: {a} -> {b}")
    for a, b in code_only:
        print(f"  code-allows/map-lacks:    {a} -> {b}")
    return 1


PRIMITIVE_CHECKS = {
    "transition-table": check_transition_table,
}


def check_entry(root: Path, map_id: str, entry: dict) -> int:
    return PRIMITIVE_CHECKS[entry["primitive"]](root, map_id, entry)


def main() -> int:
    ap = argparse.ArgumentParser(prog="corpus_conformance")
    ap.add_argument("--map", default=None, dest="map_id",
                    help="check one registry entry (default: aef-task-lifecycle)")
    ap.add_argument("--all", action="store_true",
                    help="check every registry entry; exit = worst result")
    ap.add_argument("--root", default=str(REPO_ROOT), type=Path)
    args = ap.parse_args()

    try:
        registry = load_registry(args.root)
    except LoadError as e:
        print(f"conformance: load error: {e}", file=sys.stderr)
        return 2

    if args.all:
        worst = 0
        for map_id, entry in registry.items():
            try:
                worst = max(worst, check_entry(args.root, map_id, entry))
            except LoadError as e:
                print(f"conformance: load error for {map_id}: {e}", file=sys.stderr)
                worst = max(worst, 2)
        if not registry:
            print("conformance: registry empty — no maps have opted into a rail")
        return worst

    map_id = args.map_id or "aef-task-lifecycle"
    entry = registry.get(map_id)
    if entry is None:
        print(f"conformance: load error: {map_id} has no registry entry "
              f"({REGISTRY_REL}) — descriptive-only maps are not checkable",
              file=sys.stderr)
        return 2
    try:
        return check_entry(args.root, map_id, entry)
    except LoadError as e:
        print(f"conformance: load error for {map_id}: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
