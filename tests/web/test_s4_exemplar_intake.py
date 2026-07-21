"""T-2593: S4 exemplar intake drop-point — 832's picker-AUTHORED off-page bytes.

Delta vs pair-draft-3 (T-2590/T-2591): pair-draft-3 was hand-authored by 832's
agent; the S4 exemplar must be drawn in their EDITOR through the real placement
picker (rail offset 137, vehicle B). What that buys: proof that the editor's
emit path — picker-bound workflowRef, intermediateThrow/CatchEvent + aef:link
child dialect (offset 129/130), <aef:workflowMeta uuid> identity (their S1) —
produces bytes our whole consumer chain accepts: Pass-5 compile, registry
rescan (web/designer_registry.sync_project_refs), ghost wire shape.

Drop procedure:
  1. Save 832's exemplar bytes verbatim to  tests/fixtures/832/s4-exemplar.bpmn
  2. Save their announced sha256 (hex, one line) to
     tests/fixtures/832/s4-exemplar.sha256
  3. Run:  python3 -m pytest tests/web/test_s4_exemplar_intake.py -q

Until the bytes land the fixture tests skip cleanly; the synthetic test keeps
the per-leg registry-outcome assertions green so intake is proven pre-delivery.
"""

import hashlib
import json
import sys
import uuid as uuid_mod
import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

from tests.web.test_designer_registry_ghosts import bpmn_with_links
from web.designer_registry import sync_project_refs

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "tools"))

import bpmn_to_tasks  # noqa: E402

FIXTURE = REPO_ROOT / "tests" / "fixtures" / "832" / "s4-exemplar.bpmn"
SHA_PIN = FIXTURE.with_suffix(".sha256")
LIVE_STORE = REPO_ROOT / ".context" / "designer" / "projects"

# Live corpus uuid recommended for the RESOLVED leg (same anchor as pair-draft-3).
LIVE_UUID = "1f9b5f0c-0be4-4cfe-9158-d9e6f0c1d4c7"  # aef-task-lifecycle

# 832's editor emit dialect (offset 129): aef:link rides extensionElements on an
# intermediate throw/catch event. Hand-authored pair-draft-3 used linkEventThrow
# — its absence here is the editor-authorship fingerprint.
EDITOR_HOSTS = {"intermediateThrowEvent", "intermediateCatchEvent"}


def _local(tag):
    return tag.rsplit("}", 1)[-1]


def _clone_store_metas(src, dst):
    """Minimal meta.json clones of a live store — uuid/slug view only, so
    sync_project_refs resolves against real corpus identity without touching
    the live registry."""
    dst.mkdir(parents=True, exist_ok=True)
    for d in src.iterdir() if src.is_dir() else []:
        mp = d / "meta.json"
        if not mp.is_file():
            continue
        try:
            m = json.loads(mp.read_text())
        except (OSError, ValueError):
            continue
        pd = dst / d.name
        pd.mkdir()
        (pd / "meta.json").write_text(
            json.dumps({"id": d.name, "uuid": m.get("uuid")})
        )


def _classify(link, live_uuids, live_slugs):
    """Contract-v0 leg taxonomy for one aef:link element."""
    wref = link.get("workflowRef")
    target = link.get("targetWorkflow") or ""
    if wref and wref in live_uuids:
        return "resolved"
    if wref:
        return "ghost"
    return "legacy-live" if (target or link.get("name")) in live_slugs else "legacy-ghost"


def _registry_outcome_asserts(reg, legs_by_kind, project_id):
    """Per-leg registry outcome per the corrected S3b spec (rail offsets 134/135)."""
    ghosts = reg["ghosts"]
    by_uuid = {g["uuid"]: g for g in ghosts}
    for kind, links in legs_by_kind.items():
        for link in links:
            wref = link.get("workflowRef")
            name = link.get("name") or link.get("targetWorkflow") or ""
            if kind == "resolved":
                assert wref not in by_uuid, f"resolved uuid {wref} wrongly ghosted"
            elif kind == "ghost":
                g = by_uuid.get(wref)
                assert g, f"unresolved uuid {wref} produced no ghost"
                assert any(r["id"] == project_id for r in g["referenced_by"])
            elif kind == "legacy-ghost":
                g = next((g for g in ghosts if g["name"] == name), None)
                assert g, f"legacy slug {name!r} produced no minted ghost"
                # store-minted identity: registry-side uuid4, never from the XML
                assert uuid_mod.UUID(g["uuid"]), g["uuid"]
            else:  # legacy-live: resolved by name — skip-recorded
                assert not any(g["name"] == name for g in ghosts), (
                    f"live slug {name!r} wrongly ghosted"
                )
    # wire shape (offset 136: {uuid,name,referenced_by,task,first_seen})
    for g in ghosts:
        assert set(g) >= {"uuid", "name", "referenced_by", "task", "first_seen"}, g


def test_synthetic_editor_dialect_three_legs(tmp_path):
    """Pre-delivery proof: editor-dialect bytes (intermediateThrowEvent +
    extensionElements, the exact emit shape) run through the real
    sync_project_refs and land the per-leg registry outcomes — then the
    single drop rule clears them when the refs are removed."""
    store = tmp_path / "projects"
    proj = store / "aef-task-lifecycle"
    proj.mkdir(parents=True)
    (proj / "meta.json").write_text(
        json.dumps({"id": "aef-task-lifecycle", "uuid": LIVE_UUID})
    )
    ghost_uuid = "33333333-3333-4333-8333-333333333333"
    bpmn = bpmn_with_links(
        ("n1", "resolved", f'<aef:link workflowRef="{LIVE_UUID}" name="task lifecycle"/>'),
        ("n2", "ghost", f'<aef:link workflowRef="{ghost_uuid}" name="future flow"/>'),
        ("n3", "legacy", '<aef:link targetWorkflow="not-live-yet"/>'),
    )
    reg = sync_project_refs(store, "s4-synth", bpmn)
    root = ET.fromstring(bpmn)
    links = [el for el in root.iter() if _local(el.tag) == "link"]
    legs = {"resolved": [], "ghost": [], "legacy-ghost": [], "legacy-live": []}
    for link in links:
        legs[_classify(link, {LIVE_UUID}, {"aef-task-lifecycle"})].append(link)
    assert [len(legs[k]) for k in ("resolved", "ghost", "legacy-ghost")] == [1, 1, 1]
    _registry_outcome_asserts(reg, legs, "s4-synth")

    # single drop rule (task is None on both twins' unminted entries): a rescan
    # with the refs gone empties referenced_by -> every ghost drops.
    reg = sync_project_refs(store, "s4-synth", bpmn_with_links())
    assert reg["ghosts"] == [], reg["ghosts"]


def _fixture_or_skip():
    if not FIXTURE.exists():
        pytest.skip(
            "832 S4 exemplar not yet delivered — drop bytes at "
            f"{FIXTURE.relative_to(REPO_ROOT)} (+ .sha256 sibling) and rerun"
        )
    assert SHA_PIN.exists(), "fixture present but sha256 pin sibling is missing"
    pinned = SHA_PIN.read_text().split()[0].strip().lower()
    actual = hashlib.sha256(FIXTURE.read_bytes()).hexdigest()
    assert actual == pinned, f"sha mismatch: fixture {actual} != pinned {pinned}"


def test_s4_fixture_editor_authorship_fingerprint():
    """The delta pair-draft-3 didn't cover: bytes must carry the editor's emit
    signature — workflowMeta identity + throw/catch host dialect (no
    hand-authored linkEventThrow), links riding extensionElements."""
    _fixture_or_skip()
    root = ET.parse(FIXTURE).getroot()

    metas = [el for el in root.iter() if _local(el.tag) == "workflowMeta"]
    assert metas and metas[0].get("uuid"), "editor S1 identity (workflowMeta uuid) missing"
    uuid_mod.UUID(metas[0].get("uuid"))  # raises if malformed

    assert not any(
        _local(el.tag) in ("linkEventThrow", "linkEventCatch") for el in root.iter()
    ), "hand-authored linkEvent dialect found — exemplar must be editor-emitted"

    parent_of = {c: p for p in root.iter() for c in p}
    links = [el for el in root.iter() if _local(el.tag) == "link"]
    assert links, "exemplar contains no aef:link refs"
    for link in links:
        host, cur = None, link
        while cur is not None:
            cur = parent_of.get(cur)
            if cur is not None and cur.get("id"):
                host = cur
                break
        assert host is not None and _local(host.tag) in EDITOR_HOSTS, (
            f"link host {_local(host.tag) if host is not None else None!r} "
            f"is not the editor emit dialect"
        )
        assert _local(parent_of[link].tag) == "extensionElements", (
            "aef:link must ride extensionElements"
        )


def test_s4_fixture_compile_and_registry(monkeypatch, tmp_path):
    """832's actual bytes through the full consumer chain: Pass-5 taxonomy
    against the LIVE store, then registry rescan against a meta-clone of it."""
    _fixture_or_skip()
    monkeypatch.setenv("FW_DESIGNER_STORE", str(LIVE_STORE))
    _, warnings = bpmn_to_tasks.parse_bpmn(str(FIXTURE))
    assert not any("no designer store found" in w for w in warnings), warnings
    link_warns = [w for w in warnings if "T-2576" in w]

    live_uuids, live_slugs = set(), set()
    for d in LIVE_STORE.iterdir() if LIVE_STORE.is_dir() else []:
        mp = d / "meta.json"
        if mp.is_file():
            live_slugs.add(d.name)
            u = json.loads(mp.read_text()).get("uuid")
            if u:
                live_uuids.add(u)

    root = ET.parse(FIXTURE).getroot()
    links = [el for el in root.iter() if _local(el.tag) == "link"]
    legs = {"resolved": [], "ghost": [], "legacy-ghost": [], "legacy-live": []}
    for link in links:
        kind = _classify(link, live_uuids, live_slugs)
        legs[kind].append(link)
        wref = link.get("workflowRef")
        if kind == "resolved":
            assert not any(f"workflowRef {wref}" in w for w in link_warns), (
                f"resolved uuid {wref} wrongly WARNed"
            )
        elif kind == "ghost":
            assert any(f"fw bpmn claim {wref}" in w for w in link_warns), (
                f"ghost uuid {wref} missing claim WARN"
            )
    assert legs["resolved"] and legs["ghost"], (
        f"S4 exemplar must exercise resolved + ghost legs at minimum: "
        f"{ {k: len(v) for k, v in legs.items()} }"
    )
    assert legs["legacy-ghost"] or legs["legacy-live"], "legacy leg missing"

    store = tmp_path / "projects"
    _clone_store_metas(LIVE_STORE, store)
    reg = sync_project_refs(store, "s4-exemplar", FIXTURE.read_text())
    _registry_outcome_asserts(reg, legs, "s4-exemplar")
