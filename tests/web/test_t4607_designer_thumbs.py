"""T-4607: every listed designer map has a thumbnail.

Origin: operator 2026-10-22 — the Open-project modal showed no map pictures. /api/thumb
served only the `v<N>.png` the designer client sends on save; versions written without
the client (corpus_spec --save, the prove harness) and every map that arrived via git
(`*.png` is gitignored) had none, so every request 404'd to the placeholder.
"""

import json
import shutil

import pytest

import web.blueprints.designer_api as designer_api
from web import designer_thumb

REAL_STORE = designer_api._STORE
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def _renderer_available():
    try:
        import playwright.sync_api  # noqa: F401
    except ImportError:
        return False
    return designer_thumb._artifact() is not None


needs_renderer = pytest.mark.skipif(
    not _renderer_available(),
    reason="headless renderer unavailable (no playwright or no vendored designer artifact)")


def _client(monkeypatch, store):
    monkeypatch.setattr(designer_api, "_STORE", store)
    from web.app import app
    app.config["TESTING"] = True
    return app.test_client()


def _assert_png(resp, what):
    assert resp.status_code == 200, f"{what}: HTTP {resp.status_code}"
    assert resp.mimetype == "image/png", f"{what}: {resp.mimetype}"
    assert resp.data.startswith(PNG_MAGIC), f"{what}: not PNG bytes"


@needs_renderer
def test_thumb_200_for_every_listed_map_without_stored_pngs(monkeypatch, tmp_path):
    """The git-clone state: meta.json + BPMN only, no PNG anywhere."""
    store = tmp_path / "projects"
    for d in sorted(REAL_STORE.iterdir()):
        if not (d / "meta.json").is_file():
            continue
        (store / d.name).mkdir(parents=True)
        for f in [d / "meta.json", *d.glob("v*.bpmn")]:
            shutil.copy(f, store / d.name / f.name)
    c = _client(monkeypatch, store)
    maps = c.get("/api/list").get_json()["maps"]
    assert maps, "no maps listed"
    for m in maps:
        _assert_png(c.get(f"/api/thumb?id={m['id']}"), m["id"])
        _assert_png(c.get(f"/api/thumb?id={m['id']}&v={m['latest']['v']}"), f"{m['id']}@v")
    # served from the fallback cache, the store itself stays untouched by a GET
    assert not list(store.glob("*/v*.png"))
    assert list((tmp_path / "_rendered").glob("*.png"))


@needs_renderer
def test_live_store_every_listed_map_latest_has_thumb(monkeypatch):
    c = _client(monkeypatch, REAL_STORE)
    for m in c.get("/api/list").get_json()["maps"]:
        _assert_png(c.get(f"/api/thumb?id={m['id']}&v={m['latest']['v']}"), m["id"])


@needs_renderer
def test_server_side_save_without_png_writes_version_png(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    threads = []
    real = designer_thumb.write_version_png_async
    monkeypatch.setattr(designer_thumb, "write_version_png_async",
                        lambda *a: threads.append(real(*a)) or threads[-1])
    c = _client(monkeypatch, store)
    src = REAL_STORE / "aef-audit-cron"
    latest = json.loads((src / "meta.json").read_text())["latest"]
    xml = (src / f"v{latest}.bpmn").read_text()
    resp = c.post("/api/save", json={"id": "t4607-server-save", "bpmn": xml})
    assert resp.get_json() == {"ok": True, "v": 1}
    assert threads, "save without png did not start a thumbnail render"
    threads[0].join(timeout=180)
    png = store / "t4607-server-save" / "v1.png"
    assert png.is_file()
    assert png.read_text().startswith("data:image/png;base64,")


def test_client_png_is_stored_verbatim_and_no_render_started(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    called = []
    monkeypatch.setattr(designer_thumb, "write_version_png_async",
                        lambda *a: called.append(a))
    c = _client(monkeypatch, store)
    url = "data:image/png;base64,iVBORw0KGgo="
    c.post("/api/save", json={"id": "t4607-client", "bpmn": "<a/>", "png": url})
    assert (store / "t4607-client" / "v1.png").read_text() == url
    assert not called


def test_thumb_404_when_map_has_no_bpmn(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    (store / "empty").mkdir(parents=True)
    c = _client(monkeypatch, store)
    assert c.get("/api/thumb?id=empty").status_code == 404
