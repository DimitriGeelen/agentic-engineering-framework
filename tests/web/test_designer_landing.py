"""T-2589: /designer corpus landing page — server truth first, editor at /designer/app.

Origin: operator recurrence #2 of "off-page connectors not working" — the 0.3.0
bundle's B1 autosave restored a stale local draft on /designer open, shadowing the
server's latest saved corpus content. The landing page makes the entry point show
server truth; cards deep-link /designer/app?load=<version src> which defeats the
autosave restore (differing src → deep-link wins, bundle B1 contract).
"""

import json
import re

import pytest

import web.blueprints.designer_api as designer_api

BPMN = "<?xml version=\"1.0\"?><bpmn:definitions/>"


@pytest.fixture()
def client(monkeypatch, tmp_path):
    store = tmp_path / "projects"
    store.mkdir(parents=True)
    monkeypatch.setattr(designer_api, "_STORE", store)
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client(), store


def _seed_project(store, pid, title, latest=2):
    d = store / pid
    d.mkdir()
    versions = [{"v": v, "note": f"v{v}", "ts": 1784600000 + v} for v in range(1, latest + 1)]
    (d / "meta.json").write_text(json.dumps({
        "id": pid, "title": title, "latest": latest, "versions": versions,
    }))
    for v in range(1, latest + 1):
        (d / f"v{v}.bpmn").write_text(BPMN)


def test_landing_lists_projects_with_deep_links(client):
    c, store = client
    _seed_project(store, "aef-task-lifecycle", "AEF task lifecycle", latest=2)
    _seed_project(store, "aef-dispatch-loop", "AEF dispatch loop", latest=1)

    resp = c.get("/designer/corpus")
    assert resp.status_code == 200
    html = resp.get_data(as_text=True)
    assert "Workflow Designer — Corpus" in html
    assert "aef-task-lifecycle" in html and "AEF task lifecycle" in html
    assert "aef-dispatch-loop" in html
    # Deep-link must target /designer/app with an URL-encoded /api/version src
    # pinned to the latest version — this is what defeats the autosave shadow.
    assert "/designer/app?load=%2Fapi%2Fversion%3Fid%3Daef-task-lifecycle%26v%3D2" in html
    assert "/designer/app?load=%2Fapi%2Fversion%3Fid%3Daef-dispatch-loop%26v%3D1" in html


def test_every_card_shows_its_latest_thumbnail(client):
    """T-4715: the gallery rendered no picture although /api/thumb serves one per map."""
    c, store = client
    _seed_project(store, "aef-task-lifecycle", "AEF task lifecycle", latest=2)
    _seed_project(store, "aef-dispatch-loop", "AEF dispatch loop", latest=1)

    html = c.get("/designer/corpus").get_data(as_text=True)
    assert html.count('class="corpus-card') == html.count('class="corpus-thumb"') == 2
    assert 'src="/api/thumb?id=aef-task-lifecycle&amp;v=2"' in html
    assert 'src="/api/thumb?id=aef-dispatch-loop&amp;v=1"' in html
    # A map without a stored PNG must not leave a broken-image icon.
    assert 'onerror="this.remove()"' in html


def test_landing_falls_back_to_editor_when_store_empty(client):
    c, store = client
    resp = c.get("/designer/corpus")
    # Fresh install: nothing to land on — go to the editor, never an empty landing page.
    assert resp.status_code == 302
    assert resp.headers["Location"].endswith("/designer/app")


def test_designer_entry_redirects_to_the_base_project_browser(client):
    """T-4716: /designer IS the designer's own project browser, not AEF's card list."""
    c, store = client
    _seed_project(store, "aef-task-lifecycle", "AEF task lifecycle")
    resp = c.get("/designer")
    assert resp.status_code == 302
    assert resp.headers["Location"].endswith("/designer/app?browse=1")
    followed = c.get("/designer", follow_redirects=True).get_data(as_text=True)
    assert "Workflow Designer — Corpus" not in followed


def test_boosted_nav_click_gets_full_page_redirect(client):
    """T-4716: an htmx-boosted nav click must not swap the bundle into #content."""
    c, store = client
    resp = c.get("/designer", headers={"HX-Request": "true"})
    assert resp.status_code == 200
    assert resp.headers["HX-Redirect"] == "/designer/app?browse=1"
    assert resp.get_data(as_text=True) == ""


def test_nav_designer_opens_base_and_corpus_has_its_own_entry(client):
    """T-4716: nav "Designer" → base designer; "Designer corpus" → AEF card list."""
    c, store = client
    _seed_project(store, "aef-task-lifecycle", "AEF task lifecycle")
    html = c.get("/designer/corpus").get_data(as_text=True)
    assert re.search(r'href="/designer"[^>]*>\s*Designer\s*<', html)
    assert re.search(r'href="/designer/corpus"[^>]*>\s*Designer corpus\s*<', html)


def test_designer_app_serves_bundle(client):
    c, store = client
    _seed_project(store, "aef-task-lifecycle", "AEF task lifecycle")

    landing = c.get("/designer/corpus").get_data(as_text=True)
    app_page = c.get("/designer/app")
    assert app_page.status_code == 200
    app_html = app_page.get_data(as_text=True)
    # The editor route serves the vendored single-file build (self-contained,
    # carries the autosave key marker), NOT the landing template.
    assert "aefAutosaveDoc" in app_html
    assert "Workflow Designer — Corpus" not in app_html
    assert app_html != landing


def test_ghosts_page_unchanged(client):
    c, store = client
    resp = c.get("/designer/ghosts")
    assert resp.status_code == 200


def test_card_links_mint_clicktime_nonce(client):
    """T-2596: jump-follow poisons the B1 autosave (in-place map switch leaves the
    URL's ?load stale, so the autosave records the JUMPED-TO map under the card's
    src; the next same-src card entry silently restores the wrong diagram). The
    counter is a click-time nonce appended INSIDE the load value so every card
    entry is a distinct src and the deep-link always wins. The onclick must be an
    inline attribute (survives htmx history-cache restore) and must split on any
    prior nonce before appending (idempotent across repeat clicks)."""
    c, store = client
    _seed_project(store, "aef-task-lifecycle", "AEF task lifecycle", latest=2)

    html = c.get("/designer/corpus").get_data(as_text=True)
    # One onclick nonce-minter per corpus card link, targeting the encoded load value.
    n_cards = html.count('class="corpus-open"')
    assert n_cards == 1  # one seeded project → one card link
    # hx-boost="false" is load-bearing: boosted anchors navigate off htmx's cached
    # href and silently discard the onclick mutation (live-verified on :3001).
    assert html.count('hx-boost="false"') >= n_cards
    assert html.count("this.href=this.href.split('%26t%3D')[0]+'%26t%3D'+Date.now()") \
        == n_cards


def test_app_route_mints_nonce_for_nonceless_load(client):
    """T-2599: browser history / bookmarks replay nonce-less ?load URLs forever,
    bypassing the T-2596 landing-card nonce — the server must mint one. A load
    already carrying t= must NOT redirect (F5 of a redirected URL keeps its nonce
    so B1 same-src edit restore still works in-session)."""
    c, store = client
    # Nonce-less load (the operator's replayed-history shape) → 302 with t= inside load
    r = c.get("/designer/app?load=/api/version?id%3Daef-dispatch-loop%26v%3D2")
    assert r.status_code == 302
    assert "load=" in r.headers["Location"] and "t%3D" in r.headers["Location"]
    # Following the redirect serves the bundle (no loop)
    r2 = c.get(r.headers["Location"])
    assert r2.status_code == 200
    assert "aefAutosaveDoc" in r2.get_data(as_text=True)
    # Fully-encoded landing-card shape without nonce also redirects
    r3 = c.get("/designer/app?load=%2Fapi%2Fversion%3Fid%3Daef-task-lifecycle%26v%3D2")
    assert r3.status_code == 302
    # No load param → bundle served directly (B1 last-draft restore by design)
    r4 = c.get("/designer/app")
    assert r4.status_code == 200
