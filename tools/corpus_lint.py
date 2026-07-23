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
from corpus_spec import BPMN_NS, STORE, UUID_RE, _ext, _q, store_index  # noqa: E402

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
    return findings, typed


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
