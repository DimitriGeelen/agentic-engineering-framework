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
  vocabulary-set    — a named gateway's outgoing branch labels, tokenized via
    the entry's ``branch_vocab`` spec, must equal the enforced enum extracted
    from the source file via the entry's ``source_vocab`` spec (T-2652
    slice 2). Extraction is declarative (anchor/regex/split registry keys) so
    a new vocab rail needs only a registry entry. Empty source extraction is
    a load error, never a trivial pass — a stale anchor must fail loudly.
  gate-referent     — reserved (T-2652 slice 5 era). Registering a map with
    an unimplemented primitive is a load error (exit 2), not a silent skip:
    a registry entry is a claim that a rail exists.

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
import re
import sys
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import corpus_spec  # noqa: E402

REGISTRY_REL = "tools/conformance-registry.yaml"
KNOWN_PRIMITIVES = ("transition-table", "vocabulary-set")  # gate-referent: T-2652 slice 5 era


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
        if entry["primitive"] == "vocabulary-set":
            if not entry.get("gateway"):
                raise LoadError(
                    f"registry entry '{map_id}' malformed: vocabulary-set "
                    "needs a gateway key (the gateway node's name)"
                )
            for spec_key in ("branch_vocab", "source_vocab"):
                spec = entry.get(spec_key)
                if not isinstance(spec, dict) or not spec.get("regex"):
                    raise LoadError(
                        f"registry entry '{map_id}' malformed: vocabulary-set "
                        f"needs {spec_key}.regex (declarative extraction spec)"
                    )
                try:
                    re.compile(spec["regex"])
                    if spec.get("anchor"):
                        re.compile(spec["anchor"])
                except re.error as e:
                    raise LoadError(
                        f"registry entry '{map_id}' {spec_key} regex invalid: {e}"
                    ) from e
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


# ── primitive: vocabulary-set (T-2652 slice 2) ──────────────────────────────

def _extract_tokens(text: str, spec: dict) -> set:
    """Declarative token extraction: optional anchor narrows the search region,
    regex finds matches (group 1 if present, else whole match), optional split
    fans each match out, optional first_only keeps just the first match.
    Tokens are lowercased and stripped."""
    if spec.get("anchor"):
        m = re.search(spec["anchor"], text)
        if not m:
            return set()
        text = text[m.end():]
    pattern = re.compile(spec["regex"])
    matches = []
    for m in pattern.finditer(text):
        matches.append(m.group(1) if m.groups() else m.group(0))
        if spec.get("first_only"):
            break
    tokens = set()
    for raw in matches:
        parts = raw.split(spec["split"]) if spec.get("split") else [raw]
        # keep only tokens with real content — splitting on quote/delimiter
        # chars can leave punctuation-only fragments (", ") behind
        tokens.update(
            p for p in (x.strip().lower() for x in parts)
            if re.search(r"[a-z0-9]", p)
        )
    return tokens


def check_vocabulary_set(root: Path, map_id: str, entry: dict) -> int:
    """Returns 0 pass, 1 divergent. Raises LoadError on load problems."""
    spec = load_latest_spec(root, map_id)

    gateways = {
        n["name"]: n["id"]
        for n in spec["nodes"]
        if n.get("type") == "gateway" and n.get("name")
    }
    gw_name = entry["gateway"]
    if gw_name not in gateways:
        raise LoadError(
            f"gateway '{gw_name}' not found in {map_id} "
            f"(gateways present: {sorted(gateways) or 'none'})"
        )
    gw_id = gateways[gw_name]

    branch_labels = [
        f.get("name") or "" for f in spec["flows"] if f["from"] == gw_id
    ]
    asserted = set()
    for label in branch_labels:
        asserted |= _extract_tokens(label, entry["branch_vocab"])

    source_text = (root / entry["source"]).read_text()
    canon = _extract_tokens(source_text, entry["source_vocab"])
    if not canon:
        raise LoadError(
            f"source vocabulary extraction produced nothing from "
            f"{entry['source']} — anchor/regex stale vs source; a rail that "
            "cannot read its enforced enum must fail loudly, not pass empty"
        )

    map_only = sorted(asserted - canon)
    code_only = sorted(canon - asserted)

    if not map_only and not code_only:
        print(f"conformance: PASS — {map_id} gateway '{gw_name}' covers "
              f"exactly the enforced vocabulary {{{', '.join(sorted(canon))}}}")
        return 0

    print(f"conformance: DIVERGENT — {map_id}")
    for tok in map_only:
        print(f"  map-asserts/code-refuses: {tok}")
    for tok in code_only:
        print(f"  code-allows/map-lacks:    {tok}")
    return 1


PRIMITIVE_CHECKS = {
    "transition-table": check_transition_table,
    "vocabulary-set": check_vocabulary_set,
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
