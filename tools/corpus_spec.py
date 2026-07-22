#!/usr/bin/env python3
"""corpus_spec — declarative spec ⇄ designer-corpus BPMN (T-2603, arc T-2602 GO).

Three verbs, one round-trip:

  derive    served/on-disk BPMN → spec YAML (reverse-derivation; captures maps AS-IS)
  generate  spec YAML → contract-v0 BPMN (workflowRef uuid enforced, aef:eventDef
            vocabulary, wiring invariants); optional --save through /api/save
  canon     BPMN → canonical semantic form (JSON) — the comparator's view
  diff      two BPMN files → semantic diff; exit 0 when canonically identical

Contract v0 (T-2571 rail offsets 107-113): cross-workflow refs serialize as
``<aef:link workflowRef="<uuid>" name="<display>" linkId="…"/>``. Legacy
``targetWorkflow="<slug>"`` name-refs are ACCEPTED on derive (the corpus contains
them) but NEVER emitted on generate — the generator resolves the target against
the store registry and emits the uuid form, or refuses unless the spec marks the
ref ``ghost_intent: true`` (which emits the unresolvable uuid deliberately, the
T-2584 ghost flow). The canonical comparator normalizes both forms to the resolved
uuid so a legacy-authored map and its regenerated uuid-form twin compare EQUAL —
without this, round-trip identity (IW-3) could never pass on the existing corpus.

Excluded from canonical compare: workflowMeta ``version`` (bumped by /api/save on
every write) and emission style (whitespace, attribute order). Everything else —
including the doc comment, positions, meta notes, lane heights — is semantic:
the spec is the source of truth for the whole rendered map.
"""

import argparse
import json
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape, quoteattr

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

BPMN_NS = "http://www.omg.org/spec/BPMN/20100524/MODEL"
AEF_NS = "http://anchorpoint.framework/aef/extensions"
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")

TYPE_TO_TAG = {
    "start": "startEvent",
    "end": "endEvent",
    "service": "serviceTask",
    "user": "userTask",
    "gateway": "exclusiveGateway",
    "catch": "intermediateCatchEvent",
    "throw": "intermediateThrowEvent",
}
TAG_TO_TYPE = {v: k for k, v in TYPE_TO_TAG.items()}

REPO_ROOT = Path(__file__).resolve().parent.parent
STORE = REPO_ROOT / ".context" / "designer" / "projects"


# ── store registry (read-only; writes go through /api/save only) ──────────────

def store_index(store: Path = STORE) -> dict:
    """{map_id: uuid} and {uuid: map_id} from the projects store meta.json files."""
    by_id, by_uuid = {}, {}
    if store.is_dir():
        for d in sorted(store.iterdir()):
            mp = d / "meta.json"
            if d.is_dir() and mp.is_file():
                try:
                    m = json.loads(mp.read_text())
                except (OSError, json.JSONDecodeError):
                    continue
                u = m.get("uuid")
                if u:
                    by_id[d.name] = u
                    by_uuid[u] = d.name
    return {"by_id": by_id, "by_uuid": by_uuid}


# ── parse: BPMN → spec ────────────────────────────────────────────────────────

def _q(tag, ns=BPMN_NS):
    return f"{{{ns}}}{tag}"


def _ext(el):
    """aef:* extension children of a flow element's extensionElements block."""
    out = {}
    ee = el.find(_q("extensionElements"))
    if ee is None:
        return out
    for c in ee:
        local = c.tag.split("}")[-1]
        out[local] = dict(c.attrib)
    return out


def parse_map(xml_text: str) -> dict:
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    root = ET.fromstring(xml_text, parser=parser)

    doc = None
    for c in root:
        if c.tag is ET.Comment:
            doc = "\n".join(line.rstrip() for line in c.text.strip("\n").split("\n"))
            break

    proc = root.find(_q("process"))
    wm = _ext(proc).get("workflowMeta", {})
    spec = {
        "spec_version": 1,
        "id": wm.get("id"),
        "title": wm.get("title"),
        "schema_version": int(wm.get("schemaVersion", "2")),
        "tier_default": int(wm.get("tier_default", "1")),
    }
    collab = root.find(_q("collaboration"))
    if collab is not None:
        part = collab.find(_q("participant"))
        if part is not None and part.get("name"):
            spec["pool_name"] = part.get("name")
    if doc:
        spec["doc"] = doc

    node_lane = {}
    lanes = []
    laneset = proc.find(_q("laneSet"))
    if laneset is not None:
        for lane in laneset.findall(_q("lane")):
            lm = _ext(lane).get("laneMeta", {})
            lanes.append({
                "id": lane.get("id"),
                "name": lane.get("name"),
                "abbr": lm.get("abbr"),
                "authority": lm.get("authority"),
                "height": int(lm["height"]) if lm.get("height") else None,
            })
            for ref in lane.findall(_q("flowNodeRef")):
                node_lane[ref.text.strip()] = lane.get("id")
    spec["lanes"] = lanes

    idx = store_index()
    nodes = []
    flows = []
    for el in proc:
        local = el.tag.split("}")[-1] if isinstance(el.tag, str) else None
        if local in TAG_TO_TYPE:
            ext = _ext(el)
            n = {
                "id": el.get("id"),
                "lane": node_lane.get(el.get("id")),
                "type": TAG_TO_TYPE[local],
                "name": el.get("name"),
            }
            if "uid" in ext:
                n["uid"] = ext["uid"].get("value")
            if "position" in ext:
                n["pos"] = [float(ext["position"]["x"]), float(ext["position"]["y"])]
            if "eventDef" in ext:
                n["event"] = dict(ext["eventDef"])
            if "link" in ext:
                link = ext["link"]
                h = {"link_id": link.get("linkId", "")}
                wref = link.get("workflowRef")
                if wref:
                    # uuid form: record the map id when resolvable (readable specs),
                    # else keep the raw uuid (ghost or foreign ref).
                    h["target"] = idx["by_uuid"].get(wref, wref)
                    if wref not in idx["by_uuid"]:
                        h["ghost_intent"] = True
                else:
                    # legacy slug form — captured AS-IS; generate emits uuid form.
                    h["target"] = link.get("targetWorkflow", "")
                    h["derived_from_legacy_form"] = True
                if link.get("name"):
                    h["name"] = link["name"]
                n["handoff"] = h
            if "meta" in ext:
                n["meta"] = dict(ext["meta"])
            nodes.append(n)
        elif local == "sequenceFlow":
            f = {
                "id": el.get("id"),
                "from": el.get("sourceRef"),
                "to": el.get("targetRef"),
            }
            if el.get("name"):
                f["name"] = el.get("name")
            ext = _ext(el)
            if "uid" in ext:
                f["uid"] = ext["uid"].get("value")
            flows.append(f)
    spec["nodes"] = nodes
    spec["flows"] = flows
    return spec


# ── generate: spec → BPMN ─────────────────────────────────────────────────────

def _pos(v: float) -> str:
    return f"{v:.1f}" if v == int(v) else repr(v)


def _resolve_target(target: str, ghost_intent: bool, idx: dict) -> str:
    """spec handoff target (map id or uuid) → workflowRef uuid, contract v0."""
    if UUID_RE.match(target or ""):
        if target in idx["by_uuid"] or ghost_intent:
            return target
        raise SystemExit(
            f"generate: handoff target uuid {target} not in store registry — "
            f"mark the ref 'ghost_intent: true' to emit it deliberately (T-2584 flow)"
        )
    u = idx["by_id"].get(target)
    if u:
        return u
    raise SystemExit(
        f"generate: handoff target '{target}' does not resolve to a store map id — "
        f"contract v0 forbids emitting a name-ref; fix the target or supply a uuid "
        f"with 'ghost_intent: true'"
    )


def emit_map(spec: dict, version: int = 1) -> str:
    idx = store_index()
    mid = spec["id"]
    L = []
    a = L.append
    a('<?xml version="1.0" encoding="UTF-8"?>')
    a(f'<bpmn:definitions xmlns:bpmn="{BPMN_NS}"')
    a('                  xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI"')
    a('                  xmlns:dc="http://www.omg.org/spec/DD/20100524/DC"')
    a('                  xmlns:di="http://www.omg.org/spec/DD/20100524/DI"')
    a(f'                  xmlns:aef="{AEF_NS}"')
    a(f'                  id="Definitions_{mid}"')
    a('                  targetNamespace="https://aef.anchorpoint.dev/workflows">')
    a("")
    if spec.get("doc"):
        a(f"  <!-- {spec['doc'].strip()} -->")
        a("")
    a(f'  <bpmn:collaboration id="Collaboration_{mid}">')
    a(f'    <bpmn:participant id="Pool_{mid.replace("-", "_").replace("aef_", "")}" '
      f'name={quoteattr(spec.get("pool_name") or spec["title"] or mid)} '
      f'processRef="Process_{mid}"/>')
    a("  </bpmn:collaboration>")
    a("")
    a(f'  <bpmn:process id="Process_{mid}" isExecutable="true">')
    a("    <bpmn:extensionElements>")
    a(f'      <aef:workflowMeta id={quoteattr(mid)} version="{version}" '
      f'schemaVersion="{spec.get("schema_version", 2)}" '
      f'title={quoteattr(spec.get("title") or mid)} '
      f'tier_default="{spec.get("tier_default", 1)}"/>')
    a("    </bpmn:extensionElements>")

    abbr = "".join(w[0] for w in mid.replace("aef-", "").split("-"))[:2]
    a(f'    <bpmn:laneSet id="LaneSet_{abbr}">')
    for lane in spec.get("lanes", []):
        a(f'      <bpmn:lane id={quoteattr(lane["id"])} name={quoteattr(lane["name"])}>')
        a("        <bpmn:extensionElements>")
        attrs = f'abbr={quoteattr(lane["abbr"])} authority={quoteattr(lane["authority"])}'
        if lane.get("height") is not None:
            attrs += f' height="{lane["height"]}"'
        a(f"          <aef:laneMeta {attrs}/>")
        a("        </bpmn:extensionElements>")
        for n in spec["nodes"]:
            if n.get("lane") == lane["id"]:
                a(f'        <bpmn:flowNodeRef>{escape(n["id"])}</bpmn:flowNodeRef>')
        a("      </bpmn:lane>")
    a("    </bpmn:laneSet>")

    incoming = {}
    outgoing = {}
    for f in spec.get("flows", []):
        outgoing.setdefault(f["from"], []).append(f["id"])
        incoming.setdefault(f["to"], []).append(f["id"])

    for n in spec["nodes"]:
        a("")
        tag = TYPE_TO_TAG[n["type"]]
        name_attr = f" name={quoteattr(n['name'])}" if n.get("name") else ""
        a(f'    <bpmn:{tag} id={quoteattr(n["id"])}{name_attr}>')
        a("      <bpmn:extensionElements>")
        if n.get("uid"):
            a(f'        <aef:uid value={quoteattr(n["uid"])}/>')
        if n.get("pos"):
            a(f'        <aef:position x="{_pos(n["pos"][0])}" y="{_pos(n["pos"][1])}"/>')
        if n.get("event"):
            attrs = " ".join(f"{k}={quoteattr(str(v))}" for k, v in n["event"].items())
            a(f"        <aef:eventDef {attrs}/>")
        if n.get("handoff"):
            h = n["handoff"]
            wref = _resolve_target(h.get("target"), h.get("ghost_intent", False), idx)
            name = h.get("name") or (h["target"] if not UUID_RE.match(h.get("target", "")) else "")
            name_part = f" name={quoteattr(name)}" if name else ""
            a(f'        <aef:link workflowRef={quoteattr(wref)}{name_part} '
              f'linkId={quoteattr(h.get("link_id", ""))}/>')
        if n.get("meta"):
            attrs = " ".join(f"{k}={quoteattr(str(v))}" for k, v in n["meta"].items())
            a(f"        <aef:meta {attrs}/>")
        a("      </bpmn:extensionElements>")
        for fid in incoming.get(n["id"], []):
            a(f"      <bpmn:incoming>{escape(fid)}</bpmn:incoming>")
        for fid in outgoing.get(n["id"], []):
            a(f"      <bpmn:outgoing>{escape(fid)}</bpmn:outgoing>")
        a(f"    </bpmn:{tag}>")

    a("")
    for f in spec.get("flows", []):
        name_attr = f" name={quoteattr(f['name'])}" if f.get("name") else ""
        a(f'    <bpmn:sequenceFlow id={quoteattr(f["id"])}{name_attr} '
          f'sourceRef={quoteattr(f["from"])} targetRef={quoteattr(f["to"])}>')
        uid = f.get("uid")
        if uid:
            a(f'      <bpmn:extensionElements><aef:uid value={quoteattr(uid)}/>'
              f"</bpmn:extensionElements>")
        a("    </bpmn:sequenceFlow>")
    a("  </bpmn:process>")
    a("</bpmn:definitions>")
    return "\n".join(L) + "\n"


# ── canonical form (IW-3 comparator) ─────────────────────────────────────────

def canonical(xml_text: str) -> dict:
    """Semantic view: version-independent, style-independent, ref-normalized."""
    spec = parse_map(xml_text)
    idx = store_index()
    for n in spec["nodes"]:
        h = n.get("handoff")
        if h:
            t = h.get("target", "")
            # normalize BOTH forms to the resolved uuid (or raw uuid for ghosts)
            h["target_uuid"] = t if UUID_RE.match(t) else idx["by_id"].get(t, f"UNRESOLVED:{t}")
            h.pop("target", None)
            h.pop("derived_from_legacy_form", None)
            h.pop("ghost_intent", None)
            h.pop("name", None)  # display label; uuid is the semantic ref
    spec.pop("spec_version", None)
    # pool_name is part of the canonical view (rendered pool header); parse_map
    # captures it, so a generate that substituted the title would diff here.
    spec["lanes"] = sorted(spec["lanes"], key=lambda x: x["id"])
    spec["nodes"] = sorted(spec["nodes"], key=lambda x: x["id"])
    spec["flows"] = sorted(spec["flows"], key=lambda x: x["id"])
    return spec


# ── CLI ──────────────────────────────────────────────────────────────────────

def _load_xml(arg: str, v: int | None) -> str:
    p = Path(arg)
    if p.is_file():
        return p.read_text()
    d = STORE / arg
    if d.is_dir():
        if v is None:
            v = json.loads((d / "meta.json").read_text()).get("latest")
        return (d / f"v{v}.bpmn").read_text()
    raise SystemExit(f"not a file and not a store map id: {arg}")


def main(argv=None):
    ap = argparse.ArgumentParser(prog="corpus_spec")
    sub = ap.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("derive", help="BPMN (file or store map id) → spec YAML")
    d.add_argument("source")
    d.add_argument("--v", type=int, default=None, help="store version (default: latest)")
    d.add_argument("--out", default=None)
    g = sub.add_parser("generate", help="spec YAML → contract-v0 BPMN")
    g.add_argument("spec")
    g.add_argument("--version", type=int, default=1, help="workflowMeta version to stamp")
    g.add_argument("--out", default=None)
    g.add_argument("--save", action="store_true", help="POST through /api/save")
    g.add_argument("--url", default=None, help="watchtower base URL (required with --save)")
    g.add_argument("--save-id", default=None, help="save under this map id (default: spec id)")
    g.add_argument("--note", default="", help="version note for /api/save")
    c = sub.add_parser("canon", help="BPMN → canonical semantic JSON")
    c.add_argument("source")
    c.add_argument("--v", type=int, default=None)
    f = sub.add_parser("diff", help="semantic compare; exit 0 iff canonically identical")
    f.add_argument("a")
    f.add_argument("b")
    args = ap.parse_args(argv)

    if args.cmd == "derive":
        if yaml is None:
            raise SystemExit("derive needs PyYAML")
        spec = parse_map(_load_xml(args.source, args.v))
        out = yaml.safe_dump(spec, sort_keys=False, allow_unicode=True, width=100)
        if args.out:
            Path(args.out).write_text(out)
            print(f"wrote {args.out}")
        else:
            sys.stdout.write(out)
    elif args.cmd == "generate":
        if yaml is None:
            raise SystemExit("generate needs PyYAML")
        spec = yaml.safe_load(Path(args.spec).read_text())
        xml_text = emit_map(spec, version=args.version)
        ET.fromstring(xml_text)  # self-check: well-formed before anything ships
        if args.out:
            Path(args.out).write_text(xml_text)
            print(f"wrote {args.out}")
        if args.save:
            if not args.url:
                raise SystemExit("--save needs --url (never hard-code the port; "
                                 "use $(bin/fw watchtower url))")
            body = json.dumps({
                "id": args.save_id or spec["id"],
                "bpmn": xml_text,
                "note": args.note or f"corpus_spec generate ({Path(args.spec).name})",
            }).encode()
            req = urllib.request.Request(
                args.url.rstrip("/") + "/api/save", data=body,
                headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                print(resp.read().decode())
        if not args.out and not args.save:
            sys.stdout.write(xml_text)
    elif args.cmd == "canon":
        print(json.dumps(canonical(_load_xml(args.source, args.v)),
                         indent=2, ensure_ascii=False, sort_keys=True))
    elif args.cmd == "diff":
        ca = canonical(_load_xml(args.a, None))
        cb = canonical(_load_xml(args.b, None))
        if ca == cb:
            print("IDENTICAL (canonical semantic form)")
            return 0
        sa = json.dumps(ca, indent=2, sort_keys=True).splitlines()
        sb = json.dumps(cb, indent=2, sort_keys=True).splitlines()
        import difflib
        for line in difflib.unified_diff(sa, sb, fromfile=args.a, tofile=args.b, lineterm=""):
            print(line)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
