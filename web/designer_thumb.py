"""Server-side designer map thumbnails (T-4607).

The designer client renders a thumbnail on save (`captureThumbnail()` in the pinned
832 build) and sends it as a `data:image/png;base64,` URL, which /api/save stores
as `v<N>.png`. Versions written WITHOUT the client — `corpus_spec generate --save`,
the `prove` harness, a map that arrived through git (`*.png` is gitignored) — had
no PNG, so /api/thumb 404'd and the Open-project / Versions modals showed only the
placeholder.

This module renders the same thumbnail headless: it loads the pinned designer
artifact in Playwright chromium, adopts the BPMN XML, and calls the artifact's own
`captureThumbnail()`. Same code path as the client, so the picture matches what an
operator save would have stored. Best-effort throughout: no Playwright, no
vendored artifact, or a render failure returns None and the caller degrades to
today's placeholder.

CLI:  python3 -m web.designer_thumb backfill   # v<latest>.png for every map lacking one
"""

import base64
import json
import sys
import threading
from pathlib import Path

from web.shared import PROJECT_ROOT

STORE = PROJECT_ROOT / ".context" / "designer" / "projects"
# Fallback cache for /api/thumb renders. Outside STORE on purpose: every reader of
# the store iterates its directories as map ids.
RENDERED = PROJECT_ROOT / ".context" / "designer" / "_rendered"

_LOCK = threading.Lock()  # one chromium at a time; the modal requests thumbs in bursts

_JS = """async (x) => {
  if (!parseBpmnXml(x)) return null;
  adoptImportedXml(x);
  await new Promise(r => requestAnimationFrame(() => r()));
  return await captureThumbnail();
}"""


def _artifact():
    from web.blueprints.designer import _vendored_path
    p = _vendored_path()
    return p if p and p.is_file() else None


def render_many(xmls):
    """Render each BPMN XML string to a PNG data URL (None per failure), one browser."""
    out: list = [None] * len(xmls)
    html = _artifact()
    if html is None or not xmls:
        return out
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        return out
    with _LOCK:
        try:
            with sync_playwright() as p:
                b = p.chromium.launch()
                try:
                    for n, xml in enumerate(xmls):
                        pg = b.new_page(viewport={"width": 1400, "height": 900})
                        try:
                            pg.on("dialog", lambda d: d.dismiss())
                            pg.goto(html.as_uri(), timeout=60000)
                            pg.wait_for_function(
                                "typeof adoptImportedXml === 'function' && "
                                "typeof captureThumbnail === 'function'", timeout=30000)
                            url = pg.evaluate(_JS, xml)
                            if isinstance(url, str) and url.startswith("data:image/png;base64,"):
                                out[n] = url
                        except Exception as e:
                            print(f"designer-thumb: render failed: {e}", file=sys.stderr)
                        finally:
                            pg.close()
                finally:
                    b.close()
        except Exception as e:
            print(f"designer-thumb: chromium unavailable: {e}", file=sys.stderr)
    return out


def render_png(xml):
    return render_many([xml])[0]


def write_version_png(map_dir, v, xml):
    """Writer hook: store `v<N>.png` beside `v<N>.bpmn` (same data-URL shape as the client)."""
    url = render_png(xml)
    if url:
        try:
            (Path(map_dir) / f"v{v}.png").write_text(url)
        except OSError:
            return False
    return bool(url)


def write_version_png_async(map_dir, v, xml):
    t = threading.Thread(target=write_version_png, args=(map_dir, v, xml), daemon=True)
    t.start()
    return t


def rendered_fallback(map_id, v, store=None, cache=None):
    """Path to a pre-rendered PNG data URL for map_id@v, rendering into the cache on a miss.

    v=0 means the map has no saved version number to name: the newest BPMN on disk is used.
    """
    store = Path(store or STORE)
    cache = Path(cache or RENDERED)
    d = store / map_id
    if v:
        src = d / f"v{v}.bpmn"
    else:
        vs = sorted((int(f.stem[1:]) for f in d.glob("v*.bpmn") if f.stem[1:].isdigit()),
                    reverse=True)
        src = d / f"v{vs[0]}.bpmn" if vs else None
    if src is None or not src.is_file():
        return None
    out = cache / f"{map_id}.{src.stem}.png"
    if out.is_file() and out.stat().st_mtime >= src.stat().st_mtime:
        return out
    url = render_png(src.read_text())
    if not url:
        return None
    cache.mkdir(parents=True, exist_ok=True)
    out.write_text(url)
    return out


def backfill(store=None):
    """Write v<latest>.png for every map whose latest version has none. Returns (written, failed)."""
    store = Path(store or STORE)
    todo = []
    for d in sorted(store.iterdir()) if store.is_dir() else []:
        try:
            latest = int(json.loads((d / "meta.json").read_text()).get("latest", 0))
        except (OSError, ValueError):
            continue
        if latest >= 1 and (d / f"v{latest}.bpmn").is_file() and not (d / f"v{latest}.png").is_file():
            todo.append((d, latest))
    urls = render_many([(d / f"v{v}.bpmn").read_text() for d, v in todo])
    written, failed = [], []
    for (d, v), url in zip(todo, urls):
        if url:
            (d / f"v{v}.png").write_text(url)
            written.append(f"{d.name}@v{v}")
        else:
            failed.append(f"{d.name}@v{v}")
    return written, failed


def decode(raw):
    """data-URL text → (bytes, mime); anything else is returned as raw PNG bytes."""
    if raw.startswith("data:"):
        header, _, b64 = raw.partition(",")
        return base64.b64decode(b64), (header[5:].split(";")[0] or "image/png")
    return raw.encode(), "image/png"


if __name__ == "__main__":
    if sys.argv[1:] != ["backfill"]:
        sys.exit("usage: python3 -m web.designer_thumb backfill")
    w, f = backfill()
    for x in w:
        print(f"wrote {x}")
    for x in f:
        print(f"FAILED {x}", file=sys.stderr)
    sys.exit(1 if f else 0)
