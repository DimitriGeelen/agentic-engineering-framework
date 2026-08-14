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
import os
import re
import subprocess
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
    # T-2614: designer-palette types the parser used to SILENTLY DROP — the
    # T-2609 recreate destroyed aef-inception-flow's subProcess node this way
    # (flows kept, node gone → map rendered disconnected). Structured ext parts
    # are handled like any node; unrecognized ext children round-trip verbatim
    # via ext_raw (subProcess aef:constituents, scriptTask aef:endpoint/…).
    "subprocess": "subProcess",
    "script": "scriptTask",
    "parallel-gateway": "parallelGateway",
}
TAG_TO_TYPE = {v: k for k, v in TYPE_TO_TAG.items()}

# Known structured aef:* ext children; everything else is preserved verbatim.
_KNOWN_EXT = {"uid", "position", "eventDef", "link", "meta", "workflowMeta", "laneMeta"}

# Register stable prefixes so verbatim ET.tostring round-trips keep the same
# serialization on every pass (capture-from-source == capture-from-emit).
ET.register_namespace("bpmn", BPMN_NS)
ET.register_namespace("aef", AEF_NS)
ET.register_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")

REPO_ROOT = Path(__file__).resolve().parent.parent
STORE = REPO_ROOT / ".context" / "designer" / "projects"


def _pin_resolves_workflow_ref() -> bool:
    """policy/designer-pin.yaml `resolves_workflow_ref` — capability flag of the
    pinned editor build (T-2612). Missing file/field reads as False (emit the
    compat alias — the safe direction)."""
    pin = REPO_ROOT / "policy" / "designer-pin.yaml"
    if yaml is None or not pin.exists():
        return False
    try:
        return bool((yaml.safe_load(pin.read_text()) or {}).get("resolves_workflow_ref"))
    except Exception:
        return False


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


def _raw_xml(el) -> str:
    """Verbatim-stable serialization of an element (T-2614 passthrough).

    Registered prefixes (bpmn/aef/xsi) make tostring deterministic across
    passes: capturing from the source doc and re-capturing from the emitted
    doc yield the same string, so canonical identity holds for raw parts."""
    return ET.tostring(el, encoding="unicode").strip()


def _ext_raw(el) -> list:
    """Unrecognized ext children preserved verbatim (aef:constituents,
    aef:endpoint, aef:contextReads, …) — the parser dropping these silently
    is the T-2614 data-loss class."""
    ee = el.find(_q("extensionElements"))
    if ee is None:
        return []
    return [_raw_xml(c) for c in ee
            if isinstance(c.tag, str) and c.tag.split("}")[-1] not in _KNOWN_EXT]


#: The emitter's own trailer, present in every generated file. Never a map's doc —
#: matched on a stable prefix so wording drift in the tail does not reopen the hole.
_DI_TRAILER_PREFIX = "BPMN DI (visual layout) omitted"


def _is_boilerplate_comment(text: str) -> bool:
    """True when a comment is the generator's DI trailer rather than authored doc.

    Needed in addition to the positional guard because the position-blind reader
    laundered the trailer into the doc slot: derive adopted the trailing comment,
    generate re-emitted it in LEADING position, and the corruption became
    indistinguishable from an authored doc on the next read (observed on
    aef-audit-cron and aef-session-lifecycle, both already promoted). T-2682.

    T-2895 narrows this from "starts with the trailer" to "is nothing but the
    trailer". `startswith` alone destroys a real rationale that merely OPENS with
    those words — measured, not hypothetical: our own aef-task-lifecycle rationale
    with the trailer prepended reads back empty
    (tests/fixtures/832-outbound/t406-incidental-leading-boilerplate.bpmn).

    Why the prefix match survives at all: the trailer's TAIL drifts. Three wordings
    are live in the corpus ("…omitted in this demo;…", "…omitted in this authored
    fixture;…", "…omitted;…"), so anchoring on the tail would reopen T-2682's hole
    on the variants. The prefix stays; the "one line only" clause is what makes it
    specific. Every known trailer is a single line; laundered doc slots are single
    lines; authored rationale that continues past the trailer is not.

    Deliberately NOT gated on producer identity, which is how 832 fixed the
    equivalent defect in their T-406 — do not "correct" this to match theirs. Their
    inference works because the boilerplate is THEIR text: a document naming a
    different producer cannot be carrying their own trailer. This string originates
    in their designer, and T-2682 records how it reached our documents — the reader
    adopted it and generate() re-emitted it, stamping `exporter="aef-corpus-spec"`
    on the way out (T-2891). A laundered document therefore names US. Gating on
    identity here would preserve precisely the corruption this function exists to
    suppress, on maps already promoted. The asymmetry is which side authored the
    string, not a gap in this implementation.

    Residual, stated rather than papered over: a rationale prepended on the SAME
    line as the trailer still suppresses. That case is genuinely ambiguous from the
    text alone and 832 cannot resolve it either.
    """
    stripped = text.strip()
    if not stripped.startswith(_DI_TRAILER_PREFIX):
        return False
    return len([ln for ln in stripped.splitlines() if ln.strip()]) == 1


def parse_map(xml_text: str) -> dict:
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    root = ET.fromstring(xml_text, parser=parser)

    # The doc comment is LEADING only — it must precede the first real element,
    # mirroring where generate() emits it (before <bpmn:collaboration>). Any later
    # comment is a trailer, not the map's doc: every generated file ends with the
    # "BPMN DI (visual layout) omitted" boilerplate, so a position-blind reader
    # silently adopts that string whenever the real doc is missing — the field then
    # reads plausible-and-wrong instead of empty, which is exactly what hid the
    # designer save path destroying doc comments (T-2682, G-071 class).
    doc = None
    for c in root:
        if c.tag is not ET.Comment:
            break
        cand = "\n".join(line.rstrip() for line in c.text.strip("\n").split("\n"))
        if not _is_boilerplate_comment(cand):
            doc = cand
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
                "height": _dim(lm["height"]) if lm.get("height") else None,
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
            raw = _ext_raw(el)
            if raw:
                n["ext_raw"] = raw
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
            # T-2614: preserve non-extension flow children verbatim
            # (conditionExpression with xsi:type + expression text).
            raw = [_raw_xml(c) for c in el
                   if isinstance(c.tag, str)
                   and c.tag.split("}")[-1] not in ("extensionElements",)]
            if raw:
                f["raw_children"] = raw
            flows.append(f)
        elif (local is not None and el.get("id")
                and local not in ("laneSet", "extensionElements")):
            # T-2614: silent skips destroyed data (aef-inception-flow subProcess
            # gone through recreate, flows left dangling, map rendered
            # disconnected). Any identified process child we cannot round-trip
            # is now a hard error — extend TYPE_TO_TAG deliberately instead.
            raise SystemExit(
                f"parse: unsupported BPMN element <bpmn:{local} "
                f"id=\"{el.get('id')}\"> — parse_map cannot round-trip this "
                f"tag; silently dropping it would lose the node while keeping "
                f"its flows (T-2614 data-loss class). Add the tag to "
                f"TYPE_TO_TAG (+ emit support) before regenerating this map."
            )
    spec["nodes"] = nodes
    spec["flows"] = flows
    return spec


def _dim(v: str):
    """DI dimension: int when integral (byte-stable for existing maps), float otherwise.

    The designer editor saves fractional lane heights (drag-resize); int() crashed
    on those (T-2625). repr(float) round-trips the fractional value verbatim."""
    f = float(v)
    return int(f) if f == int(f) else f


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


def emit_map(spec: dict, version: int = 1, compat_alias: bool | None = None) -> str:
    # T-2615: compat_alias None → derived from the pin capability flag (emit the
    # targetWorkflow alias only while the pinned editor cannot auto-resolve
    # uuid workflowRefs). Tests pass an explicit bool for hermeticity.
    if compat_alias is None:
        compat_alias = not _pin_resolves_workflow_ref()
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
    # T-2891: name the producer of these bytes.
    #
    # T-2884 measured that we stamped nothing, so a document through both our
    # emitter and 832's carried NO producer identity. That reads as the safe
    # answer — absence is a true statement about a document with no single
    # producer, and it fails detectably rather than confidently. 832's 493
    # changed the cost: their T-406 fix suppresses an imported doc comment
    # unless the document positively names a DIFFERENT producer, so our
    # anonymous documents still lose their authored rationale on import. The
    # attribute is not only about attribution any more; it is load-bearing for
    # whether our own prose survives the seam.
    #
    # `aef-corpus-spec`, not `aef-workflow-designer`: this module emits these
    # bytes, the designer does not. Stamping the designer's name here would be
    # exactly the false-authorship record the whole exchange is about, pointed
    # at 832 instead of at us. It is also deliberately DIFFERENT from 832's
    # producer string — their suppression check keys on difference, so a
    # colliding value would silently reintroduce the bug their fix closed.
    #
    # No `exporterVersion`, and this is a choice rather than an inheritance:
    # emitted maps are committed artifacts, and VERSION moves on nearly every
    # handover, so a version attribute would rewrite every corpus document on
    # every release for a field no reader consumes. 832 drops theirs on import
    # in any case.
    a('                  exporter="aef-corpus-spec"')
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
            # T-2612 compat alias: while the pinned editor lacks T-240 uuid
            # auto-resolve (pin resolves_workflow_ref false), emit both attrs —
            # the editor binds via the slug, the uuid stays canonical.
            # canonical() folds either form to the uuid, so round-trip identity
            # and the prove guard are unaffected. Ghost refs get no alias (no
            # store slug exists to bind). T-2615: alias is capability-
            # conditional — a T-240-capable pin emits canonical uuid-only.
            slug = idx["by_uuid"].get(wref) if compat_alias else None
            tw_part = f" targetWorkflow={quoteattr(slug)}" if slug else ""
            a(f'        <aef:link{tw_part} workflowRef={quoteattr(wref)}{name_part} '
              f'linkId={quoteattr(h.get("link_id", ""))}/>')
        if n.get("meta"):
            attrs = " ".join(f"{k}={quoteattr(str(v))}" for k, v in n["meta"].items())
            a(f"        <aef:meta {attrs}/>")
        for raw in n.get("ext_raw", []):
            a(f"        {raw}")
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
        for raw in f.get("raw_children", []):
            a(f"      {raw}")
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


# ── prove: delete/recreate repeatability harness (T-2605, T-2602 GO child 3/3) ──

def _default_watchtower_url() -> str:
    """FW_WATCHTOWER_URL/WATCHTOWER_URL env, else the triple-file, else localhost:3000.

    Mirrors bin/fw's watchtower-port resolution order (CLAUDE.md §Watchtower
    Port) without sourcing bash — this script also runs standalone.
    """
    env = os.environ.get("FW_WATCHTOWER_URL") or os.environ.get("WATCHTOWER_URL")
    if env:
        return env.rstrip("/")
    p = REPO_ROOT / ".context" / "working" / "watchtower.url"
    if p.is_file():
        for line in p.read_text().splitlines():
            line = line.strip()
            if line:
                return line.rstrip("/")
    return "http://localhost:3000"


def _http_get(url: str) -> str:
    with urllib.request.urlopen(url, timeout=15) as resp:
        return resp.read().decode()


def _http_post(url: str, body: dict) -> dict:
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode())


def cmd_prove(args) -> int:
    """snapshot served latest -> identity-preserving delete (all versions, meta/
    uuid kept) -> regenerate from spec via /api/save -> fetch served -> canonical
    diff vs snapshot. Exits 0 only when canonically IDENTICAL and uuid preserved.
    """
    map_id = args.map_id
    url = (args.url or _default_watchtower_url()).rstrip("/")
    meta_path = STORE / map_id / "meta.json"
    if not meta_path.is_file():
        print(f"prove: no such map in store: {map_id}", file=sys.stderr)
        return 2
    meta_before = json.loads(meta_path.read_text())
    uuid_before = meta_before.get("uuid")
    if not uuid_before:
        print("prove: map has no uuid — cannot verify identity preservation", file=sys.stderr)
        return 2
    versions_before = list(meta_before.get("versions", []))
    latest_before = int(meta_before.get("latest") or 0)
    if latest_before < 1 or not versions_before:
        print("prove: map has no versions to snapshot", file=sys.stderr)
        return 2

    print(f"prove: snapshotting {map_id}@v{latest_before} (served, {url}) ...")
    snapshot_xml = _http_get(f"{url}/api/version?id={map_id}&v={latest_before}")
    snapshot_canon = canonical(snapshot_xml)

    # Spec source (T-2608 single stored representation): the XML in the store is
    # the only persisted truth, so the default derives the spec in-memory from the
    # snapshot just taken. --spec accepts a transient authoring file; --from
    # regenerates from the map's XML at a git ref (survivability leg, IW-3) — the
    # proof target then becomes that historical artifact.
    spec_src = "derived in-memory from served snapshot"
    if args.spec:
        if yaml is None:
            raise SystemExit("prove --spec needs PyYAML")
        spec = yaml.safe_load(Path(args.spec).read_text())
        spec_src = args.spec
    elif args.from_ref:
        rel = f".context/designer/projects/{map_id}"
        ref_meta = json.loads(subprocess.run(
            ["git", "show", f"{args.from_ref}:{rel}/meta.json"],
            cwd=REPO_ROOT, capture_output=True, text=True, check=True).stdout)
        ref_v = int(ref_meta.get("latest") or 0)
        ref_xml = subprocess.run(
            ["git", "show", f"{args.from_ref}:{rel}/v{ref_v}.bpmn"],
            cwd=REPO_ROOT, capture_output=True, text=True, check=True).stdout
        spec = parse_map(ref_xml)
        snapshot_canon = canonical(ref_xml)
        spec_src = f"derived from {args.from_ref}:{rel}/v{ref_v}.bpmn"
    else:
        spec = parse_map(snapshot_xml)
    if spec.get("id") != map_id:
        print(f"prove: spec id {spec.get('id')!r} != map_id {map_id!r}", file=sys.stderr)
        return 2

    # Pre-flight loss guard (T-2609): everything from the first /api/delete on is
    # destructive, and the snapshot exists only in memory (plus git). Regenerate
    # from the spec IN MEMORY and canonical-diff against the proof target first —
    # a map the spec format cannot express losslessly is refused with the store
    # untouched, instead of being replaced by its lossy regeneration.
    preflight_canon = canonical(emit_map(spec, version=1))
    if preflight_canon != snapshot_canon:
        import difflib
        print("prove: REFUSED — in-memory regeneration is not canonically identical "
              "to the proof target; store untouched", file=sys.stderr)
        sa = json.dumps(snapshot_canon, indent=2, sort_keys=True).splitlines()
        sb = json.dumps(preflight_canon, indent=2, sort_keys=True).splitlines()
        for line in difflib.unified_diff(sa, sb, fromfile="target", tofile="regenerated",
                                         lineterm=""):
            print(line, file=sys.stderr)
        return 2

    print(f"prove: identity-preserving delete — {len(versions_before)} version(s), "
          f"meta/uuid kept ...")
    for vent in versions_before:
        _http_post(f"{url}/api/delete", {"id": map_id, "scope": "version", "v": vent["v"]})

    meta_mid = json.loads(meta_path.read_text())
    if meta_mid.get("uuid") != uuid_before:
        print(f"prove: FAIL — uuid changed after version-delete "
              f"({uuid_before} -> {meta_mid.get('uuid')}); aborting before regenerate",
              file=sys.stderr)
        return 1
    if meta_mid.get("versions"):
        print("prove: FAIL — versions not fully cleared by version-scope delete",
              file=sys.stderr)
        return 1

    print(f"prove: regenerating from spec ({spec_src}) via /api/save ...")
    xml_text = emit_map(spec, version=1)
    ET.fromstring(xml_text)  # self-check: well-formed before it ships
    save_resp = _http_post(f"{url}/api/save", {
        "id": map_id,
        "bpmn": xml_text,
        "note": args.note or f"fw corpus prove — identity-preserving recreate ({map_id})",
    })
    new_v = save_resp.get("v")

    print(f"prove: fetching served regenerated v{new_v} ...")
    served_canon = canonical(_http_get(f"{url}/api/version?id={map_id}&v={new_v}"))

    meta_after = json.loads(meta_path.read_text())
    uuid_after = meta_after.get("uuid")
    identical = served_canon == snapshot_canon
    uuid_preserved = uuid_after == uuid_before

    result = {
        "map_id": map_id, "snapshot_v": latest_before, "regenerated_v": new_v,
        "uuid_before": uuid_before, "uuid_after": uuid_after,
        "uuid_preserved": uuid_preserved, "identical": identical,
    }
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"  uuid before: {uuid_before}")
        print(f"  uuid after:  {uuid_after}  "
              f"({'PRESERVED' if uuid_preserved else 'CHANGED — FAIL'})")
        print(f"  canonical:   {'IDENTICAL' if identical else 'DIFFERENT — FAIL'}")
        print(f"prove: {'PASS' if identical and uuid_preserved else 'FAIL'}")
    if not identical:
        import difflib
        sa = json.dumps(snapshot_canon, indent=2, sort_keys=True).splitlines()
        sb = json.dumps(served_canon, indent=2, sort_keys=True).splitlines()
        for line in difflib.unified_diff(sa, sb, fromfile="snapshot", tofile="regenerated",
                                         lineterm=""):
            print(line)
    return 0 if identical and uuid_preserved else 1


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
    pr = sub.add_parser("prove", help="delete/recreate repeatability proof harness (T-2605)")
    pr.add_argument("map_id")
    pr.add_argument("--spec", default=None,
                     help="transient authoring spec file (default: derive in-memory "
                          "from the served snapshot — T-2608 single stored representation)")
    pr.add_argument("--from", dest="from_ref", default=None,
                     help="git ref: regenerate from the map's XML at this ref "
                          "(survivability leg; proof target = that historical artifact)")
    pr.add_argument("--url", default=None,
                     help="watchtower base URL (default: env FW_WATCHTOWER_URL/WATCHTOWER_URL "
                          "or the triple-file)")
    pr.add_argument("--note", default=None)
    pr.add_argument("--json", action="store_true")
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
    elif args.cmd == "prove":
        return cmd_prove(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
