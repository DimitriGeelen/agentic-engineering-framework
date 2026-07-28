"""Designer blueprint — serves the pinned Workflow Designer build (T-2521).

832-Workflow-designer is the single source of truth. AEF vendors a RELEASED
single-file build (never source) verified against `policy/designer-pin.yaml` by
`fw designer sync`, and serves it here at `/designer`.

Read-only: this blueprint never writes the vendored artifact. Improvements route
upstream to 832 per docs/aef-designer-integration-protocol.md (832 side).
"""

import re
import subprocess
import time
from pathlib import Path

import yaml
from flask import Blueprint, Response, redirect, request

from web.shared import FRAMEWORK_ROOT, PROJECT_ROOT, render_page

bp = Blueprint("designer", __name__)

# T-2648 (OBS-097): pin + fw binary are FRAMEWORK-owned (vendored for
# consumers) — PROJECT_ROOT resolution breaks split-root installs.
_PIN_FILE = FRAMEWORK_ROOT / "policy" / "designer-pin.yaml"


def _pin():
    try:
        return yaml.safe_load(_PIN_FILE.read_text()) or {}
    except (OSError, yaml.YAMLError):
        return {}


def _vendored_path():
    rel = _pin().get("vendored_path")
    return (PROJECT_ROOT / rel) if rel else None


def _placeholder(pin):
    """200 page shown until 832 delivers the build and `fw designer sync` installs it."""
    ver = pin.get("version", "?")
    sha = pin.get("sha256", "?")
    return Response(
        f"""<!doctype html><html><head><meta charset="utf-8">
<title>Workflow Designer — not yet synced</title></head>
<body style="font-family:system-ui;max-width:40rem;margin:4rem auto;line-height:1.5">
<h1>Workflow Designer</h1>
<p>The pinned build (<code>v{ver}</code>) is <strong>not yet vendored</strong> in this
AEF instance.</p>
<p>832-Workflow-designer is the source of truth. Once 832 delivers the released
build, run:</p>
<pre>fw designer sync --from &lt;delivered-artifact&gt;</pre>
<p>It verifies the artifact's sha256 against <code>{sha[:16]}…</code> before installing.</p>
</body></html>""",
        status=200,
        mimetype="text/html",
    )


@bp.route("/designer/ghosts")
def designer_ghosts():
    """T-2578 (T-2571 S5): AEF-side ghost visibility with bidirectional markers.

    The /designer gallery itself is 832's pinned bundle (read-only here), so the
    operator-required reference markers render on THIS page, from the same
    registry the /api/list contract serves: ghost cards (who references it, that
    it needs mapping, the minted documentation task, the claim affordance) and
    the reverse per-referrer unmapped-reference counts.
    """
    from web.blueprints.designer_api import _STORE
    from web.designer_registry import load_registry

    reg = load_registry(_STORE)
    ghosts = []
    referrers: dict[str, int] = {}
    for g in reg.get("ghosts") or []:
        refs = g.get("referenced_by") or []
        for r in refs:
            referrers[r["id"]] = referrers.get(r["id"], 0) + 1
        ghosts.append({
            **g,
            "short_uuid": (g.get("uuid") or "")[:8],
            "first_seen_h": time.strftime(
                "%Y-%m-%d %H:%M", time.localtime(g.get("first_seen") or 0)
            ),
        })
    claims = list(reversed(reg.get("claims") or []))[:10]
    for c in claims:
        c["ts_h"] = time.strftime("%Y-%m-%d %H:%M", time.localtime(c.get("ts") or 0))
    return render_page(
        "designer_ghosts.html",
        page_title="Designer — Pending References",
        ghosts=ghosts,
        referrers=sorted(referrers.items()),
        claims=claims,
    )


def _serve_bundle():
    pin = _pin()
    vpath = _vendored_path()
    if vpath and vpath.is_file():
        # Serve the vendored single-file build verbatim. It is self-contained
        # (inline CSS/JS); it links Google Fonts CDN with an offline fallback.
        return Response(vpath.read_text(), status=200, mimetype="text/html")
    return _placeholder(pin)


@bp.route("/designer/app")
def designer_app():
    """T-2589: the editor itself (vendored 0.3.0 bundle), moved off the entry URL.

    The bundle's B1 autosave silently restores the browser's last local draft on
    open — an operator following /designer saw a stale copy of a corpus diagram
    (same title, no off-page handoff nodes) and read the seam as broken (operator
    recurrence #2, 2026-07-21). Accepts the bundle's own ?load=<same-origin path>
    deep-link; a src that differs from the stored autosave src wins over the
    restore (bundle B1 contract), which is what the landing cards exploit.

    T-2599: any ?load WITHOUT a t= nonce is 302-redirected to the same URL with
    a ms-timestamp nonce minted INSIDE the load value. The in-editor handoff
    jump switches maps in-place without updating ?load, so post-jump autosaves
    record the jumped-to map under the entry URL's src — and B1's same-src
    restore then silently renders the WRONG map on the next visit through that
    URL (T-2596). The T-2596 click-time nonce only covers the landing cards'
    current markup; browser history / bookmarks / cached pages replay nonce-less
    URLs forever (operator recurrence #4, access-log evidence 2026-07-22
    08:18:58). Minting server-side closes every entry path. A redirected URL
    keeps its nonce, so F5 / same-session reload still restores in-progress
    edits (B1 same-src contract intact); only NEW arrivals get a fresh nonce.
    """
    import re
    from urllib.parse import quote as _q

    from flask import redirect, request

    load = request.args.get("load")
    if load and not re.search(r"[?&]t=", load):
        sep = "&" if "?" in load else "?"
        nonce = str(int(time.time() * 1000))
        return redirect(
            "/designer/app?load=" + _q(f"{load}{sep}t={nonce}", safe=""), code=302
        )
    return _serve_bundle()


@bp.route("/designer")
def designer():
    """T-2589: corpus landing page — server truth first, editor one click away.

    Lists every saved project from the same store /api/list reads, each card
    deep-linking /designer/app?load=/api/version?id=<id>&v=<latest> so the editor
    opens the SERVER-LATEST version instead of whatever the browser last had.
    Falls back to the bundle directly when the store has no projects yet (fresh
    install — nothing to land on).
    """
    from urllib.parse import quote

    import web.blueprints.designer_api as designer_api

    store = designer_api._STORE
    try:
        overlay_ids = set(_overlay_module().PROFILES)
    except Exception:
        overlay_ids = set()
    projects = []
    if store.is_dir():
        for d in sorted(store.iterdir()):
            if not d.is_dir():
                continue
            m = designer_api._read_meta(d.name)
            if not m:
                continue
            latest_v = int(m.get("latest", 0))
            if latest_v < 1:
                continue
            vlist = m.get("versions", [])
            latest_entry = next((x for x in vlist if x.get("v") == latest_v), None)
            latest_ts = int(
                latest_entry["ts"]
                if latest_entry and "ts" in latest_entry
                else m.get("updated", 0)
            )
            src = f"/api/version?id={m['id']}&v={latest_v}"
            projects.append({
                "id": m["id"],
                "title": m.get("title", m["id"]),
                "latest_v": latest_v,
                "version_count": len(vlist),
                "saved_h": time.strftime("%Y-%m-%d %H:%M", time.localtime(latest_ts)),
                "open_url": "/designer/app?load=" + quote(src, safe=""),
                # T-2623 draft mode: id prefix is the draft convention.
                "is_draft": m["id"].startswith("draft-"),
                # T-2630: live-overlay wrapper exists only for profiled maps.
                "has_overlay": m["id"] in overlay_ids,
            })
    if not projects:
        return _serve_bundle()
    ghost_count = 0
    try:
        from web.designer_registry import load_registry
        ghost_count = len(load_registry(store).get("ghosts") or [])
    except Exception:
        pass
    return render_page(
        "designer_landing.html",
        page_title="Workflow Designer — Corpus",
        projects=projects,
        ghost_count=ghost_count,
    )


def _overlay_module():
    """Load tools/corpus_overlay.py from the CODE tree (this file's repo).

    Data always comes from PROJECT_ROOT — the two differ under test
    monkeypatching and in vendored consumers.
    """
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "corpus_overlay",
        Path(__file__).resolve().parents[2] / "tools" / "corpus_overlay.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _known_map_or_none(map_id):
    """Shared id guard for the overlay surfaces: syntax + store existence."""
    store_dir = PROJECT_ROOT / ".context/designer/projects" / map_id
    if not re.fullmatch(r"[a-z0-9-]{1,64}", map_id or ""):
        return None
    return map_id if (store_dir / "meta.json").is_file() else None


@bp.route("/api/overlay")
def api_overlay():
    """T-2629 (T-2620 GO, Slice A): wire-ready aef:annotate payload for a map.

    AEF-side extension — NOT part of 832's designer client contract (T-2530);
    the Slice B wrapper forwards this verbatim via postMessage on every
    aef:ready (rail-197 re-ready/re-annotate contract). Projection rules live
    in tools/corpus_overlay.py, in exactly one place (T-2620 IW-4).
    """
    map_id = _known_map_or_none(request.args.get("id", ""))
    if not map_id:
        return Response('{"error":"not found","ok":false}', status=404,
                        mimetype="application/json")
    import json as _json
    return Response(_json.dumps(_overlay_module().build_payload(PROJECT_ROOT, map_id)),
                    status=200, mimetype="application/json")


@bp.route("/designer/overlay")
def designer_overlay():
    """T-2630 (T-2620 GO, Slice B): live-overlay wrapper page.

    Iframes the editor at server-latest (/designer/app?load=/api/version?id=…,
    T-2599 nonce flow untouched — the app route 302-mints it) and forwards the
    Slice A payload verbatim via postMessage on EVERY aef:ready, per 832's
    ratified T-250 contract (rail 216: re-ready after every render, aef:annotate
    keyed by uid, unknown uids ignored). Until the pinned bundle ships aef:ready
    (832 T-258, next release cut), the listener never fires — documented no-op;
    both halves land independently and the seam lights up on re-pin.
    """
    from urllib.parse import quote as _q

    from flask import render_template

    map_id = _known_map_or_none(request.args.get("id", ""))
    if not map_id:
        return Response("unknown map", status=404, mimetype="text/plain")
    editor_url = "/designer/app?load=" + _q(f"/api/version?id={map_id}", safe="")
    return render_template(
        "designer_overlay.html", map_id=map_id, editor_url=editor_url)


@bp.route("/designer/draft/new", methods=["POST"])
def designer_draft_new():
    """T-2623: gallery entry point for a pair-draft session.

    Thin wrapper over the CLI (`fw designer draft new <name>`) so seeding logic
    has exactly one implementation; on success redirects straight into the
    editor at the seeded v1.
    """
    name = (request.form.get("name") or "").strip()
    if not re.fullmatch(r"[A-Za-z0-9 _-]{1,48}", name):
        return Response("draft name: 1-48 chars, letters/digits/space/dash only",
                        status=400, mimetype="text/plain")
    r = subprocess.run(
        [str(FRAMEWORK_ROOT / "bin" / "fw"), "designer", "draft", "new", name],
        capture_output=True, text=True, timeout=60, cwd=str(PROJECT_ROOT),
    )
    # mirror the CLI's tr 'A-Z _' 'a-z--' normalization
    slug = "draft-" + name.removeprefix("draft-").lower().replace(" ", "-").replace("_", "-")
    link = f"/designer/app?load=%2Fapi%2Fversion%3Fid%3D{slug}%26v%3D1"
    if r.returncode != 0:
        detail = (r.stderr or r.stdout or "").strip()[-500:]
        return Response(f"draft creation failed:\n{detail}",
                        status=409 if "already exists" in detail else 500,
                        mimetype="text/plain")
    return redirect(link)
