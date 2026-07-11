"""Designer gallery-server API (T-2529) — the ``/api/*`` endpoints that 832's
shipped 0.2.0 Workflow Designer client already calls.

The client (served read-only by ``designer.py`` at ``/designer``) is
progressive-enhancement-gated: ``detectSaveApi()`` probes ``GET /api/health`` and
only reveals its save / open-project / versions buttons when a write-capable
"gallery server" answers ``{"ok": true}``. On a static serve, ``/api/health``
404s and the buttons stay hidden — that is the operator's "cannot save to
project" (T-2528 GO). This blueprint is the AEF side of that contract.

Contract recovered verbatim from the shipped client; full table in
``docs/reports/T-2522-bpmn-aef-mapping-contract.md`` (IW-8-CORRECTED):

    GET  /api/health                      -> {"ok": true}
    GET  /api/list                        -> {"maps": [{id, title, v, updated, versions}]}
    POST /api/save   {id,bpmn,png,note}   -> {"ok": true, "v": N}   (versioned)
    GET  /api/versions?id=<id>            -> [{"v": N, "note", "ts"}]  (desc client-side)
    GET  /api/version?id=<id>&v=<v>       -> bpmn (application/xml)
    POST /api/delete {id,scope,v}         -> {"ok": true}

    id constraint: ^[a-z0-9][a-z0-9_-]*$

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
import time
from pathlib import Path

from flask import Blueprint, Response, jsonify, request

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
    """Progressive-enhancement gate — presence + {ok:true} lights up the client."""
    return _ok()


@bp.route("/api/save", methods=["POST"])
def save():
    data = request.get_json(silent=True) or {}
    i = data.get("id")
    bpmn = data.get("bpmn")
    if not _valid_id(i):
        return _err('invalid id (must match ^[a-z0-9][a-z0-9_-]*$)')
    if not isinstance(bpmn, str) or not bpmn.strip():
        return _err("missing bpmn")
    png = data.get("png") or ""
    note = data.get("note") or ""

    meta = _read_meta(i) or {"id": i, "title": i, "versions": []}
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
            # Shape the client expects (recovered from the 0.2.0 card browser):
            #   saved = m.latest && m.openTarget && m.openTarget.kind === 'version'
            #   thumb = /api/thumb?id=&v=m.latest.v ; open via m.openTarget.v
            maps.append({
                "id": m["id"],
                "title": m.get("title", m["id"]),
                "updated": int(m.get("updated", 0)),
                "latest": {"v": latest_v},
                "openTarget": {"kind": "version", "v": latest_v},
                "versions": len(m.get("versions", [])),
            })
    return jsonify({"maps": maps})


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
    i = request.args.get("id", "")
    v = request.args.get("v", "")
    if not _valid_id(i):
        return _err("invalid id")
    try:
        vn = int(v)
    except (ValueError, TypeError):
        return _err("invalid v")
    p = _map_dir(i) / f"v{vn}.bpmn"
    if not p.is_file():
        return _err("not found", 404)
    return Response(p.read_text(), mimetype="application/xml")


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
