"""T-4677: aef-task-lifecycle reads as a business flow under the business lens.

The business lens (tools/corpus_lenses.yaml) shows Name, Lane and the ``note``
field, but it hides fields, not words inside them. 832's screenshot review found
task ids, policy ids, ``fw`` commands and markdown headings in names and notes,
so the BUSINESS view read like the technical one. The detail belongs in a
technical-lens field (``aef:endpoint``), not in the text every reader sees.

Checks the LATEST stored version (the one /designer and ``fw corpus explain``
serve), and pins it against v3 so the rewording never moves a node, a uid, a
state carrier or a flow.
"""
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MAP_DIR = REPO_ROOT / ".context/designer/projects/aef-task-lifecycle"
NS = {
    "bpmn": "http://www.omg.org/spec/BPMN/20100524/MODEL",
    "aef": "http://anchorpoint.framework/aef/extensions",
}

# Technical tokens a business reader should not meet in a name or a note.
TECHNICAL = [
    (r"\b[TPGLDC]-(\d+|XXX)\b", "task/policy/gap id"),
    (r"\bfw [a-z]", "fw CLI command"),
    (r"#{2,}", "markdown heading"),
    (r"--[a-z]", "CLI flag"),
    (r"\[(REVIEW|REVIEWER|RUBBER-STAMP)\]", "AC prefix"),
    (r"\b(status|horizon|owner):", "frontmatter field"),
    (r"\b(active|completed)/", "directory path"),
    (r"(?<![\w/])/review\b", "Watchtower route"),
    (r"\bACs?\b", "AC jargon"),
]


def _latest_path() -> Path:
    v = json.loads((MAP_DIR / "meta.json").read_text())["latest"]
    return MAP_DIR / f"v{v}.bpmn"


def _process(path: Path):
    root = ET.parse(path).getroot()
    return root, root.find("bpmn:process", NS)


def business_texts(path: Path):
    """(where, text) for every string the business lens renders."""
    root, proc = _process(path)
    out = []
    for el in root.iter():
        if not isinstance(el.tag, str):
            continue
        name = el.get("name")
        local = el.tag.split("}")[-1]
        if name and el.tag.startswith("{%s}" % NS["bpmn"]):
            out.append((f"{local} {el.get('id')} name", name))
    for el in proc:
        meta = el.find("bpmn:extensionElements/aef:meta", NS)
        if meta is not None and meta.get("note"):
            out.append((f"{el.get('id')} note", meta.get("note")))
    return out


def technical_hits(path: Path):
    hits = []
    for where, text in business_texts(path):
        for pat, label in TECHNICAL:
            m = re.search(pat, text)
            if m:
                hits.append(f"{where}: {label} {m.group(0)!r} in {text!r}")
    return hits


def _structure(path: Path):
    _, proc = _process(path)
    nodes, flows = set(), set()
    for el in proc:
        local = el.tag.split("}")[-1]
        if local in ("laneSet", "extensionElements"):
            continue
        uid = el.find("bpmn:extensionElements/aef:uid", NS)
        uid = uid.get("value") if uid is not None else None
        if local == "sequenceFlow":
            flows.add((el.get("id"), uid, el.get("sourceRef"), el.get("targetRef")))
            continue
        meta = el.find("bpmn:extensionElements/aef:meta", NS)
        pos = el.find("bpmn:extensionElements/aef:position", NS)
        nodes.add((
            local, el.get("id"), uid,
            meta.get("state") if meta is not None else None,
            (pos.get("x"), pos.get("y")) if pos is not None else None,
        ))
    lanes = {
        (lane.get("id"), tuple(r.text for r in lane.findall("bpmn:flowNodeRef", NS)))
        for lane in proc.iter("{%s}lane" % NS["bpmn"])
    }
    return nodes, flows, lanes


def _ids(text: str):
    return set(re.findall(r"\b[TPG]-\d+\b", text))


def test_business_lens_text_has_no_technical_tokens():
    hits = technical_hits(_latest_path())
    assert not hits, "technical tokens in business-visible text:\n" + "\n".join(hits)


def test_v3_is_what_the_check_catches():
    # The control leg: the pre-T-4677 version must fail, or the check bites nothing.
    hits = technical_hits(MAP_DIR / "v3.bpmn")
    joined = "\n".join(hits)
    for expected in ("T-1068", "fw work-on", "P-010", "G-020"):
        assert expected in joined, expected


def test_rewording_keeps_ids_uids_carriers_and_topology():
    assert _structure(_latest_path()) == _structure(MAP_DIR / "v3.bpmn")


def test_technical_detail_moved_not_deleted():
    """Every id v3 showed in a name or note survives in a technical field."""
    before = set()
    for _, text in business_texts(MAP_DIR / "v3.bpmn"):
        before |= _ids(text)
    _, proc = _process(_latest_path())
    endpoints = " ".join(
        (e.text or "") for e in proc.iter("{%s}endpoint" % NS["aef"])
    )
    missing = before - _ids(endpoints)
    assert not missing, f"ids dropped instead of moved to aef:endpoint: {sorted(missing)}"
