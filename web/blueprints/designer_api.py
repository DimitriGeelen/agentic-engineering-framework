"""Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's
shipped 0.2.0 Workflow Designer client already calls.

The client (served read-only by ``designer.py`` at ``/designer``) is
progressive-enhancement-gated: ``detectSaveApi()`` probes ``GET /api/health`` and
only reveals its save / open-project / versions buttons when a write-capable
"gallery server" answers ``{"ok": true}``. On a static serve, ``/api/health``
404s and the buttons stay hidden — that is the operator's "cannot save to
project" (T-2528 GO). This blueprint is the AEF side of that contract.

Contract: recovered from the shipped client (T-2529), then corrected against 832's
authoritative reference server ``tools/gallery-serve.py`` (T-2523 rail offset 12,
T-2530). Full table in ``docs/reports/T-2522-bpmn-aef-mapping-contract.md``:

    GET  /api/health                      -> {"ok": true, "store": "<store-id>"}
    GET  /api/list                        -> {"maps": [{id, title, sources:[saved|rendered],
                                                         latest:{v,ts,count}, openTarget:{kind,v}}]}
    POST /api/save   {id,bpmn,png,note}   -> {"ok": true, "v": N}   (versioned)
    GET  /api/versions?id=<id>            -> [{"v": N, "note", "ts"}]  (desc client-side)
    GET  /api/version?id=<id>&v=<v>       -> bpmn (text/xml)
    GET  /api/thumb?id=<id>&v=<v>         -> png bytes (decoded from stored data-url)
    POST /api/delete {id,scope,v}         -> {"ok": true}

    id constraint: ^[a-z0-9][a-z0-9_-]*$
    /api/list: NO `updated` (use latest.ts); NO `versions` array (use /api/versions).

Store (runtime data plane; NOT the vendored build, which stays read-only):
    .context/designer/projects/<id>/meta.json   {id,title,latest,updated,versions:[{v,note,ts}]}
    .context/designer/projects/<id>/v<N>.bpmn
    .context/designer/projects/<id>/v<N>.png     (thumbnail data-url as sent by the client)

`rendered/<id>.bpmn` (pre-rendered corpus) is a follow-up — the client falls back
gracefully when it is absent, so saved maps work without it.
"""

import json
import re
import shutil
import sys
import time
import uuid as _uuid
import xml.etree.ElementTree as ET
from pathlib import Path

from flask import Blueprint, Response, jsonify, request

from web.designer_registry import (
    load_registry,
    mint_ghost_tasks,
    remove_project_refs,
    sync_project_refs,
)
from web.shared import PROJECT_ROOT

bp = Blueprint("designer_api", __name__)

_STORE = PROJECT_ROOT / ".context" / "designer" / "projects"
_ID_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")


def _valid_id(i):
    return isinstance(i, str) and bool(_ID_RE.match(i))


def _map_dir(i: str) -> Path:
    return _STORE / i


def _meta_path(i: str) -> Path:
    return _map_dir(i) / "meta.json"


def _read_meta(i: str):
    try:
        return json.loads(_meta_path(i).read_text())
    except (OSError, json.JSONDecodeError):
        return None


def _write_meta(i: str, meta: dict):
    d = _map_dir(i)
    d.mkdir(parents=True, exist_ok=True)
    # atomic replace (L-493): write temp in same dir, then os.replace via Path.replace
    tmp = _meta_path(i).with_name("meta.json.tmp")
    tmp.write_text(json.dumps(meta, indent=2))
    tmp.replace(_meta_path(i))


def _ok(**kw):
    d = {"ok": True}
    d.update(kw)
    return jsonify(d)


def _err(msg, code=400):
    return jsonify({"ok": False, "error": msg}), code


@bp.route("/api/health")
def health():
    """Progressive-enhancement gate — presence + {ok:true} lights up the client.

    Authoritative contract carries a diagnostic `store` key (832 ref server, T-2523
    rail offset 12: `{ok:true, store:'.editor-versions'}`). AEF reports its own store
    identifier honestly rather than echoing 832's literal — the client gates on
    `ok:true`; `store` is diagnostic (T-2530).
    """
    return _ok(store=".context/designer/projects")


@bp.route("/api/save", methods=["POST"])
def save():
    data = request.get_json(silent=True) or {}
    i = data.get("id")
    bpmn = data.get("bpmn")
    if not _valid_id(i):
        return _err('invalid id (must match ^[a-z0-9][a-z0-9_-]*$)')
    if not isinstance(bpmn, str) or not bpmn.strip():
        return _err("missing bpmn")
    # T-2564: well-formedness gate at the store boundary. Origin: D4 v1 (T-2563) —
    # a payload with a raw `<dispatch_id>` in an attribute was ACCEPTED here and only
    # `fw bpmn compile` caught it downstream. The str(ParseError) carries line/column
    # ("not well-formed (invalid token): line 62, column 75") — surfaced to the client
    # so the designer can point at the defect. Nothing is written on reject.
    try:
        ET.fromstring(bpmn)
    except ET.ParseError as e:
        return _err(f"malformed XML: {e}")
    png = data.get("png") or ""
    note = data.get("note") or ""

    meta = _read_meta(i) or {"id": i, "title": i, "versions": []}
    # T-2573 (T-2571 S1): immutable workflow identity. Minted once — on project
    # creation or the first save of a pre-uuid legacy meta — and never rewritten;
    # off-page workflowRef connectors pin this, so a changed uuid would orphan
    # every referring diagram (contract v0, rail offsets 108/109).
    meta.setdefault("uuid", str(_uuid.uuid4()))
    v = int(meta.get("latest") or 0) + 1
    d = _map_dir(i)
    d.mkdir(parents=True, exist_ok=True)
    (d / f"v{v}.bpmn").write_text(bpmn)
    if png:
        (d / f"v{v}.png").write_text(png)
    meta["latest"] = v
    meta["updated"] = int(time.time())
    meta.setdefault("versions", []).append({"v": v, "note": note, "ts": meta["updated"]})
    _write_meta(i, meta)
    # T-2574 (T-2571 S2): rescan this project's off-page refs into the pending-ref
    # registry — capture-at-source, so a dangling workflowRef becomes a ghost the
    # moment it is saved, not when someone later runs a verb.
    sync_project_refs(_STORE, i, bpmn)
    # T-2577 (T-2571 S4): mint the parallel documentation task for any NEW ghost
    # through the gated writer (FW_TASK_ORIGIN=designer-ghost — gate enforces
    # owner:human + captured; horizon:later so it never steals focus). Non-fatal
    # by contract: the save must succeed even when minting cannot — the ghost
    # persists with task:null and the audit sweep flags it.
    try:
        mint_ghost_tasks(_STORE)
    except Exception as e:
        print(f"designer-api: ghost task minting failed: {e}", file=sys.stderr)
    return _ok(v=v)


@bp.route("/api/list")
def list_maps():
    maps = []
    if _STORE.is_dir():
        for d in sorted(_STORE.iterdir()):
            if not d.is_dir():
                continue
            m = _read_meta(d.name)
            if not m:
                continue
            latest_v = int(m.get("latest", 0))
            if latest_v < 1:
                continue  # no versions on disk — skip empty stubs
            # Authoritative shape (832 ref server tools/gallery-serve.py, T-2523 rail offset 12):
            #   {id, title, sources:[rendered|saved], latest:{v,ts,count}, openTarget:{kind:'version',v}}
            #   - sources distinguishes canonical-corpus ("rendered") from user-saved ("saved");
            #     AEF's store holds only user-saved maps for now → ["saved"] (T-2530).
            #   - latest is {v,ts,count}, NOT scalar {v}; ts = latest version's ts, count = #versions.
            #   - NO `updated` key (timestamp is latest.ts); NO `versions` array (see /api/versions).
            vlist = m.get("versions", [])
            latest_entry = next((x for x in vlist if x.get("v") == latest_v), None)
            latest_ts = int(
                latest_entry["ts"]
                if latest_entry and "ts" in latest_entry
                else m.get("updated", 0)
            )
            maps.append({
                "id": m["id"],
                "title": m.get("title", m["id"]),
                # T-2573: additive identity field (contract v0, offset 109) —
                # 0.3.0 pickers ignore it; workflowRef-aware pickers key on it.
                "uuid": m.get("uuid"),
                "sources": ["saved"],
                "latest": {"v": latest_v, "ts": latest_ts, "count": len(vlist)},
                "openTarget": {"kind": "version", "v": latest_v},
            })
    # T-2574: ghosts partitioned as a SEPARATE array (contract v0, offset 109) —
    # never folded into maps[], where a pre-contract picker would try to open one
    # (no versions on disk → openTarget contract breaks).
    ghosts = [
        {
            "uuid": g["uuid"],
            "name": g["name"],
            "referenced_by": g["referenced_by"],
            "task": g.get("task"),
            "first_seen": g.get("first_seen"),
        }
        for g in load_registry(_STORE)["ghosts"]
    ]
    return jsonify({"maps": maps, "ghosts": ghosts})


@bp.route("/api/thumb")
def thumb():
    """Version PNG for the card browser. `?id=&v=` → that version's thumbnail;
    `?id=` alone → latest. Stored as the data-url the client sent on save; decoded
    to image bytes here. 404 → client renders its ▦ placeholder (graceful)."""
    i = request.args.get("id", "")
    if not _valid_id(i):
        return _err("invalid id")
    v = request.args.get("v", "")
    if v:
        try:
            vn = int(v)
        except (ValueError, TypeError):
            return _err("invalid v")
    else:
        m = _read_meta(i)
        vn = int(m.get("latest", 0)) if m else 0
    p = _map_dir(i) / f"v{vn}.png"
    if not p.is_file():
        return _err("not found", 404)
    raw = p.read_text()
    if raw.startswith("data:"):
        import base64
        header, _, b64 = raw.partition(",")
        mime = header[5:].split(";")[0] or "image/png"
        try:
            return Response(base64.b64decode(b64), mimetype=mime)
        except (ValueError, TypeError):
            return _err("bad thumb", 404)
    return Response(raw, mimetype="image/png")


@bp.route("/api/versions")
def versions():
    i = request.args.get("id", "")
    if not _valid_id(i):
        return jsonify([])
    m = _read_meta(i)
    if not m:
        return jsonify([])
    vs = sorted(m.get("versions", []), key=lambda x: x.get("v", 0), reverse=True)
    return jsonify(vs)


@bp.route("/api/version")
def version():
    """`?id=&v=` → that version's bpmn; `?id=` alone → latest (T-2624, additive —
    same missing-v resolution /api/thumb already has; 832's client always passes
    an explicit v, deep-link consumers like the read-value map links need not
    hardcode a version that goes stale on every save)."""
    i = request.args.get("id", "")
    v = request.args.get("v", "")
    if not _valid_id(i):
        return _err("invalid id")
    if v:
        try:
            vn = int(v)
        except (ValueError, TypeError):
            return _err("invalid v")
    else:
        m = _read_meta(i)
        vn = int(m.get("latest", 0)) if m else 0
    p = _map_dir(i) / f"v{vn}.bpmn"
    if not p.is_file():
        return _err("not found", 404)
    # text/xml to exactly match 832's reference gallery-serve.py contract (T-2530).
    return Response(p.read_text(), mimetype="text/xml")


@bp.route("/api/delete", methods=["POST"])
def delete():
    data = request.get_json(silent=True) or {}
    i = data.get("id")
    scope = data.get("scope", "version")
    if not _valid_id(i):
        return _err("invalid id")
    m = _read_meta(i)
    if not m:
        return _err("not found", 404)

    if scope == "map":
        shutil.rmtree(_map_dir(i), ignore_errors=True)
        # T-2574: a deleted project can no longer reference anything — strip its
        # ghost back-references or the registry drifts against the store.
        remove_project_refs(_STORE, i)
        return _ok()

    # version scope (client sends scope:'version')
    try:
        vn = int(data.get("v"))
    except (ValueError, TypeError):
        return _err("invalid v")
    (_map_dir(i) / f"v{vn}.bpmn").unlink(missing_ok=True)
    (_map_dir(i) / f"v{vn}.png").unlink(missing_ok=True)
    m["versions"] = [x for x in m.get("versions", []) if x.get("v") != vn]
    m["latest"] = max((x["v"] for x in m["versions"]), default=0)
    _write_meta(i, m)
    return _ok()
