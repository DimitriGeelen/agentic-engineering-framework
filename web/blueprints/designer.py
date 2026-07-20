"""Designer blueprint — serves the pinned Workflow Designer build (T-2521).

832-Workflow-designer is the single source of truth. AEF vendors a RELEASED
single-file build (never source) verified against `policy/designer-pin.yaml` by
`fw designer sync`, and serves it here at `/designer`.

Read-only: this blueprint never writes the vendored artifact. Improvements route
upstream to 832 per docs/aef-designer-integration-protocol.md (832 side).
"""

import time
from pathlib import Path

import yaml
from flask import Blueprint, Response

from web.shared import PROJECT_ROOT, render_page

bp = Blueprint("designer", __name__)

_PIN_FILE = PROJECT_ROOT / "policy" / "designer-pin.yaml"


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


@bp.route("/designer")
def designer():
    pin = _pin()
    vpath = _vendored_path()
    if vpath and vpath.is_file():
        # Serve the vendored single-file build verbatim. It is self-contained
        # (inline CSS/JS); it links Google Fonts CDN with an offline fallback.
        return Response(vpath.read_text(), status=200, mimetype="text/html")
    return _placeholder(pin)
