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
from web import designer_thumb
from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT

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


# T-4402: the one lens definition (tools/corpus_lenses.yaml), read by designer 0.25.0's
# lens switch (T-1241). FRAMEWORK_ROOT, not PROJECT_ROOT: the file ships with the
# framework (tools/ is vendored whole), it is not per-project data.
_LENS_FILE = FRAMEWORK_ROOT / "tools" / "corpus_lenses.yaml"
_LENS_LISTS = ("fields", "bpmn", "sections", "canvas")


def load_lens_definition(path=None):
    """Return (definition, error). Refuses rather than repairs: a definition the
    designer would half-read is answered as no definition, and the designer falls
    back to All."""
    import yaml

    try:
        d = yaml.safe_load(Path(path or _LENS_FILE).read_text())
    except (OSError, yaml.YAMLError) as e:
        return None, f"lens definition unreadable: {e}"
    lenses = d.get("lenses") if isinstance(d, dict) else None
    if not isinstance(lenses, dict) or not lenses:
        return None, "lens definition has no lenses"
    order = d.get("order")
    if not isinstance(order, list) or sorted(order) != sorted(lenses) or "all" in lenses:
        return None, "lens order must name every lens exactly once (and 'all' is reserved)"
    for name, lens in lenses.items():
        if not isinstance(lens, dict):
            return None, f"lens {name}: not a mapping"
        for k in _LENS_LISTS:
            v = lens.get(k, [])
            if not isinstance(v, list) or not all(isinstance(x, str) for x in v):
                return None, f"lens {name}: {k} must be a list of names"
        seen, cur = {name}, lens.get("extends")
        while cur:
            if cur not in lenses or cur in seen:
                return None, f"lens {name}: extends chain broken at {cur}"
            seen.add(cur)
            cur = lenses[cur].get("extends")
    return d, None


@bp.route("/api/lens-definition")
def lens_definition():
    """GET -> {"ok": true, "definition": {order, lenses}} (designer 0.25.0, T-1241)."""
    d, err = load_lens_definition()
    if err:
        return _err(err, 500)
    return _ok(definition=d)


# T-4832: the project's field catalog, read by designer 0.30.0's ref picker. Contract:
# 832 docs/reports/T-1312-field-catalog-contract.md; design: docs/reports/
# T-4832-field-catalog-design.md. PROJECT_ROOT, not FRAMEWORK_ROOT: the catalog is
# project data, named by the project's own config. Unlike /api/lens-definition (500
# for any failure) this route splits absent (404) from malformed (422), as the
# contract asks: the designer hides the picker on 404 and must not on a broken file.
_FIELD_CATALOG_MAX_DEFAULT = 10 * 1024 * 1024


def _project_config(key, default=""):
    """FW_<KEY> env > PROJECT_ROOT/.framework.yaml > default (lib/config.sh order)."""
    import os
    import yaml

    env = os.environ.get(f"FW_{key}")
    if env is not None and env.strip() != "":
        return env.strip()
    try:
        data = yaml.safe_load((PROJECT_ROOT / ".framework.yaml").read_text()) or {}
    except (OSError, yaml.YAMLError):
        data = {}
    v = data.get(key) if isinstance(data, dict) else None
    return default if v is None else str(v).strip()


def load_field_catalog(rel=None, root=None, max_bytes=None):
    """Return (status, payload). 200 -> the catalog dict unchanged; 404/422 -> an
    error string that names the rule broken and never a filesystem path."""
    root = Path(root or PROJECT_ROOT).resolve()
    rel = _project_config("DESIGNER_FIELD_CATALOG") if rel is None else rel
    if not rel:
        return 404, "no field catalog"
    if max_bytes is None:
        try:
            max_bytes = int(_project_config("DESIGNER_FIELD_CATALOG_MAX_BYTES",
                                            str(_FIELD_CATALOG_MAX_DEFAULT)))
        except ValueError:
            max_bytes = _FIELD_CATALOG_MAX_DEFAULT
        if max_bytes < 1:
            max_bytes = _FIELD_CATALOG_MAX_DEFAULT
    p = (root / rel).resolve()  # follows symlinks, so a link out of the root is caught
    if p != root and root not in p.parents:
        return 422, "field catalog path is outside the project root"
    if not p.is_file():
        return 404, "no field catalog"
    try:
        with p.open("rb") as f:
            raw = f.read(max_bytes + 1)
    except OSError:
        return 422, "field catalog unreadable"
    if len(raw) > max_bytes:
        return 422, f"field catalog larger than DESIGNER_FIELD_CATALOG_MAX_BYTES ({max_bytes} bytes)"
    try:
        cat = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return 422, "field catalog is not valid UTF-8 JSON"
    if not isinstance(cat, dict) or type(cat.get("version")) is not int or cat["version"] != 1:
        return 422, "field catalog version must be 1"
    attrs = cat.get("attributes")
    if not isinstance(attrs, list):
        return 422, "field catalog attributes must be an array"
    seen = set()
    for n, row in enumerate(attrs):
        if not isinstance(row, dict):
            return 422, f"field catalog attribute {n} is not an object"
        ref = row.get("ref")
        if not isinstance(ref, str) or not ref.strip():
            return 422, f"field catalog attribute {n} has no ref (non-blank string required)"
        if ref in seen:
            return 422, f"field catalog ref {ref!r} is duplicated (refs must be unique)"
        seen.add(ref)
    return 200, cat


@bp.route("/api/field-catalog")
def field_catalog():
    """GET -> {"ok": true, "catalog": {version:1, attributes:[...]}} (designer 0.30.0).
    404 {ok:false, error:"no field catalog"}; 422 malformed, refused whole. Gzipped
    when the client accepts it (1,300 rows: 309 KB raw, 20 KB gz)."""
    import gzip

    status, payload = load_field_catalog()
    if status != 200:
        return _err(payload, status)
    body = json.dumps({"ok": True, "catalog": payload}, ensure_ascii=False).encode("utf-8")
    resp = Response(body, mimetype="application/json")
    resp.headers["Vary"] = "Accept-Encoding"
    if "gzip" in request.accept_encodings:
        resp.set_data(gzip.compress(body, compresslevel=6))
        resp.headers["Content-Encoding"] = "gzip"
    resp.headers["Cache-Control"] = "no-store"
    return resp


# T-4831 (T-4737 GO, slice 2): GET /api/instances — live tasks on the map.
# 832's contract (T-1300): only a map with state-carrier nodes has instances; AEF
# has exactly one, aef-task-lifecycle (nodes per CLAUDE.md §Task Lifecycle). The
# one status+horizon -> node table below is the single place the mapping lives;
# tools/corpus_overlay.py (T-2629) projects the same states onto badges.
_LIFECYCLE_MAP = "aef-task-lifecycle"
_LIFECYCLE_NODES = {
    ("captured", "now"): "tl_create",
    ("captured", "next"): "tl_create",
    ("captured", "later"): "tl_parked",
    ("started-work", None): "tl_work",
    ("issues", None): "tl_heal",
    ("work-completed", None): "tl_human_review",  # still in active/ = partial-complete
}
_INSTANCE_FM = re.compile(r"^(id|status|horizon|owner):[ \t]*(.*?)[ \t]*$", re.M)


def _lifecycle_node(status, horizon):
    return _LIFECYCLE_NODES.get((status, horizon)) or _LIFECYCLE_NODES.get((status, None))


def _lifecycle_instances():
    """(instances, examined, refusals) for the active tasks under PROJECT_ROOT."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "corpus_overlay", FRAMEWORK_ROOT / "tools" / "corpus_overlay.py")
    overlay = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(overlay)
    present = overlay.carriers(PROJECT_ROOT, _LIFECYCLE_MAP)
    instances, refusals, examined = [], [], 0
    for p in sorted((PROJECT_ROOT / ".tasks" / "active").glob("T-*.md")):
        examined += 1
        try:
            head = re.match(r"^---\n(.*?)\n---", p.read_text(errors="replace"), re.S)
        except OSError as e:
            refusals.append({"task": p.name, "reason": f"unreadable: {e}"})
            continue
        if not head:
            refusals.append({"task": p.name, "reason": "no frontmatter"})
            continue
        fm = {k: v.strip("\"'") for k, v in _INSTANCE_FM.findall(head.group(1))}
        task = fm.get("id") or "-".join(p.name.split("-")[:2])
        status = fm.get("status", "")
        node = _lifecycle_node(status, fm.get("horizon") or "now")
        if node is None:
            state = "NO-POSITION"
        else:
            state = "NODE" if node in present else "STALE"
        instances.append({
            "task": task, "state": state, "node": node,
            "status": status, "owner": fm.get("owner", ""),
        })
    return instances, examined, refusals


@bp.route("/api/instances")
def instances():
    template = request.args.get("template", "")
    if not _valid_id(template):
        return _err("bad template id", 400)
    if _read_meta(template) is None:
        return _err("unknown template", 404)
    insts, examined, refusals = [], 0, []
    if template == _LIFECYCLE_MAP:
        insts, examined, refusals = _lifecycle_instances()
    return jsonify({
        "template": template,
        "generated": int(time.time()),
        "state": "INSTANCES" if insts else "NO-INSTANCES",
        "examined": examined,
        "instances": insts,
        "refusals": refusals,
    })


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
    else:
        # T-4607: a save without a client thumbnail (corpus_spec --save, prove harness)
        # gets one rendered headless, off the request thread. Best-effort.
        designer_thumb.write_version_png_async(d, v, bpmn)
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
        # T-4607: no stored PNG (server-written version, or a map that arrived via
        # git — *.png is gitignored) → pre-rendered fallback, rendered on a miss.
        p = designer_thumb.rendered_fallback(i, vn, store=_STORE,
                                             cache=_STORE.parent / "_rendered")
        if p is None:
            return _err("not found", 404)
    try:
        body, mime = designer_thumb.decode(p.read_text())
    except (ValueError, TypeError):
        return _err("bad thumb", 404)
    return Response(body, mimetype=mime)


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
