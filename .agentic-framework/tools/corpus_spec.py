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
import io
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
    # T-4374: sync sub-workflow call (832 T-282), round-trip only — AEF's corpus
    # is descriptive, nothing here executes it. calledElement = called map's
    # corpus id; aef:ioMapping + sibling aef:callRef carry data mapping/identity.
    "call": "callActivity",
    # T-4488: plain untyped activity (832 T-1215), round-trip only — third-party
    # BPMN uses it widely; re-emitted as authored, never coerced to a typed task.
    "task": "task",
    # T-4495: decision-table activity (832 kitchen-sink.bpmn), round-trip only —
    # AEF evaluates no DMN; re-emitted as authored, like the plain task above.
    "business-rule": "businessRuleTask",
    # T-4501: event attached to an activity's boundary (832 boundary-events /
    # kitchen-sink goldens), round-trip only. attachedToRef + cancelActivity
    # are carried as fields; event definitions ride raw_children verbatim.
    "boundary": "boundaryEvent",
    # T-4505: the rest of the BPMN 2.0 process flow nodes, round-trip only —
    # added together against the spec's list instead of one per field report.
    # Their own attributes (messageRef, instantiate, eventGatewayType, ordering,
    # method, …) ride n["attrs"]; children (loop/completion conditions, nested
    # flow elements) ride raw_children verbatim, as subProcess's already do.
    "send": "sendTask",
    "receive": "receiveTask",
    "manual": "manualTask",
    "inclusive-gateway": "inclusiveGateway",
    "complex-gateway": "complexGateway",
    "event-gateway": "eventBasedGateway",
    "adhoc-subprocess": "adHocSubProcess",
    "transaction": "transaction",
}
TAG_TO_TYPE = {v: k for k, v in TYPE_TO_TAG.items()}

# T-4399: tags whose BPMN schema type defines the unprefixed `default`
# attribute (tExclusive/tInclusive/tComplexGateway, tActivity) — the flow taken
# when no condition holds.
DEFAULT_FLOW_TAGS = {"exclusiveGateway", "inclusiveGateway", "complexGateway",
                     "serviceTask", "userTask", "scriptTask", "subProcess",
                     "callActivity", "task", "businessRuleTask", "sendTask",
                     "receiveTask", "manualTask", "adHocSubProcess", "transaction"}

#: BPMN 2.0 flow nodes that are deliberately NOT round-tripped, with the reason
#: the parse refusal names. Choreography nodes belong to a bpmn:choreography,
#: not a process; implicitThrowEvent is the spec's choreography-only event.
REFUSED_FLOW_TAGS = {
    "choreographyTask": "choreography node, not valid in a bpmn:process",
    "subChoreography": "choreography node, not valid in a bpmn:process",
    "callChoreography": "choreography node, not valid in a bpmn:process",
    "implicitThrowEvent": "choreography-only event, not valid in a bpmn:process",
}

#: T-4505: unprefixed attributes the BPMN 2.0 schema defines on each tag and
#: parse_map does not model as a named field (id, name, default, calledElement,
#: attachedToRef, cancelActivity are). These ride n["attrs"] verbatim; any other
#: unprefixed attribute is not BPMN and stays dropped (T-4389, T-4399).
_ACTIVITY_ATTRS = ("isForCompensation", "startQuantity", "completionQuantity")
_SUBPROCESS_ATTRS = _ACTIVITY_ATTRS + ("triggeredByEvent",)
BPMN_SCHEMA_ATTRS = {
    "task": _ACTIVITY_ATTRS,
    "sendTask": _ACTIVITY_ATTRS + ("implementation", "messageRef", "operationRef"),
    "receiveTask": _ACTIVITY_ATTRS + ("implementation", "instantiate", "messageRef",
                                      "operationRef"),
    "serviceTask": _ACTIVITY_ATTRS + ("implementation", "operationRef"),
    "userTask": _ACTIVITY_ATTRS + ("implementation",),
    "manualTask": _ACTIVITY_ATTRS,
    "scriptTask": _ACTIVITY_ATTRS + ("scriptFormat",),
    "businessRuleTask": _ACTIVITY_ATTRS + ("implementation",),
    "subProcess": _SUBPROCESS_ATTRS,
    "adHocSubProcess": _SUBPROCESS_ATTRS + ("cancelRemainingInstances", "ordering"),
    "transaction": _SUBPROCESS_ATTRS + ("method",),
    "callActivity": _ACTIVITY_ATTRS,
    "startEvent": ("parallelMultiple", "isInterrupting"),
    "intermediateCatchEvent": ("parallelMultiple",),
    "boundaryEvent": ("parallelMultiple",),
    "exclusiveGateway": ("gatewayDirection",),
    "inclusiveGateway": ("gatewayDirection",),
    "complexGateway": ("gatewayDirection",),
    "parallelGateway": ("gatewayDirection",),
    "eventBasedGateway": ("gatewayDirection", "instantiate", "eventGatewayType"),
}

# Known structured aef:* ext children; everything else is preserved verbatim.
_KNOWN_EXT = {"uid", "position", "eventDef", "link", "meta", "workflowMeta", "laneMeta",
              "callRef", "ioMapping"}

# Register stable prefixes so verbatim ET.tostring round-trips keep the same
# serialization on every pass (capture-from-source == capture-from-emit).
ET.register_namespace("bpmn", BPMN_NS)
ET.register_namespace("aef", AEF_NS)
ET.register_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")

#: Prefixes the emitter declares on <bpmn:definitions> itself (plus xsi). A source
#: document may never rebind these — registering one would re-prefix every map.
_ROOT_NS = {"bpmn": BPMN_NS, "aef": AEF_NS,
            "bpmndi": "http://www.omg.org/spec/BPMN/20100524/DI",
            "dc": "http://www.omg.org/spec/DD/20100524/DC",
            "di": "http://www.omg.org/spec/DD/20100524/DI",
            "xsi": "http://www.w3.org/2001/XMLSchema-instance"}


def _source_prefixes(xml_text: str) -> dict:
    """uri → prefix as the SOURCE declared it (first declaration wins).

    ElementTree drops prefixes at parse time, so verbatim parts would come back
    as ns0: (T-4389). Foreign prefixes are registered so _raw_xml keeps them;
    the reserved root prefixes are never rebound."""
    out = {}
    for _, (pfx, uri) in ET.iterparse(io.BytesIO(xml_text.encode("utf-8")),
                                      events=("start-ns",)):
        if pfx and uri not in out:
            out[uri] = pfx
            if (pfx not in _ROOT_NS and uri not in _ROOT_NS.values()
                    and not re.fullmatch(r"ns\d+", pfx)):
                ET.register_namespace(pfx, uri)
    return out


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


def _is_known_ext(c) -> bool:
    """A structured aef:* child — namespace AND local name (T-4387): keyed on the
    local name alone, a foreign <zeebe:uid> overwrote the node's aef:uid."""
    return isinstance(c.tag, str) and c.tag in {_q(k, AEF_NS) for k in _KNOWN_EXT}


#: T-4518: the plain attributes each structured aef:* element is modelled with
#: (None = any plain attribute, carried as one dict). Other plain attributes
#: ride the owner's ext_attrs verbatim (the designer stamps aef:workflowMeta
#: uuid=…); a child element, text or a namespaced attribute inside one has no
#: slot in the spec and is refused.
_EXT_ATTRS = {"uid": {"value"}, "position": {"x", "y"}, "eventDef": None,
              "link": {"linkId", "workflowRef", "targetWorkflow", "name"},
              "meta": None, "callRef": {"workflowRef"}, "ioMapping": set(),
              "workflowMeta": {"id", "version", "schemaVersion", "title", "tier_default"},
              "laneMeta": {"abbr", "authority", "height"}}

#: T-4518: the structured aef:* elements each context actually reads. A known
#: name anywhere else (aef:position on a flow) rides ext_raw verbatim.
_NODE_EXT = {"uid", "position", "eventDef", "link", "meta"}
_CALL_EXT = _NODE_EXT | {"callRef", "ioMapping"}
_FLOW_EXT = {"uid"}
_PROCESS_EXT = {"workflowMeta"}
_LANE_EXT = {"laneMeta"}


def _ext_owner(el) -> str:
    local = el.tag.split("}")[-1]
    return f"<bpmn:{local} id=\"{el.get('id')}\">"


def _is_read(c, known) -> bool:
    return isinstance(c.tag, str) and c.tag in {_q(k, AEF_NS) for k in known}


def _ext(el, known=_NODE_EXT):
    """Structured aef:* children of a flow element's extensionElements block.

    T-4518: content a structured element carries beyond its modelled shape, and
    a repeat of one, used to be dropped silently — refused here instead."""
    out = {}
    ee = el.find(_q("extensionElements"))
    if ee is None:
        return out
    for c in ee:
        if not _is_read(c, known):
            continue
        local = c.tag.split("}")[-1]
        if local in out:
            raise SystemExit(
                f"parse: {_ext_owner(el)} carries aef:{local} more than once — the "
                f"spec holds one, so the others would be dropped (T-4518)")
        nsattr = sorted(k for k in c.attrib if k.startswith("{"))
        inner = local != "ioMapping"  # ioMapping entries are checked by _io_mapping
        if nsattr or (inner and (len(c) or (c.text or "").strip())):
            what = ([f"attribute {k}" for k in nsattr]
                    + ([f"child <{x.tag.split('}')[-1]}>" for x in c
                        if isinstance(x.tag, str)] if inner else [])
                    + (["text"] if inner and (c.text or "").strip() else [])
                    or ["a comment or processing instruction"])
            raise SystemExit(
                f"parse: {_ext_owner(el)} aef:{local} carries {', '.join(what)} "
                f"outside its modelled shape — refusing rather than dropping it "
                f"(T-4518). Put extra content in its own aef: element, which "
                f"round-trips verbatim.")
        out[local] = dict(c.attrib)
    return out


def _ext_attrs(ext: dict) -> dict:
    """T-4518: {element: {attr: value}} — plain attributes of structured aef:*
    elements outside their modelled set, carried verbatim instead of dropped."""
    out = {}
    for local, attrs in ext.items():
        allowed = _EXT_ATTRS[local]
        extra = {k: v for k, v in attrs.items()
                 if allowed is not None and k not in allowed}
        if extra:
            out[local] = extra
    return out


def _attrs_xml(extra: dict | None) -> str:
    return "".join(f" {k}={quoteattr(v)}" for k, v in (extra or {}).items())


def _io_mapping(el) -> dict:
    """aef:ioMapping v1 (T-4374): aef:in / aef:out entries naming variables by
    source and target, nothing else. Expressions are not part of v1 — anything
    outside the shape is a hard error, not a silent drop (T-2614 class)."""
    ee = el.find(_q("extensionElements"))
    io = ee.find(_q("ioMapping", AEF_NS)) if ee is not None else None
    if io is None:
        return None
    out = {"in": [], "out": []}
    # T-4518: text and comments between entries were skipped silently.
    if (io.text or "").strip() or any(not isinstance(c.tag, str) or (c.tail or "").strip()
                                      for c in io):
        raise SystemExit(
            f"parse: <bpmn:callActivity id=\"{el.get('id')}\"> aef:ioMapping carries "
            f"text or a comment between its entries, outside mapping v1 — refusing "
            f"rather than dropping it (T-4518)")
    for c in io:
        local = c.tag.split("}")[-1]
        if (c.tag not in (_q("in", AEF_NS), _q("out", AEF_NS))
                or set(c.attrib) != {"source", "target"} or len(c)
                or (c.text or "").strip()):
            raise SystemExit(
                f"parse: <bpmn:callActivity id=\"{el.get('id')}\"> aef:ioMapping "
                f"entry <{local} {' '.join(sorted(c.attrib))}> is outside mapping v1 "
                f"(aef:in / aef:out with exactly source and target, no expressions) "
                f"— refusing rather than dropping it (T-4374)")
        out[local].append({"source": c.get("source"), "target": c.get("target")})
    return out


#: T-4549: structured aef:io and the process-level aef:meta of mapping v1.1
#: (policy/standards/aef-bpmn-mapping-v1.1-io.md). Each modelled element is
#: {"attrs": {…verbatim, in source order}, <child list>: […], "raw": […]}: the
#: children it knows go to the named list, anything else rides "raw" verbatim
#: (rule 1.4). Lists are emitted in the order given here, so a source that
#: interleaves e.g. aef:field and aef:expect settles after one pass.
_IO_SCHEMA = {
    "io": {"input": "items", "output": "items"},
    "input": {"field": "fields", "expect": "expects", "example": "examples"},
    "field": {"when": "when"},
    "expect": {"value": "values"},
    "when": {"value": "values"},
    "example": {},
    "meta": {"prefixes": "prefixes"},
    "prefixes": {"prefix": "prefix"},
    "prefix": {},
}
_IO_SCHEMA["output"] = _IO_SCHEMA["input"]
#: Lists holding more than one element name record each entry's name.
_IO_MIXED = {"items"}
#: Mapping versions this reader knows (rule 1.5: anything else is refused).
MAPPING_VERSIONS = ("1.1",)


def _io_where(path) -> str:
    return " > ".join(f"aef:{p}" for p in path)


def _io_parse(el, local, owner, path=()) -> dict:
    """One modelled aef element → its spec entry (T-4549). Text outside
    aef:value has no slot and is refused naming the element, never dropped."""
    path = path + (local,)
    entry = {}
    if el.attrib:
        entry["attrs"] = dict(el.attrib)
    if (el.text or "").strip() or any((c.tail or "").strip() for c in el):
        raise SystemExit(
            f"parse: {owner} {_io_where(path)} carries text outside mapping v1.1 — "
            f"refusing rather than dropping it (T-4549, rule 1.4)")
    kids = _IO_SCHEMA[local]
    for c in el:
        clocal = c.tag.split("}")[-1] if isinstance(c.tag, str) else None
        key = kids.get(clocal) if isinstance(c.tag, str) and c.tag == _q(clocal, AEF_NS) else None
        if key is None:
            entry.setdefault("raw", []).append(_raw_xml(c))
        elif clocal == "value":
            if c.attrib or len(c):
                raise SystemExit(
                    f"parse: {owner} {_io_where(path)} > aef:value carries attributes "
                    f"or children — a value is text only (rule 8); refusing rather "
                    f"than dropping them (T-4549)")
            entry.setdefault(key, []).append(c.text or "")
        else:
            sub = _io_parse(c, clocal, owner, path)
            if key in _IO_MIXED:
                sub = {"kind": clocal, **sub}
            entry.setdefault(key, []).append(sub)
    return entry


def _io_element(entry, local, indent: int):
    """Spec entry → ET element laid out at `indent` spaces (T-4549). Built as a
    tree and serialized by ET, so the bytes match the verbatim ext_raw form
    aef:io rode before it was modelled (v1.0 maps unchanged)."""
    el = ET.Element(_q(local, AEF_NS), entry.get("attrs", {}))
    kids = []
    names = {}
    for clocal, key in _IO_SCHEMA[local].items():
        names.setdefault(key, clocal)
    for key, clocal in names.items():
        for sub in entry.get(key, []):
            if key == "values":
                kid = ET.Element(_q("value", AEF_NS))
                kid.text = sub
            else:
                sub = dict(sub)
                kid = _io_element(sub, sub.pop("kind") if key in _IO_MIXED else clocal,
                                  indent + 2)
            kids.append(kid)
    for raw in entry.get("raw", []):
        if raw.startswith("<!--"):
            kids.append(ET.Comment(raw[4:-3]))
        else:
            kids.append(ET.fromstring(
                raw, parser=ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))))
    if kids:
        el.text = "\n" + " " * (indent + 2)
        for k in kids:
            k.tail = "\n" + " " * (indent + 2)
            el.append(k)
        kids[-1].tail = "\n" + " " * indent
    return el


def _io_xml(entry, local, indent: int) -> str:
    return ET.tostring(_io_element(entry, local, indent), encoding="unicode")


def _io_take(el, local, known):
    """The one aef:<local> child of el's extensionElements, parsed, and how many
    ext_raw entries precede it (so emit puts it back in place) — or (None, None).
    `known` is the context's structured set, i.e. what is NOT in ext_raw."""
    ee = el.find(_q("extensionElements"))
    if ee is None:
        return None, None
    found = [c for c in ee if isinstance(c.tag, str) and c.tag == _q(local, AEF_NS)]
    if not found:
        return None, None
    owner = _ext_owner(el)
    if len(found) > 1:
        raise SystemExit(
            f"parse: {owner} carries aef:{local} more than once — the spec holds one, "
            f"so the others would be dropped (T-4549)")
    at = 0
    for c in ee:
        if c is found[0]:
            break
        if isinstance(c.tag, str) and not _is_read(c, known):
            at += 1
    return _io_parse(found[0], local, owner), at


def mapping_version(spec: dict) -> str | None:
    """The map's declared mappingVersion (rule 1.1), None for a v1.0 map."""
    return spec.get("process_meta", {}).get("attrs", {}).get("mappingVersion")


def prefix_map(spec: dict) -> dict:
    """{prefix name: its aef:prefix attributes} from the process aef:meta (§6)."""
    out = {}
    for group in spec.get("process_meta", {}).get("prefixes", []):
        for p in group.get("prefix", []):
            attrs = p.get("attrs", {})
            if "name" in attrs:
                out.setdefault(attrs["name"], attrs)
    return out


def _raw_xml(el) -> str:
    """Verbatim-stable serialization of an element (T-2614 passthrough).

    Registered prefixes (bpmn/aef/xsi) make tostring deterministic across
    passes: capturing from the source doc and re-capturing from the emitted
    doc yield the same string, so canonical identity holds for raw parts."""
    return ET.tostring(el, encoding="unicode").strip()


def _ext_raw(el, known=_NODE_EXT) -> list:
    """Unrecognized ext children preserved verbatim (aef:constituents,
    aef:endpoint, aef:contextReads, …) — the parser dropping these silently
    is the T-2614 data-loss class. Foreign-namespace children land here too,
    whatever their local name (T-4387), and so does a structured name in a
    context that does not read it (T-4518)."""
    ee = el.find(_q("extensionElements"))
    if ee is None:
        return []
    return [_raw_xml(c) for c in ee
            if isinstance(c.tag, str) and not _is_read(c, known)]


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


def _is_empty_shell(proc) -> bool:
    """A process holding nothing a spec could carry: only childless, textless
    documentation / laneSet / extensionElements (Bizagi's second-pool shell)."""
    for c in proc:
        if not isinstance(c.tag, str):
            continue
        if (c.tag.split("}")[-1] not in ("documentation", "laneSet", "extensionElements")
                or len(c) or (c.text or "").strip()):
            return False
    return True


def _single_process(root):
    """T-4502: a spec models ONE process. A second one used to be skipped by
    root.find() — exit 0, its tasks gone (832 multiple-diagrams). Refuse when an
    extra process carries content; an empty shell is dropped with a warning."""
    procs = root.findall(_q("process"))
    if not procs:
        raise SystemExit("parse: no <bpmn:process> in this document — nothing to derive")
    extra = [p for p in procs[1:] if not _is_empty_shell(p)]
    if extra:
        named = ", ".join(
            f"{p.get('id')!r} ({sum(isinstance(c.tag, str) for c in p)} child elements)"
            for p in extra)
        raise SystemExit(
            f"parse: {len(procs)} <bpmn:process> elements; a spec models one "
            f"({procs[0].get('id')!r}) and would drop {named} — refusing rather "
            f"than losing them silently (T-4502). Split the document per process.")
    for p in procs[1:]:
        print(f"parse: warning: dropping empty process {p.get('id')!r} "
              f"(name={p.get('name')!r}; no flow elements, lanes or text)", file=sys.stderr)
    return procs[0]


def parse_map(xml_text: str) -> dict:
    prefixes = _source_prefixes(xml_text)
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

    proc = _single_process(root)
    proc_ext = _ext(proc, _PROCESS_EXT)
    wm = proc_ext.get("workflowMeta", {})
    spec = {
        "spec_version": 1,
        "id": wm.get("id"),
        "title": wm.get("title"),
        "schema_version": int(wm.get("schemaVersion", "2")),
        "tier_default": int(wm.get("tier_default", "1")),
    }
    # T-4518: unknown aef:/foreign siblings of aef:workflowMeta, verbatim.
    proc_raw = _ext_raw(proc, _PROCESS_EXT | {"meta"})
    if proc_raw:
        spec["ext_raw"] = proc_raw
    # T-4549: process-level aef:meta (mappingVersion, aef:prefixes — v1.1 §1, §6).
    pmeta, at = _io_take(proc, "meta", _PROCESS_EXT)
    if pmeta is not None:
        spec["process_meta"] = pmeta
        if at < len(proc_raw):
            spec["process_meta_at"] = at
        mv = mapping_version(spec)
        if mv is not None and mv not in MAPPING_VERSIONS:
            raise SystemExit(
                f"parse: process aef:meta declares mappingVersion={mv!r}; this reader "
                f"knows {', '.join(MAPPING_VERSIONS)} (v1.0 = no attribute) — refusing "
                f"the map rather than misreading it (rule 1.5, T-4549)")
    if _ext_attrs(proc_ext):
        spec["ext_attrs"] = _ext_attrs(proc_ext)
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
            lane_ext = _ext(lane, _LANE_EXT)
            lm = lane_ext.get("laneMeta", {})
            lanes.append({
                "id": lane.get("id"),
                "name": lane.get("name"),
                "abbr": lm.get("abbr"),
                "authority": lm.get("authority"),
                "height": _dim(lm["height"]) if lm.get("height") else None,
            })
            lane_raw = _ext_raw(lane, _LANE_EXT)
            if lane_raw:
                lanes[-1]["ext_raw"] = lane_raw
            if _ext_attrs(lane_ext):
                lanes[-1]["ext_attrs"] = _ext_attrs(lane_ext)
            for ref in lane.findall(_q("flowNodeRef")):
                node_lane[ref.text.strip()] = lane.get("id")
    spec["lanes"] = lanes

    idx = store_index()
    nodes = []
    flows = []
    for el in proc:
        local = el.tag.split("}")[-1] if isinstance(el.tag, str) else None
        if local in TAG_TO_TYPE:
            known = _CALL_EXT if local == "callActivity" else _NODE_EXT
            ext = _ext(el, known)
            n = {
                "id": el.get("id"),
                "lane": node_lane.get(el.get("id")),
                "type": TAG_TO_TYPE[local],
                "name": el.get("name"),
            }
            if local in DEFAULT_FLOW_TAGS and el.get("default"):
                n["default"] = el.get("default")
            if local == "boundaryEvent":
                n["attached_to"] = el.get("attachedToRef")
                if el.get("cancelActivity") is not None:
                    n["cancel_activity"] = el.get("cancelActivity")
            # T-4389: namespace-qualified attributes (camunda:asyncBefore, …)
            # with the source prefix and the declaration they need.
            schema_attrs = BPMN_SCHEMA_ATTRS.get(local, ())
            for key, val in el.attrib.items():
                if not key.startswith("{"):
                    # T-4505: schema-defined plain attributes (messageRef,
                    # instantiate, eventGatewayType, …) verbatim.
                    if key in schema_attrs:
                        n.setdefault("attrs", {})[key] = val
                else:
                    uri, local = key[1:].split("}", 1)
                    pfx = prefixes.get(uri, "")
                    n.setdefault("attrs", {})[f"{pfx}:{local}"] = val
                    if _ROOT_NS.get(pfx) != uri:
                        n.setdefault("xmlns", {})[pfx] = uri
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
            if n["type"] == "call":  # not `local`: rebound by the attrs loop
                n["called_element"] = el.get("calledElement")
                if "callRef" in ext:
                    n["call_ref"] = ext["callRef"].get("workflowRef")
                io = _io_mapping(el)
                if io is not None:
                    n["io_mapping"] = io
            if _ext_attrs(ext):
                n["ext_attrs"] = _ext_attrs(ext)
            raw = _ext_raw(el, known | {"io"})
            if raw:
                n["ext_raw"] = raw
            # T-4549: aef:io modelled (mapping v1.1 attributes and children).
            io_, at = _io_take(el, "io", known)
            if io_ is not None:
                n["io"] = io_
                if at < len(raw):
                    n["io_at"] = at
            # T-4388: unmodelled node children (loop characteristics,
            # ioSpecification, documentation, …) verbatim, as flows do.
            # incoming/outgoing are derived from flows on emit.
            raw = [_raw_xml(c) for c in el
                   if isinstance(c.tag, str) and c.tag.split("}")[-1]
                   not in ("extensionElements", "incoming", "outgoing")]
            if raw:
                n["raw_children"] = raw
            nodes.append(n)
        elif local == "sequenceFlow":
            f = {
                "id": el.get("id"),
                "from": el.get("sourceRef"),
                "to": el.get("targetRef"),
            }
            if el.get("name"):
                f["name"] = el.get("name")
            ext = _ext(el, _FLOW_EXT)
            if "uid" in ext:
                f["uid"] = ext["uid"].get("value")
            if _ext_attrs(ext):
                f["ext_attrs"] = _ext_attrs(ext)
            ext_raw = _ext_raw(el, _FLOW_EXT)
            if ext_raw:
                f["ext_raw"] = ext_raw
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
            if local in REFUSED_FLOW_TAGS:
                raise SystemExit(
                    f"parse: refused BPMN element <bpmn:{local} "
                    f"id=\"{el.get('id')}\"> — {REFUSED_FLOW_TAGS[local]}; "
                    f"parse_map does not round-trip it (T-4505)."
                )
            raise SystemExit(
                f"parse: unsupported BPMN element <bpmn:{local} "
                f"id=\"{el.get('id')}\"> — parse_map cannot round-trip this "
                f"tag; silently dropping it would lose the node while keeping "
                f"its flows (T-2614 data-loss class). Add the tag to "
                f"TYPE_TO_TAG (+ emit support) before regenerating this map."
            )
    spec["nodes"] = nodes
    spec["flows"] = flows
    _check_default_flows(spec, "parse")
    _check_boundary_hosts(spec, "parse")
    return spec


def _check_default_flows(spec: dict, where: str) -> None:
    """T-4399: a node's `default` must name a sequenceFlow leaving that node."""
    src = {f["id"]: f["from"] for f in spec.get("flows", [])}
    bad = []
    for n in spec["nodes"]:
        fid = n.get("default")
        if fid is None:
            continue
        if fid not in src:
            bad.append(f"node \"{n['id']}\" default=\"{fid}\" names no "
                       f"sequenceFlow in this process")
        elif src[fid] != n["id"]:
            bad.append(f"node \"{n['id']}\" default=\"{fid}\" names a "
                       f"sequenceFlow whose sourceRef is \"{src[fid]}\", "
                       f"not \"{n['id']}\"")
    if bad:
        raise SystemExit(f"{where}: " + "; ".join(bad))


#: Node types a boundaryEvent may attach to (BPMN tActivity subclasses).
_ACTIVITY_TYPES = {"service", "user", "script", "subprocess", "call", "task",
                   "business-rule", "send", "receive", "manual",
                   "adhoc-subprocess", "transaction"}


def _check_boundary_hosts(spec: dict, where: str) -> None:
    """T-4501: attachedToRef is required and must name an activity in this map;
    a boundary event emitted against a missing host is a dangling reference."""
    types = {n["id"]: n["type"] for n in spec.get("nodes", [])}
    for n in spec.get("nodes", []):
        if n["type"] != "boundary":
            continue
        host = n.get("attached_to")
        if not host:
            raise SystemExit(f"{where}: boundaryEvent {n['id']} has no attachedToRef")
        if types.get(host) not in _ACTIVITY_TYPES:
            raise SystemExit(
                f"{where}: boundaryEvent {n['id']} attachedToRef={host!r} names "
                f"no activity in this map (found: {types.get(host) or 'nothing'})")


def _dim(v: str):
    """DI dimension: int when integral (byte-stable for existing maps), float otherwise.

    The designer editor saves fractional lane heights (drag-resize); int() crashed
    on those (T-2625). repr(float) round-trips the fractional value verbatim."""
    f = float(v)
    return int(f) if f == int(f) else f


# ── generate: spec → BPMN ─────────────────────────────────────────────────────

def _pos(v: float) -> str:
    return f"{v:.1f}" if v == int(v) else repr(v)


#: tActivity's own children in schema sequence (BPMN 2.0 Semantic.xsd); loop
#: characteristics close it. Anything else (subProcess flow elements, event
#: definitions) ranks after and keeps source order (sort is stable).
_ACTIVITY_ORDER = ("ioSpecification", "property", "dataInputAssociation",
                   "dataOutputAssociation", "resourceRole")
_LOOP_TAGS = ("standardLoopCharacteristics", "multiInstanceLoopCharacteristics")


def _raw_local(raw: str) -> str:
    """Local name of a verbatim-captured element's root tag."""
    return re.match(r"<([^\s/>]+)", raw).group(1).split(":")[-1]


def _node_child_rank(raw: str) -> int:
    local = _raw_local(raw)
    if local in _ACTIVITY_ORDER:
        return _ACTIVITY_ORDER.index(local)
    return len(_ACTIVITY_ORDER) + (0 if local in _LOOP_TAGS else 1)


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


def call_findings(spec: dict, idx: dict | None = None) -> list:
    """Cross-map reference check for callActivity nodes (T-4374, 832 proposal C).

    calledElement must name a corpus map; callRef workflowRef, when present,
    must be some map's meta.json uuid. The uuid identifies the called map and
    calledElement is its readable name, so a disagreement is reported naming
    both sides and the uuid wins — nothing is rewritten. No callRef is valid."""
    idx = idx if idx is not None else store_index()
    out = []
    for n in spec.get("nodes", []):
        if n.get("type") != "call":
            continue
        nid, ce, ref = n["id"], n.get("called_element"), n.get("call_ref")
        if not ce:
            out.append({"level": "error", "node": nid,
                        "message": "callActivity has no calledElement"})
        elif ce not in idx["by_id"]:
            out.append({"level": "error", "node": nid,
                        "message": f"calledElement '{ce}' is not a corpus map id"})
        if ref is None:
            continue
        if ref not in idx["by_uuid"]:
            out.append({"level": "error", "node": nid,
                        "message": f"callRef workflowRef {ref} is no corpus map's uuid"})
        elif ce and idx["by_uuid"][ref] != ce:
            out.append({"level": "finding", "node": nid,
                        "message": f"calledElement '{ce}' disagrees with callRef "
                                   f"workflowRef {ref} (map '{idx['by_uuid'][ref]}'); "
                                   f"the uuid wins, nothing rewritten"})
    return out


def _with_modelled(raws: list, owner: dict, key: str, local: str, indent: int) -> list:
    """ext_raw with owner[key] (T-4549 modelled aef:io / process aef:meta)
    serialized back into the slot it was read from (owner[key + "_at"])."""
    if owner.get(key) is None:
        return list(raws)
    at = owner.get(f"{key}_at", len(raws))
    return raws[:at] + [_io_xml(owner[key], local, indent)] + raws[at:]


def emit_map(spec: dict, version: int = 1, compat_alias: bool | None = None) -> str:
    # T-2615: compat_alias None → derived from the pin capability flag (emit the
    # targetWorkflow alias only while the pinned editor cannot auto-resolve
    # uuid workflowRefs). Tests pass an explicit bool for hermeticity.
    if compat_alias is None:
        compat_alias = not _pin_resolves_workflow_ref()
    # T-4496: the id names the map in every generated element id, so a spec
    # without one (`id: null`, e.g. derived from a map with no aef:workflowMeta)
    # used to die as an AttributeError deep in the emitter. Refuse up front.
    if not isinstance(spec, dict):
        raise SystemExit(f"generate: spec is not a mapping (got {type(spec).__name__}) "
                         f"— an empty file? A spec needs at least `id:`")
    if not isinstance(spec.get("id"), str) or not spec["id"].strip():
        raise SystemExit(
            f"generate: spec needs an id (top-level `id:` is {spec.get('id')!r}) "
            f"— set it to the map's corpus id, e.g. `id: aef-my-map`; a map "
            f"derived from BPMN without aef:workflowMeta carries none")
    idx = store_index()
    errors = [f for f in call_findings(spec, idx) if f["level"] == "error"]
    if errors:
        raise SystemExit("generate: " + "; ".join(
            f"{f['node']}: {f['message']}" for f in errors))
    _check_default_flows(spec, "generate")
    _check_boundary_hosts(spec, "generate")
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
      f'tier_default="{spec.get("tier_default", 1)}"'
      f'{_attrs_xml(spec.get("ext_attrs", {}).get("workflowMeta"))}/>')
    for raw in _with_modelled(spec.get("ext_raw", []), spec, "process_meta", "meta", 6):
        a(f"      {raw}")
    a("    </bpmn:extensionElements>")

    abbr = "".join(w[0] for w in mid.replace("aef-", "").split("-"))[:2]
    a(f'    <bpmn:laneSet id="LaneSet_{abbr}">')
    for lane in spec.get("lanes", []):
        a(f'      <bpmn:lane id={quoteattr(lane["id"])} name={quoteattr(lane["name"])}>')
        a("        <bpmn:extensionElements>")
        attrs = f'abbr={quoteattr(lane["abbr"])} authority={quoteattr(lane["authority"])}'
        if lane.get("height") is not None:
            attrs += f' height="{lane["height"]}"'
        attrs += _attrs_xml(lane.get("ext_attrs", {}).get("laneMeta"))
        a(f"          <aef:laneMeta {attrs}/>")
        for raw in lane.get("ext_raw", []):
            a(f"          {raw}")
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
        if n.get("called_element"):
            name_attr += f" calledElement={quoteattr(n['called_element'])}"
        if n.get("default"):
            name_attr += f" default={quoteattr(n['default'])}"
        if n["type"] == "boundary":
            name_attr += f" attachedToRef={quoteattr(n['attached_to'])}"
            if n.get("cancel_activity") is not None:
                name_attr += f" cancelActivity={quoteattr(n['cancel_activity'])}"
        name_attr += "".join(f" xmlns:{p}={quoteattr(u)}"
                             for p, u in n.get("xmlns", {}).items())
        name_attr += "".join(f" {k}={quoteattr(v)}"
                             for k, v in n.get("attrs", {}).items())
        a(f'    <bpmn:{tag} id={quoteattr(n["id"])}{name_attr}>')
        # T-4388: BPMN schema order — documentation precedes extensionElements;
        # the rest follow incoming/outgoing, loop characteristics last in tActivity.
        raws = n.get("raw_children", [])
        for raw in raws:
            if _raw_local(raw) == "documentation":
                a(f"      {raw}")
        after = sorted((r for r in raws if _raw_local(r) != "documentation"),
                       key=_node_child_rank)
        a("      <bpmn:extensionElements>")
        xa = n.get("ext_attrs", {})
        if n.get("uid"):
            a(f'        <aef:uid value={quoteattr(n["uid"])}{_attrs_xml(xa.get("uid"))}/>')
        if n.get("pos"):
            a(f'        <aef:position x="{_pos(n["pos"][0])}" y="{_pos(n["pos"][1])}"'
              f'{_attrs_xml(xa.get("position"))}/>')
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
              f'linkId={quoteattr(h.get("link_id", ""))}{_attrs_xml(xa.get("link"))}/>')
        if n.get("meta"):
            attrs = " ".join(f"{k}={quoteattr(str(v))}" for k, v in n["meta"].items())
            a(f"        <aef:meta {attrs}/>")
        if n.get("call_ref"):
            a(f'        <aef:callRef workflowRef={quoteattr(n["call_ref"])}'
              f'{_attrs_xml(xa.get("callRef"))}/>')
        if n.get("io_mapping") is not None:
            io = n["io_mapping"]
            io_attrs = _attrs_xml(xa.get("ioMapping"))
            if not io["in"] and not io["out"]:
                a(f"        <aef:ioMapping{io_attrs}/>")
            else:
                a(f"        <aef:ioMapping{io_attrs}>")
                for kind in ("in", "out"):
                    for e in io[kind]:
                        a(f'          <aef:{kind} source={quoteattr(e["source"])} '
                          f'target={quoteattr(e["target"])}/>')
                a("        </aef:ioMapping>")
        for raw in _with_modelled(n.get("ext_raw", []), n, "io", "io", 8):
            a(f"        {raw}")
        a("      </bpmn:extensionElements>")
        for fid in incoming.get(n["id"], []):
            a(f"      <bpmn:incoming>{escape(fid)}</bpmn:incoming>")
        for fid in outgoing.get(n["id"], []):
            a(f"      <bpmn:outgoing>{escape(fid)}</bpmn:outgoing>")
        for raw in after:
            a(f"      {raw}")
        a(f"    </bpmn:{tag}>")

    a("")
    for f in spec.get("flows", []):
        name_attr = f" name={quoteattr(f['name'])}" if f.get("name") else ""
        a(f'    <bpmn:sequenceFlow id={quoteattr(f["id"])}{name_attr} '
          f'sourceRef={quoteattr(f["from"])} targetRef={quoteattr(f["to"])}>')
        uid = f.get("uid")
        ext_raw = "".join(f.get("ext_raw", []))
        uid_part = (f"<aef:uid value={quoteattr(uid)}"
                    f"{_attrs_xml(f.get('ext_attrs', {}).get('uid'))}/>" if uid else "")
        if uid_part or ext_raw:
            a(f"      <bpmn:extensionElements>{uid_part}{ext_raw}"
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
    va = sub.add_parser("validate", help="callActivity cross-map refs; exit 1 on errors")
    va.add_argument("source")
    va.add_argument("--v", type=int, default=None)
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
    elif args.cmd == "validate":
        found = call_findings(parse_map(_load_xml(args.source, args.v)))
        for f in found:
            print(f"{f['level'].upper()} {f['node']}: {f['message']}")
        if not found:
            print("no call findings")
        return 1 if any(f["level"] == "error" for f in found) else 0
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
