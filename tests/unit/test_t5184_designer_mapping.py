#!/usr/bin/env python3
"""T-5184 — designer 0.43.0 BPMN export -> EWCR contracts v2 procedure (shared contract 2).

Checks the worked example in docs/research/executable-workflow/contracts/v2/examples-mapping/:
  1. the BPMN example parses and is in the shape designer 0.43.0 writes (exporter, namespaces);
  2. the procedure JSON validates against contracts v2 procedure.schema.json;
  3. applying the mapping rules of designer-0.43-mapping.md to the BPMN gives exactly that JSON
     (a small reference mapper, here, so the rules are executable and not only prose);
  4. content_hash is the value the content_hash rule (§4 of the mapping) produces;
  5. the hash ignores layout and document order (a moved node or reordered flow changes nothing).

Run: python3 -m pytest tests/unit/test_t5184_designer_mapping.py -q
"""

import copy
import hashlib
import json
import pathlib
import re
import xml.etree.ElementTree as ET

import pytest

ROOT = pathlib.Path(__file__).resolve().parents[2]
V2 = ROOT / "docs/research/executable-workflow/contracts/v2"
EX = V2 / "examples-mapping"
BPMN_FILE = EX / "human-script-human.bpmn"
PROC_FILE = EX / "human-script-human.procedure.json"

NS = {
    "bpmn": "http://www.omg.org/spec/BPMN/20100524/MODEL",
    "bpmndi": "http://www.omg.org/spec/BPMN/20100524/DI",
    "dc": "http://www.omg.org/spec/DD/20100524/DC",
    "di": "http://www.omg.org/spec/DD/20100524/DI",
    "aef": "http://anchorpoint.framework/aef/extensions",
}
B = "{%s}" % NS["bpmn"]
A = "{%s}" % NS["aef"]

# Fields AEF owns: never taken from the export and excluded from content_hash (§3, §4).
LIFECYCLE_FIELDS = ("status", "content_hash", "ratification", "successor_version")


class Refused(Exception):
    pass


def content_hash(proc):
    """§4: sha256 over canonical JSON of the procedure minus the lifecycle fields."""
    body = {k: copy.deepcopy(v) for k, v in proc.items() if k not in LIFECYCLE_FIELDS}
    body["nodes"] = sorted(body["nodes"], key=lambda n: n["uid"])
    body["edges"] = sorted(body["edges"], key=lambda e: (e["from"], e["to"], e.get("guard", "")))
    body["terminal_nodes"] = sorted(body["terminal_nodes"])
    data = json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def _ext(el):
    return el.find(B + "extensionElements")


def _meta(el):
    ext = _ext(el)
    m = ext.find(A + "meta") if ext is not None else None
    return dict(m.attrib) if m is not None else {}


def _uid(el):
    ext = _ext(el)
    u = ext.find(A + "uid") if ext is not None else None
    if u is None:
        raise Refused("no aef:uid on %s" % el.get("id"))
    return u.get("value")


KIND_BY_TAG = {
    "startEvent": "gateway",
    "endEvent": "gateway",
    "exclusiveGateway": "gateway",
    "userTask": "human_gate",
    "scriptTask": "script",
}


def bpmn_to_procedure(path):
    """Reference mapper for the subset the worked example uses (mapping §2, §3)."""
    root = ET.parse(path).getroot()
    proc = root.find(B + "process")
    wm = _ext(proc).find(A + "workflowMeta")
    if wm is None:
        raise Refused("no aef:workflowMeta")
    if wm.get("kind") != "work-plan":
        raise Refused("workflowMeta kind is %r, not work-plan" % wm.get("kind"))
    version = wm.get("version", "1")
    if re.fullmatch(r"[0-9]+", version):
        version = version + ".0.0"
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise Refused("version %r" % version)

    uid_of = {}
    nodes, starts, ends = [], [], []
    flow_els = []
    for el in proc:
        tag = el.tag[len(B):] if el.tag.startswith(B) else None
        if tag in (None, "extensionElements", "laneSet"):
            continue
        if tag == "sequenceFlow":
            flow_els.append(el)
            continue
        if tag not in KIND_BY_TAG:
            raise Refused("element <bpmn:%s> has no procedure kind in this mapping" % tag)
        uid = _uid(el)
        uid_of[el.get("id")] = uid
        meta = _meta(el)
        node = {"uid": uid, "kind": meta.get("nodeKind", KIND_BY_TAG[tag])}
        outcome = meta.get("outcome") or (meta.get("state") if tag == "endEvent" else None)
        if not outcome:
            raise Refused("node %s has no outcome" % uid)
        node["outcome"] = outcome
        io = _ext(el).find(A + "io")
        if io is not None:
            ins = [i.get("name") for i in io.findall(A + "input")]
            outs = [o.get("name") for o in io.findall(A + "output")]
            if ins:
                node["inputs"] = ins
            if outs:
                node["outputs"] = outs
        for src, dst in (("actionRef", "action_ref"), ("executionProfileRef", "execution_profile_ref"),
                         ("capabilityProfileRef", "capability_profile_ref"), ("timeout", "timeout"),
                         ("compensationRef", "compensation_ref")):
            if meta.get(src):
                node[dst] = meta[src]
        if "maxAttempts" in meta:
            node["retry"] = {"max_attempts": int(meta["maxAttempts"])}
        cr = _ext(el).find(A + "contextReads")
        if cr is not None and cr.get("paths"):
            node["context_selectors"] = [p.strip() for p in cr.get("paths").split(",") if p.strip()]
        do = _ext(el).find(A + "decisionOutputs")
        node["_labels"] = [s.strip() for s in do.text.split(",")] if do is not None and do.text else []
        nodes.append(node)
        if tag == "startEvent":
            starts.append(uid)
        if tag == "endEvent":
            ends.append(uid)

    if len(starts) != 1:
        raise Refused("expected one startEvent, found %d" % len(starts))
    edges, named = [], {}
    for f in flow_els:
        e = {"from": uid_of[f.get("sourceRef")], "to": uid_of[f.get("targetRef")]}
        cond = f.find(B + "conditionExpression")
        if cond is not None and (cond.text or "").strip():
            e["guard"] = cond.text.strip()
        edges.append(e)
        if f.get("name"):
            named.setdefault(e["from"], {})[f.get("name")] = e["to"]
    for n in nodes:
        labels = n.pop("_labels")
        if n["kind"] == "human_gate":
            m = {}
            for lab in labels:
                if lab not in named.get(n["uid"], {}):
                    raise Refused("decision %r on %s has no outgoing flow of that name" % (lab, n["uid"]))
                m[lab] = named[n["uid"]][lab]
            n["human_decision_map"] = m
    out = {
        "id": wm.get("id"),
        "version": version,
        "status": "draft",
        "content_hash": "",
        "start_node": starts[0],
        "terminal_nodes": ends,
        "nodes": nodes,
        "edges": edges,
    }
    out["content_hash"] = content_hash(out)
    return out


@pytest.fixture(scope="module")
def procedure():
    return json.loads(PROC_FILE.read_text())


def test_bpmn_example_parses_in_designer_0_43_shape():
    root = ET.parse(BPMN_FILE).getroot()
    assert root.tag == B + "definitions"
    assert root.get("exporter") == "aef-workflow-designer"
    proc = root.find(B + "process")
    assert proc is not None
    wm = _ext(proc).find(A + "workflowMeta")
    assert wm is not None and wm.get("id") == "human-script-human"
    assert root.find("bpmndi:BPMNDiagram", NS) is not None


def test_procedure_validates_against_v2_schema(procedure):
    jsonschema = pytest.importorskip("jsonschema")
    schema = json.loads((V2 / "procedure.schema.json").read_text())
    jsonschema.Draft202012Validator.check_schema(schema)
    errors = sorted(jsonschema.Draft202012Validator(schema).iter_errors(procedure), key=str)
    assert not errors, [e.message for e in errors]


def test_mapping_rules_reproduce_the_example(procedure):
    assert bpmn_to_procedure(BPMN_FILE) == procedure


def test_content_hash_follows_the_rule(procedure):
    assert procedure["content_hash"] == content_hash(procedure)


def test_content_hash_ignores_layout_and_order(procedure):
    moved = BPMN_FILE.read_text().replace('<aef:position x="340.0" y="193.0"/>',
                                          '<aef:position x="999.0" y="1.0"/>')
    assert moved != BPMN_FILE.read_text()
    tmp = EX / ".t5184-moved.bpmn"
    try:
        tmp.write_text(moved)
        assert bpmn_to_procedure(tmp)["content_hash"] == procedure["content_hash"]
    finally:
        tmp.unlink(missing_ok=True)
    shuffled = copy.deepcopy(procedure)
    shuffled["nodes"].reverse()
    shuffled["edges"].reverse()
    assert content_hash(shuffled) == procedure["content_hash"]
    # control: a semantic change does move the hash
    changed = copy.deepcopy(procedure)
    changed["nodes"][0]["outcome"] = "something_else"
    assert content_hash(changed) != procedure["content_hash"]


def test_lifecycle_fields_do_not_move_the_hash(procedure):
    ratified = copy.deepcopy(procedure)
    ratified["status"] = "ratified"
    ratified["ratification"] = {"actor": {"identity": "user:x", "kind": "human"}, "ts": "2026-11-16T00:00:00Z"}
    assert content_hash(ratified) == procedure["content_hash"]
