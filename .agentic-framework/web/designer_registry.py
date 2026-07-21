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

import os
import re
import sys
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

    # Drop rules (T-2579 composition-test finding): a ghost with no remaining
    # referrers is kept ONLY while it represents open debt — a minted doc task
    # for a target that still doesn't exist (deleted-connector case). If the
    # named target now lives in the store, the legacy refs resolve by name and
    # the debt is closed — keeping it would show a stale "needs mapping" card
    # forever. (uuid-pinned ghosts never resolve by name; they exit via claim,
    # which removes them explicitly.)
    reg["ghosts"] = [
        g
        for g in reg["ghosts"]
        if (g["referenced_by"] or g.get("task"))
        and not (not g["referenced_by"] and g.get("name") in slugs)
    ]
    save_registry(store, reg)
    return reg


def _fw_bin(store: Path) -> Path | None:
    """fw shim for the project owning this store. FW_BIN override, else derived
    from the store path: framework repo ``bin/fw``, consumer
    ``.agentic-framework/bin/fw``. None when neither exists (minting skipped)."""
    env = os.environ.get("FW_BIN")
    if env:
        return Path(env)
    root = registry_path(store).parents[2]  # <root>/.context/designer/registry.yaml
    for cand in (root / "bin" / "fw", root / ".agentic-framework" / "bin" / "fw"):
        if cand.is_file():
            return cand
    return None


def mint_ghost_tasks(store: Path, runner=None) -> list[dict]:
    """Mint a documentation task for every ghost lacking one (T-2577, T-2571 S4).

    The operator's original sketch: "in parallel create a task to document the
    workflow" — this is that parallel leg, fired at save-time so the task exists
    the moment the forward-reference is drawn. Shape is enforced by the GATE,
    not this caller (T-2543 pattern): the create runs through ``fw task create``
    with ``FW_TASK_ORIGIN=designer-ghost``, which create-task.sh refuses unless
    owner:human + captured. horizon:later so a mint never steals focus
    (T-100146 class). Idempotent per uuid: ``ghost["task"]`` records the T-ID
    and minted ghosts are skipped forever after.

    Non-fatal by contract: a failed mint leaves ``task: null`` (stderr WARN) and
    the caller's save proceeds — the audit sweep flags stale unminted ghosts.
    ``runner`` is injectable for tests: ``runner(args) -> (rc, output)``.
    """
    reg = load_registry(store)
    pending = [g for g in reg["ghosts"] if not g.get("task")]
    if not pending:
        return []
    if runner is None:
        fw = _fw_bin(store)
        if fw is None:
            print(
                "designer-registry: no fw shim found for store — "
                "ghost task minting skipped (audit sweep will flag)",
                file=sys.stderr,
            )
            return []

        def runner(args):
            import subprocess

            env = dict(os.environ, FW_TASK_ORIGIN="designer-ghost")
            p = subprocess.run(
                [str(fw), *args], capture_output=True, text=True, env=env
            )
            return p.returncode, p.stdout + p.stderr

    minted = []
    for g in pending:
        refs = ", ".join(
            f"{r['id']}:{r['node']}" for r in g["referenced_by"]
        ) or "(none yet)"
        name = g["name"] or g["uuid"][:8]
        rc, out = runner([
            "task", "create",
            "--name", f"Document workflow '{name}' (referenced, not yet created)",
            "--description",
            (
                f"Off-page connector(s) reference a workflow that does not exist "
                f"yet (T-2571 ghost). uuid: {g['uuid']}. Referenced by: {refs}. "
                f"Create/document the workflow in the designer, then bind the "
                f"identity: fw bpmn claim {g['uuid']} <project>"
            ),
            "--type", "build",
            "--owner", "human",
            "--horizon", "later",
        ])
        if rc != 0:
            print(
                f"designer-registry: ghost task mint failed for {g['uuid']} "
                f"(rc={rc}): {out.strip()[:300]}",
                file=sys.stderr,
            )
            continue
        m = re.search(r"^ID:\s*(\S+)", out, re.MULTILINE)
        if not m:
            print(
                f"designer-registry: could not parse task id from create output "
                f"for {g['uuid']} — leaving task: null",
                file=sys.stderr,
            )
            continue
        g["task"] = m.group(1)
        minted.append({"uuid": g["uuid"], "task": g["task"]})
    if minted:
        save_registry(store, reg)
    return minted


class ClaimError(ValueError):
    """Refused claim — message is operator-actionable."""


def claim_ghost(store: Path, ghost_uuid: str, project_id: str, via: str = "cli") -> dict:
    """Bind a pending ghost uuid to a live project (T-2575, T-2571 S6).

    The claim moment: the project adopts the uuid every referring connector
    already pins, so all referrers resolve with zero diagram edits. Refusals
    keep the single-uuid-namespace invariant (rail offset 110/111): a project
    that already owns a DIFFERENT uuid can never be re-bound.

    Returns {"uuid", "project", "resolved_referrers": N}.
    """
    import json

    reg = load_registry(store)
    ghost = next((g for g in reg["ghosts"] if g["uuid"] == ghost_uuid), None)
    if ghost is None:
        known = ", ".join(g["uuid"] for g in reg["ghosts"]) or "(registry has no ghosts)"
        raise ClaimError(f"unknown ghost uuid {ghost_uuid!r} — pending: {known}")
    meta_p = store / project_id / "meta.json"
    if not meta_p.is_file():
        raise ClaimError(f"project {project_id!r} not found in store {store}")
    meta = json.loads(meta_p.read_text())
    if meta.get("uuid") and meta["uuid"] != ghost_uuid:
        raise ClaimError(
            f"project {project_id!r} already owns uuid {meta['uuid']} — "
            f"uuids are immutable; a claim binds, never re-mints"
        )
    meta["uuid"] = ghost_uuid
    tmp = meta_p.with_name("meta.json.tmp")
    tmp.write_text(json.dumps(meta, indent=2))
    tmp.replace(meta_p)

    reg["ghosts"] = [g for g in reg["ghosts"] if g["uuid"] != ghost_uuid]
    reg["claims"].append({
        "uuid": ghost_uuid,
        "project": project_id,
        "ts": int(time.time()),
        "via": via,
    })
    save_registry(store, reg)
    return {
        "uuid": ghost_uuid,
        "project": project_id,
        "resolved_referrers": len(ghost["referenced_by"]),
    }


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
