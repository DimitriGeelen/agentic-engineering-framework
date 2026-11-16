#!/usr/bin/env python3
"""T-5184 — designer 0.43.0 BPMN export -> EWCR contracts v2 procedure (shared contract 2).

Checks the worked example in docs/research/executable-workflow/contracts/v2/examples-mapping/:
  1. the BPMN example parses and is in the shape designer 0.43.0 writes (exporter, namespaces);
  2. the procedure JSON validates against contracts v2 procedure.schema.json;
  3. applying the mapping rules of designer-0.43-mapping.md to the BPMN gives exactly that JSON
     (a small reference mapper, here, so the rules are executable and not only prose);
  4. content_hash is the value the content_hash rule (§4 of the mapping) produces;
  5. the hash ignores layout and document order (a moved node or reordered flow changes nothing);
  6. T-5192: the rules 832's answers changed (msg ccdef9f3) -- Q2 version, Q3 agentType,
     Q5 sovereignty lane wins, Q6 link throw/catch, Q7 boundary timer -- on small inline cases.

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
    "serviceTask": None,  # decided by @agentType (Q3)
    "task": None,  # only a sovereignty-lane activity (Q5); otherwise refused
}
ACTIVITIES = ("userTask", "serviceTask", "scriptTask", "task")  # Q5: only these take an owner
AGENT_TYPES = ("primary", "termlink-worker")


def map_version(version):
    """Q2: integer N -> N.0.0; X.Y.Z as-is; anything else refused (schema allows X.Y.Z only)."""
    if re.fullmatch(r"[0-9]+", version):
        return version + ".0.0"
    if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        return version
    raise Refused("version %r" % version)


def _link(el):
    ext = _ext(el)
    return ext.find(A + "link") if ext is not None else None


def bpmn_to_procedure(path):
    return root_to_procedure(ET.parse(path).getroot())


def bpmn_text_to_procedure(text):
    return root_to_procedure(ET.fromstring(text))


def root_to_procedure(root):
    """Reference mapper for the subset the worked example and the T-5192 cases use (mapping §2, §3)."""
    proc = root.find(B + "process")
    wm = _ext(proc).find(A + "workflowMeta")
    if wm is None:
        raise Refused("no aef:workflowMeta")
    if wm.get("kind") != "work-plan":
        raise Refused("workflowMeta kind is %r, not work-plan" % wm.get("kind"))
    version = map_version(wm.get("version", "1"))

    sovereign = set()  # displayIds of nodes in a lane with authority="sovereignty"
    for lane in proc.iter(B + "lane"):
        lm = _ext(lane).find(A + "laneMeta") if _ext(lane) is not None else None
        if lm is not None and lm.get("authority") == "sovereignty":
            sovereign.update((r.text or "").strip() for r in lane.findall(B + "flowNodeRef"))

    uid_of = {}
    nodes, starts, ends = [], [], []
    flow_els = []
    throws, catches = {}, {}  # Q6: same-document link pairs, by linkId -> displayId
    for el in proc:
        tag = el.tag[len(B):] if el.tag.startswith(B) else None
        if tag in (None, "extensionElements", "laneSet"):
            continue
        if tag == "sequenceFlow":
            flow_els.append(el)
            continue
        if tag == "boundaryEvent":
            raise Refused("boundary event %s: v2 has no boundary semantics, timers included (Q7)" % el.get("id"))
        if tag in ("intermediateThrowEvent", "intermediateCatchEvent") and _link(el) is not None:
            link = _link(el)
            if link.get("workflowRef") or link.get("targetWorkflow"):
                raise Refused("cross-workflow link %s: call_workflow awaits a result, a link has no return (Q6)"
                              % el.get("id"))
            (throws if tag == "intermediateThrowEvent" else catches)[link.get("linkId")] = el.get("id")
            continue
        if tag not in KIND_BY_TAG:
            raise Refused("element <bpmn:%s> has no procedure kind in this mapping" % tag)
        uid = _uid(el)
        uid_of[el.get("id")] = uid
        meta = _meta(el)
        if tag in ACTIVITIES and el.get("id") in sovereign:
            kind = "human_gate"  # Q5: lane wins (O-1), over tag, @agentType and @nodeKind
        elif tag == "serviceTask":
            at = meta.get("agentType")
            if at is None:
                kind = "service"
            elif at in AGENT_TYPES:
                kind = "agent_prompt"
            else:
                raise Refused("serviceTask %s with agentType %r outside a sovereignty lane (Q3)" % (uid, at))
            kind = meta.get("nodeKind", kind)
        elif KIND_BY_TAG[tag] is None:
            raise Refused("<bpmn:%s> %s has no procedure kind outside a sovereignty lane" % (tag, uid))
        else:
            kind = meta.get("nodeKind", KIND_BY_TAG[tag])
        node = {"uid": uid, "kind": kind}
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
    if set(throws) != set(catches):
        raise Refused("unmatched link throw/catch: %s" % sorted(set(throws) ^ set(catches)))
    # Q6: collapse each throw -> catch pair into one edge per incoming flow of the throw.
    goto = {}  # throw displayId -> target displayId of the catch's single outgoing flow
    for link_id, catch in catches.items():
        outs = [f for f in flow_els if f.get("sourceRef") == catch]
        if len(outs) != 1:
            raise Refused("link catch %s has %d outgoing flows, not 1" % (catch, len(outs)))
        if outs[0].find(B + "conditionExpression") is not None:
            raise Refused("link catch %s: outgoing flow has its own condition" % catch)
        goto[throws[link_id]] = outs[0].get("targetRef")
    flow_els = [f for f in flow_els if f.get("sourceRef") not in catches.values()]
    edges, named = [], {}
    for f in flow_els:
        target = goto.get(f.get("targetRef"), f.get("targetRef"))
        e = {"from": uid_of[f.get("sourceRef")], "to": uid_of[target]}
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


# ---- T-5192: rules changed by 832's answers (msg ccdef9f3), on small inline cases ----

def _bpmn(body, lanes="", version="1"):
    """A minimal process in the shape buildBpmnXml writes: start -> body -> end."""
    return (
        '<bpmn:definitions xmlns:bpmn="%s" xmlns:aef="%s" exporter="aef-workflow-designer">'
        '<bpmn:process id="P" isExecutable="true"><bpmn:extensionElements>'
        '<aef:workflowMeta id="case" version="%s" kind="work-plan"/></bpmn:extensionElements>'
        '<bpmn:laneSet>%s</bpmn:laneSet>'
        '<bpmn:startEvent id="s"><bpmn:extensionElements><aef:uid value="n_s"/>'
        '<aef:meta outcome="started"/></bpmn:extensionElements></bpmn:startEvent>'
        '%s'
        '<bpmn:endEvent id="e"><bpmn:extensionElements><aef:uid value="n_e"/>'
        '<aef:meta state="closed"/></bpmn:extensionElements></bpmn:endEvent>'
        '</bpmn:process></bpmn:definitions>' % (NS["bpmn"], NS["aef"], version, lanes, body)
    )


def _lane(authority, *refs):
    return ('<bpmn:lane id="l_%s"><bpmn:extensionElements><aef:laneMeta authority="%s"/>'
            '</bpmn:extensionElements>%s</bpmn:lane>'
            % (authority, authority, "".join("<bpmn:flowNodeRef>%s</bpmn:flowNodeRef>" % r for r in refs)))


def _node(tag, nid, meta="", extra=""):
    return ('<bpmn:%s id="%s"><bpmn:extensionElements><aef:uid value="n_%s"/>'
            '<aef:meta outcome="done_%s" %s/>%s</bpmn:extensionElements></bpmn:%s>'
            % (tag, nid, nid, nid, meta, extra, tag))


def _flow(fid, src, dst, name="", cond=""):
    n = ' name="%s"' % name if name else ""
    c = "<bpmn:conditionExpression>%s</bpmn:conditionExpression>" % cond if cond else ""
    return '<bpmn:sequenceFlow id="%s" sourceRef="%s" targetRef="%s"%s>%s</bpmn:sequenceFlow>' % (fid, src, dst, n, c)


LINEAR = lambda node: node + _flow("f1", "s", "x") + _flow("f2", "x", "e")  # noqa: E731
DECISION = "<aef:decisionOutputs>ok</aef:decisionOutputs>"


def _kind(proc, uid):
    return next(n["kind"] for n in proc["nodes"] if n["uid"] == uid)


@pytest.mark.parametrize("given,expected", [("1", "1.0.0"), ("7", "7.0.0"), ("2.3.4", "2.3.4")])
def test_q2_version_integer_and_semver(given, expected):
    proc = bpmn_text_to_procedure(_bpmn(LINEAR(_node("scriptTask", "x", 'actionRef="a.v1" capabilityProfileRef="c.v1"')), version=given))
    assert proc["version"] == expected


@pytest.mark.parametrize("given", ["v1", "1.0", "1.0.0-rc1", "latest", ""])
def test_q2_version_anything_else_refused(given):
    with pytest.raises(Refused):
        map_version(given)


@pytest.mark.parametrize("agent_type,kind", [(None, "service"), ("primary", "agent_prompt"),
                                             ("termlink-worker", "agent_prompt")])
def test_q3_service_task_agent_type(agent_type, kind):
    meta = 'agentType="%s"' % agent_type if agent_type else ""
    proc = bpmn_text_to_procedure(_bpmn(LINEAR(_node("serviceTask", "x", meta)), lanes=_lane("initiative", "x")))
    assert _kind(proc, "n_x") == kind


def test_q3_human_service_task_refused_outside_sovereignty_lane():
    with pytest.raises(Refused):
        bpmn_text_to_procedure(_bpmn(LINEAR(_node("serviceTask", "x", 'agentType="human"')),
                                     lanes=_lane("authority", "x")))


def test_q3_human_service_task_in_sovereignty_lane_is_a_gate():
    body = _node("serviceTask", "x", 'agentType="human"', DECISION) + _flow("f1", "s", "x") + _flow("f2", "x", "e", name="ok")
    proc = bpmn_text_to_procedure(_bpmn(body, lanes=_lane("sovereignty", "x")))
    assert _kind(proc, "n_x") == "human_gate"


@pytest.mark.parametrize("tag,meta", [("scriptTask", 'actionRef="a.v1" capabilityProfileRef="c.v1"'),
                                      ("serviceTask", 'agentType="primary"'), ("task", ""),
                                      ("scriptTask", 'nodeKind="command"')])
def test_q5_activity_in_sovereignty_lane_maps_to_human_gate(tag, meta):
    body = _node(tag, "x", meta, DECISION) + _flow("f1", "s", "x") + _flow("f2", "x", "e", name="ok")
    proc = bpmn_text_to_procedure(_bpmn(body, lanes=_lane("sovereignty", "x")))
    assert _kind(proc, "n_x") == "human_gate"
    assert next(n for n in proc["nodes"] if n["uid"] == "n_x")["human_decision_map"] == {"ok": "n_e"}


def test_q5_events_and_gateways_in_sovereignty_lane_are_exempt():
    body = _node("exclusiveGateway", "x") + _flow("f1", "s", "x") + _flow("f2", "x", "e")
    proc = bpmn_text_to_procedure(_bpmn(body, lanes=_lane("sovereignty", "s", "x", "e")))
    assert {n["uid"]: n["kind"] for n in proc["nodes"]} == {"n_s": "gateway", "n_x": "gateway", "n_e": "gateway"}


def test_q5_example_gates_are_in_the_sovereignty_lane(procedure):
    # The worked example's human lane holds exactly its two human_gates.
    gates = {n["uid"] for n in procedure["nodes"] if n["kind"] == "human_gate"}
    assert gates == {"n_2b1d4f02", "n_4d3f6b04"}


SCRIPT = 'actionRef="a.v1" capabilityProfileRef="c.v1"'


def _link_ev(tag, nid, **attrs):
    a = " ".join('%s="%s"' % kv for kv in attrs.items())
    return '<bpmn:%s id="%s"><bpmn:extensionElements><aef:link %s/></bpmn:extensionElements></bpmn:%s>' % (tag, nid, a, tag)


def test_q6_same_document_link_pair_collapses_into_one_edge():
    body = (_node("scriptTask", "x", SCRIPT) + _link_ev("intermediateThrowEvent", "t", linkId="L1")
            + _link_ev("intermediateCatchEvent", "c", linkId="L1") + _node("scriptTask", "y", SCRIPT)
            + _flow("f1", "s", "x") + _flow("f2", "x", "t", cond='status == "ok"') + _flow("f3", "c", "y")
            + _flow("f4", "y", "e"))
    proc = bpmn_text_to_procedure(_bpmn(body))
    assert {n["uid"] for n in proc["nodes"]} == {"n_s", "n_x", "n_y", "n_e"}
    assert {"from": "n_x", "to": "n_y", "guard": 'status == "ok"'} in proc["edges"]
    assert len(proc["edges"]) == 3


def test_q6_cross_workflow_link_throw_refused():
    body = _link_ev("intermediateThrowEvent", "t", workflowRef="other-flow") + _flow("f1", "s", "t")
    with pytest.raises(Refused):
        bpmn_text_to_procedure(_bpmn(body))


def test_q6_unmatched_link_refused():
    body = _link_ev("intermediateThrowEvent", "t", linkId="L1") + _flow("f1", "s", "t")
    with pytest.raises(Refused):
        bpmn_text_to_procedure(_bpmn(body))


def test_q7_boundary_timer_refused():
    body = (LINEAR(_node("scriptTask", "x", SCRIPT))
            + '<bpmn:boundaryEvent id="b" attachedToRef="x"><bpmn:extensionElements><aef:uid value="n_b"/>'
              '<aef:eventDef kind="timer" binding="0 9 * * *"/></bpmn:extensionElements></bpmn:boundaryEvent>')
    with pytest.raises(Refused):
        bpmn_text_to_procedure(_bpmn(body))
