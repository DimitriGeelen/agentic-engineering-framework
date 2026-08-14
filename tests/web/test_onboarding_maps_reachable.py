"""T-2981: the onboarding maps stay reachable from the UI the seeds send operators to.

The seeded curriculum makes two promises about where to find these diagrams. One is
``fw corpus explain <id>`` — guarded by T-2980's audit check. The other is Watchtower
``/designer`` ("every map at once", ``existing-project/T-006``), and nothing guarded that
until now: T-2979 added a map to the store with no check that the landing page picked it up.

The test follows the link the page actually emits rather than a URL written here. That
distinction is the whole point. ``/designer/<id>`` is not a route — the editor lives at
``/designer/app?load=<encoded api path>`` (T-2589, with a T-2599 nonce redirect on top) —
so a hardcoded URL in a test would encode one snapshot of a scheme that has already moved
twice. Extracting the href and fetching it means the test tracks the scheme instead of
pinning it, and still fails if the map stops being served.

Both onboarding paths are covered. The asymmetry T-2979 closed (greenfield had a map,
existing-project did not) reopens the moment either one drops off this page.
"""

import re
import urllib.parse

import pytest

MAPS = ["aef-greenfield-onboarding", "aef-existing-project-onboarding"]


@pytest.fixture()
def client():
    from web.app import app

    app.config["TESTING"] = True
    return app.test_client()


def _landing(client):
    resp = client.get("/designer")
    assert resp.status_code == 200, f"/designer returned {resp.status_code}"
    return resp.get_data(as_text=True)


@pytest.mark.parametrize("map_id", MAPS)
def test_map_is_listed_on_the_designer_landing_page(client, map_id):
    """`/designer` is what existing-project/T-006 tells the operator to open."""
    assert map_id in _landing(client), (
        f"{map_id} is not on /designer. The seeds send operators here for 'every map at "
        f"once'; a map in the store but not on this page is a promise the curriculum "
        f"makes and the UI does not keep."
    )


@pytest.mark.parametrize("map_id", MAPS)
def test_landing_page_link_actually_serves_the_map(client, map_id):
    """Follow the emitted href rather than a URL hardcoded here — see module docstring."""
    html = _landing(client)
    hrefs = re.findall(r'href="(/designer/app\?load=[^"]+)"', html)
    target = [h for h in hrefs if map_id in urllib.parse.unquote(h)]
    assert target, (
        f"no /designer/app?load= link for {map_id} on the landing page — it may be listed "
        f"as text while being unopenable"
    )

    # The href carries the API path the editor will fetch, percent-encoded once.
    load = urllib.parse.parse_qs(urllib.parse.urlparse(target[0]).query)["load"][0]
    resp = client.get(load)
    assert resp.status_code == 200, (
        f"the link /designer offers for {map_id} resolves to {load}, which returned "
        f"{resp.status_code} — the card is on the page but opening it fails"
    )
    body = resp.get_data(as_text=True)
    assert "bpmn:definitions" in body, f"{load} served something that is not BPMN"
    assert map_id in body, (
        f"{load} served BPMN that does not mention {map_id} — the link may be pointing at "
        f"the wrong map, which renders successfully and is therefore invisible"
    )


@pytest.mark.parametrize("map_id", MAPS)
def test_map_is_served_by_bare_id_too(client, map_id):
    """`/api/version?id=` with no v resolves latest (T-2624) — the form deep links use."""
    resp = client.get(f"/api/version?id={map_id}")
    assert resp.status_code == 200
    assert "bpmn:definitions" in resp.get_data(as_text=True)
