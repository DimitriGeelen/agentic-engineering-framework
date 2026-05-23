"""T-2013 (arc-007 S6b): keyboard-shortcuts overlay — server-side presence.

The overlay is static markup + client-side JS, but one server-side guarantee is
unit-testable: the overlay (and every documented shortcut row) is injected into
EVERY page via base.html (the shell), so `?` works regardless of which #content
page is loaded. The keyboard flow (open on `?`, input-focus guard, mutual
exclusion with the ⌘K palette) is proven end-to-end in
tests/playwright/test_shortcuts_overlay.py (needs a real browser).
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


def test_overlay_present_on_arbitrary_page():
    from web.app import app

    c = app.test_client()
    html = c.get("/tasks").get_data(as_text=True)
    assert 'id="wt-shortcuts-overlay"' in html   # the overlay root
    assert "shortcuts-overlay.js" in html         # the logic is wired in


def test_overlay_lists_every_documented_shortcut():
    from web.app import app

    c = app.test_client()
    html = c.get("/tasks").get_data(as_text=True)
    # each live shortcut's description must be in the rendered cheat-sheet
    for needle in (
        "Open command palette",
        "Show this shortcuts overlay",
        "Close the palette or this overlay",
        "Move the highlighted result",
        "Jump to / open the highlighted result",
    ):
        assert needle in html, f"shortcut row missing: {needle!r}"


def test_overlay_is_hidden_by_default():
    from web.app import app

    c = app.test_client()
    html = c.get("/tasks").get_data(as_text=True)
    # the overlay ships hidden — opened only by the `?` key
    idx = html.index('id="wt-shortcuts-overlay"')
    snippet = html[idx:idx + 200]
    assert "hidden" in snippet
