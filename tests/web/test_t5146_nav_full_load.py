"""T-5146: menu links to pages with their own script library are one direct load.

Boosted, htmx fetched such a page, T-5130's beforeSwap handler then saw a library the
shell had not loaded and loaded the URL a second time (/bvp: 5.2-5.7 s against 2.8 s
direct; independent reviewer on T-5130). NAV_FULL_LOAD_ENDPOINTS marks those links
hx-boost="false". This test renders every menu page, so a page that gains a library
cannot silently go back to two fetches, and a page that loses one is dropped from the set.
"""
import os
import re
from pathlib import Path

os.environ.setdefault("PROJECT_ROOT", str(Path(__file__).resolve().parents[2]))

from flask import url_for  # noqa: E402

from web.app import app  # noqa: E402
from web.shared import NAV_FULL_LOAD_ENDPOINTS, NAV_GROUPS, _nav_flatten  # noqa: E402

SRC = re.compile(r'<script\b[^>]*\bsrc\s*=\s*["\']([^"\']+)["\']', re.I)


def _menu_endpoints():
    return [it[1] for _, items in NAV_GROUPS for it in _nav_flatten(items)]


def test_full_load_set_is_exactly_the_menu_pages_with_their_own_library():
    c = app.test_client()
    shell = set(SRC.findall(c.get("/project").get_data(as_text=True)))
    with app.test_request_context("/"):
        urls = {ep: url_for(ep) for ep in _menu_endpoints()}
    bring_own = set()
    for ep, url in urls.items():
        html = c.get(url, headers={"HX-Request": "true", "HX-Boosted": "true"}).get_data(as_text=True)
        if set(SRC.findall(html)) - shell:
            bring_own.add(ep)
    assert bring_own == set(NAV_FULL_LOAD_ENDPOINTS), (
        f"add to NAV_FULL_LOAD_ENDPOINTS: {sorted(bring_own - NAV_FULL_LOAD_ENDPOINTS)}; "
        f"drop: {sorted(NAV_FULL_LOAD_ENDPOINTS - bring_own)}")


def test_menu_marks_only_those_links_unboosted():
    html = app.test_client().get("/fabric").get_data(as_text=True)
    with app.test_request_context("/"):
        urls = {ep: url_for(ep) for ep in _menu_endpoints()}
    for ep, url in urls.items():
        m = re.search(r'<a href="' + re.escape(url) + r'"[^>]*>', html)
        assert m, (ep, url)
        unboosted = 'hx-boost="false"' in m.group(0)
        assert unboosted == (ep in NAV_FULL_LOAD_ENDPOINTS), (ep, m.group(0))
