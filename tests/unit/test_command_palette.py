"""T-2012 (arc-007 S6a): command-palette jump-list contract (server side).

The palette is mostly client-side JS, but two server-side guarantees are unit-
testable and load-bearing:
  1. The jump list is EXACTLY the nav whitelist (web.shared.NAV_ITEMS) resolved
     to URLs — no destination outside the nav whitelist can ever be jumped to.
     One source of truth, same list S2c pins use (T-2010).
  2. The palette markup + the nav-items JSON payload are injected into every page
     via base.html (the shell), so ⌘K works regardless of which #content loaded.

The keyboard flow, fuzzy ranking, and the /search fall-through routing are proven
end-to-end in tests/playwright/test_command_palette.py (they need a real browser).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from web import shared as S


def _labels(items):
    return sorted(leaf[0] for leaf in items)


# ── 1. Jump list == NAV_ITEMS whitelist ─────────────────────────────────────
def test_palette_jump_list_is_nav_items():
    from web.app import app

    with app.test_request_context("/"):
        dests = S.palette_destinations()
    # one entry per nav leaf, same labels — no destination outside the whitelist
    assert _labels([(d["label"],) for d in dests]) == _labels(S.NAV_ITEMS)
    # every destination resolves to an in-app path and carries its group
    for d in dests:
        assert d["url"].startswith("/"), f"{d['label']} url not app-relative: {d['url']}"
        assert d["group"], f"{d['label']} missing group"


def test_palette_destinations_nonempty():
    from web.app import app

    with app.test_request_context("/"):
        assert len(S.palette_destinations()) > 5


# ── 2. Injected into the shell on every page ─────────────────────────────────
def test_palette_present_on_arbitrary_page():
    from web.app import app

    c = app.test_client()
    html = c.get("/tasks").get_data(as_text=True)
    assert 'id="wt-command-palette"' in html       # the modal root
    assert 'id="wt-palette-input"' in html          # the single input
    assert 'id="wt-nav-items"' in html              # the JSON jump payload
    assert "command-palette.js" in html             # the logic is wired in


def test_nav_items_json_payload_parses_and_matches_whitelist():
    from web.app import app

    c = app.test_client()
    html = c.get("/tasks").get_data(as_text=True)
    # extract the JSON between the script tag's > and </script>
    start = html.index('id="wt-nav-items">') + len('id="wt-nav-items">')
    end = html.index("</script>", start)
    payload = json.loads(html[start:end])
    assert len(payload) > 5
    assert sorted(d["label"] for d in payload) == _labels(S.NAV_ITEMS)
    for d in payload:
        assert d["url"].startswith("/")


# ── 3. The nav-search affordance opens the palette (no /search navigation) ───
def test_nav_search_affordance_marked_as_palette_opener():
    from web.app import app

    c = app.test_client()
    html = c.get("/tasks").get_data(as_text=True)
    # the magnifier link carries data-palette-open and no longer hx-targets #content
    nav_search_idx = html.index('class="nav-search"')
    snippet = html[nav_search_idx:nav_search_idx + 400]
    assert "data-palette-open" in snippet
    assert "hx-target" not in snippet  # click opens the palette, not an htmx nav
