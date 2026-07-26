#!/usr/bin/env python3
"""T-2622: agent retrieval seam — corpus maps readable without a browser.

Two modes:

  corpus_explain.py <map-id> [--root DIR]
      Render an agent-readable walkthrough of the latest stored version:
      lanes with authority levels, nodes in flow order with gateway branch
      labels, typed events, handoff targets, embedded notes — then a
      provenance footer stating the map's AUTHORITY STAGE per the T-2619
      cascading-detail model:
        - detail-authority        conformance rail green: the map holds the
                                  process detail; CLAUDE.md holds principles
                                  + a pointer. The map wins on detail conflict.
        - transitional-subordinate rail divergent, dormant, or absent: the map
                                  is descriptive; CLAUDE.md prose wins on
                                  conflict until the rail goes green.

  corpus_explain.py --search TERM [--root DIR]
      Retrieval seam for `fw search`: match TERM (case-insensitive) against
      map ids, titles, and node names across the corpus store; print one
      pointer block per matching map with the matched node names and the
      explain command. Prints nothing and exits 0 on no match, so callers
      can append output unconditionally.
"""

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import corpus_spec  # noqa: E402
import corpus_conformance as conformance  # noqa: E402


def store_dir(root: Path) -> Path:
    return root / ".context/designer/projects"


def load_latest(root: Path, map_id: str):
    d = store_dir(root) / map_id
    meta = json.loads((d / "meta.json").read_text())
    xml = (d / f"v{meta['latest']}.bpmn").read_text()
    return corpus_spec.parse_map(xml), meta


def flow_order(spec: dict) -> list:
    """Nodes in BFS order from start nodes; unreachable stragglers appended."""
    adj = {}
    for f in spec["flows"]:
        adj.setdefault(f["from"], []).append(f["to"])
    order, seen = [], set()
    frontier = [n["id"] for n in spec["nodes"] if n["type"] == "start"]
    while frontier:
        nid = frontier.pop(0)
        if nid in seen:
            continue
        seen.add(nid)
        order.append(nid)
        frontier.extend(adj.get(nid, []))
    order.extend(n["id"] for n in spec["nodes"] if n["id"] not in seen)
    return order


def authority_stage(root: Path, map_id: str) -> tuple:
    """(stage, rail_state) per the T-2619 cascading-detail model."""
    if map_id != "aef-task-lifecycle":
        return ("transitional-subordinate", "no conformance rail exists for this map")
    try:
        spec = conformance.load_latest_spec(root, map_id)
        canon = conformance.canonical_transitions(root)
    except Exception as e:  # noqa: BLE001
        return ("transitional-subordinate", f"rail unreadable: {e}")
    if conformance.carrier_count(spec) == 0:
        return ("transitional-subordinate", "rail dormant: map has no state-carrier annotations")
    asserted = conformance.asserted_transitions(spec)
    if asserted == canon:
        return ("detail-authority", "conformance rail GREEN: map transitions match enforcement exactly")
    diverging = sorted((asserted - canon) | (canon - asserted))
    pairs = ", ".join(f"{a}->{b}" for a, b in diverging)
    return ("transitional-subordinate", f"rail DIVERGENT: {pairs}")


def explain(root: Path, map_id: str) -> int:
    spec, meta = load_latest(root, map_id)
    nodes = {n["id"]: n for n in spec["nodes"]}
    lanes = {l["id"]: l for l in spec["lanes"]}
    out_flows = {}
    for f in spec["flows"]:
        out_flows.setdefault(f["from"], []).append(f)

    print(f"# {map_id} — {spec.get('title') or meta.get('title') or map_id}")
    print(f"version v{meta['latest']} · uuid {meta.get('uuid', '?')} · "
          f"{len(spec['nodes'])} nodes / {len(spec['flows'])} flows")
    if spec.get("doc"):
        print(f"\n{spec['doc'].strip()}")
    print("\n## Lanes")
    for l in spec["lanes"]:
        print(f"- {l['name']} (authority: {l.get('authority') or '?'})")

    print("\n## Walkthrough (flow order)")
    for nid in flow_order(spec):
        n = nodes[nid]
        lane = lanes.get(n.get("lane") or "", {})
        bits = [f"[{n['type']}]", n.get("name") or nid]
        if lane:
            bits.append(f"({lane.get('abbr') or lane.get('name')})")
        ev = n.get("event") or {}
        if ev.get("kind"):
            bits.append(f"<{ev['kind']} event>")
        print("- " + " ".join(bits))
        m = n.get("meta") or {}
        if m.get("state"):
            print(f"    state: {m['state']}")
        if m.get("note"):
            print(f"    note: {m['note']}")
        h = n.get("handoff") or {}
        if h:
            print(f"    handoff -> {h.get('name') or h.get('target')}")
        for f in out_flows.get(nid, []):
            label = f" — {f['name']}" if f.get("name") else ""
            tgt = nodes.get(f["to"], {})
            print(f"    -> {tgt.get('name') or f['to']}{label}")

    print("\n## Provenance")
    if map_id.startswith("draft-"):
        # T-2623 draft mode: drafts are never authority and sit outside the
        # retrieval index and lint baseline until promoted to a production id.
        print("authority stage: DRAFT — not authority at any stage")
        print("rail: n/a (drafts are excluded from lint baseline and retrieval; "
              "promotion to a production id pays the full ceremony)")
        print("precedence: none — a draft is a shared sketch, not a source of truth.")
        return 0
    stage, rail = authority_stage(root, map_id)
    print(f"authority stage: {stage}")
    print(f"rail: {rail}")
    if stage == "detail-authority":
        print("precedence: this map holds the process detail; CLAUDE.md holds "
              "principles + a pointer. On detail conflict the map wins (T-2619).")
    else:
        print("precedence: descriptive only — CLAUDE.md prose wins on conflict "
              "until the conformance rail goes green (T-2619 transitional rule).")
    return 0


def search(root: Path, term: str) -> int:
    sd = store_dir(root)
    if not sd.is_dir():
        return 0
    t = term.lower()
    for d in sorted(sd.iterdir()):
        if not (d / "meta.json").is_file():
            continue
        if d.name.startswith("draft-"):
            # T-2623: drafts are excluded from retrieval — they are sketches,
            # not knowledge. Browse them in the /designer gallery instead.
            continue
        try:
            spec, meta = load_latest(root, d.name)
        except Exception:  # noqa: BLE001 — unreadable maps just don't match
            continue
        matched = []
        if t in d.name.lower() or t in str(spec.get("title") or "").lower():
            matched.append("(map title)")
        matched += [n["name"] for n in spec["nodes"]
                    if n.get("name") and t in n["name"].lower()]
        if matched:
            print(f"  corpus map: {d.name} (v{meta['latest']}) — "
                  f"matches: {'; '.join(matched[:4])}")
            print(f"    read it: fw corpus explain {d.name}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="corpus_explain")
    ap.add_argument("map_id", nargs="?")
    ap.add_argument("--search", dest="term")
    ap.add_argument("--root", default=str(REPO_ROOT), type=Path)
    args = ap.parse_args()
    if args.term:
        return search(args.root, args.term)
    if not args.map_id:
        ap.error("map-id or --search TERM required")
    return explain(args.root, args.map_id)


if __name__ == "__main__":
    sys.exit(main())
