"""Pending-ref registry for off-page workflow connectors (T-2574, T-2571 S2).

Contract v0 (rail offsets 108/109, ratified with 832):

- Connectors serialize as ``<aef:link workflowRef="<uuid>" name="<display>"
  linkId="…"/>`` riding a flow node's extensionElements; legacy maps carry
  ``targetWorkflow="<slug>"`` instead of ``workflowRef`` (832 import alias).
- A reference whose target workflow does not exist yet becomes a GHOST entry in
  ``.context/designer/registry.yaml`` — uuid-keyed, carrying every referrer
  (project id + node id + node label) so the gallery can render "referenced by"
  markers and a claim can resolve all referrers at once.
- For a workflowRef-less unresolved ref the STORE mints the ghost uuid
  (registry-side only — the diagram XML is never rewritten); deduped by display
  name so two referrers naming the same missing workflow share one ghost.
- ``claims`` is the audit trail: on claim the ghost is removed, its uuid written
  to the claiming project's meta.json (S6, ``fw bpmn claim``).

Pure stdlib + PyYAML — importable from Flask (web/blueprints/designer_api.py)
and CLI (fw bpmn claim / compile) alike. Lives under web/ (NOT tools/) so
``fw vendor self`` ships it to consumers alongside the blueprint that imports
it — tools/ is not part of the vendored tree. All writes atomic (temp +
os.replace, L-493); timestamps are epoch ints (never ISO — L-495/OBS-085 class).
"""

from __future__ import annotations

import time
import uuid as _uuid
import xml.etree.ElementTree as ET
from pathlib import Path

import yaml

AEF_NS = "http://anchorpoint.framework/aef/extensions"
_LINK = f"{{{AEF_NS}}}link"

_EMPTY = {"ghosts": [], "claims": []}


def registry_path(store: Path) -> Path:
    """Registry lives beside ``projects/`` — part of the STORE, not the server."""
    return store.parent / "registry.yaml"


def load_registry(store: Path) -> dict:
    p = registry_path(store)
    try:
        data = yaml.safe_load(p.read_text()) or {}
    except (OSError, yaml.YAMLError):
        return {"ghosts": [], "claims": []}
    return {"ghosts": data.get("ghosts") or [], "claims": data.get("claims") or []}


def save_registry(store: Path, reg: dict) -> None:
    p = registry_path(store)
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_name(p.name + ".tmp")
    tmp.write_text(yaml.safe_dump(reg, sort_keys=False))
    tmp.replace(p)


def extract_links(bpmn: str) -> list[dict]:
    """All aef:link refs with their host flow node's id and display name.

    ET has no parent pointers, so the host is found by walking every element
    that (transitively) contains the link and keeping the nearest one carrying
    an ``id`` — in practice the flow node whose extensionElements holds it.
    """
    root = ET.fromstring(bpmn)
    parent_of = {child: parent for parent in root.iter() for child in parent}
    links = []
    for link in root.iter(_LINK):
        host, cur = None, link
        while cur is not None:
            cur = parent_of.get(cur)
            if cur is not None and cur.get("id"):
                host = cur
                break
        links.append({
            "workflowRef": link.get("workflowRef"),
            "targetWorkflow": link.get("targetWorkflow"),
            "name": link.get("name") or link.get("targetWorkflow") or "",
            "node": host.get("id") if host is not None else "",
            "nodeName": (host.get("name") or "") if host is not None else "",
        })
    return links


def _known(store: Path) -> tuple[dict, set]:
    """(uuid -> project id, {slug}) for every live project in the store."""
    import json

    uuids, slugs = {}, set()
    if store.is_dir():
        for d in store.iterdir():
            mp = d / "meta.json"
            if not mp.is_file():
                continue
            try:
                m = json.loads(mp.read_text())
            except (OSError, ValueError):
                continue
            slugs.add(d.name)
            if m.get("uuid"):
                uuids[m["uuid"]] = d.name
    return uuids, slugs


def sync_project_refs(store: Path, project_id: str, bpmn: str) -> dict:
    """Rescan ``project_id``'s refs from its just-saved BPMN into the registry.

    Replace-semantics: the save is the authority on what this project references
    NOW — its old ``referenced_by`` entries are stripped first, so deleted
    connectors disappear. Ghosts left with no referrers are dropped unless a
    documentation task was already minted for them (the task keeps the debt
    visible until resolved). Returns the saved registry.
    """
    uuids, slugs = _known(store)
    reg = load_registry(store)

    for g in reg["ghosts"]:
        g["referenced_by"] = [r for r in g["referenced_by"] if r["id"] != project_id]

    for ref in extract_links(bpmn):
        wref = ref["workflowRef"]
        if wref and wref in uuids:
            continue  # resolved by uuid — nothing to record
        if not wref and (ref["targetWorkflow"] or ref["name"]) in slugs:
            continue  # legacy resolve-by-name — live target; migrate-WARN is compile's job (S3)
        entry = {"id": project_id, "node": ref["node"], "nodeName": ref["nodeName"]}
        ghost = None
        if wref:
            ghost = next((g for g in reg["ghosts"] if g["uuid"] == wref), None)
        if ghost is None and not wref and ref["name"]:
            ghost = next((g for g in reg["ghosts"] if g["name"] == ref["name"]), None)
        if ghost is None:
            ghost = {
                "uuid": wref or str(_uuid.uuid4()),
                "name": ref["name"],
                "referenced_by": [],
                "task": None,
                "first_seen": int(time.time()),
            }
            reg["ghosts"].append(ghost)
        if entry not in ghost["referenced_by"]:
            ghost["referenced_by"].append(entry)

    reg["ghosts"] = [g for g in reg["ghosts"] if g["referenced_by"] or g.get("task")]
    save_registry(store, reg)
    return reg


def remove_project_refs(store: Path, project_id: str) -> dict:
    """Strip a deleted project's referrer entries (delete has no save to rescan).

    Without this, ``/api/delete scope=map`` would leave ghost back-references
    pointing at a project that no longer exists — silent registry drift.
    """
    reg = load_registry(store)
    for g in reg["ghosts"]:
        g["referenced_by"] = [r for r in g["referenced_by"] if r["id"] != project_id]
    reg["ghosts"] = [g for g in reg["ghosts"] if g["referenced_by"] or g.get("task")]
    save_registry(store, reg)
    return reg
