"""T-2008 (arc-007 S2a): nav IA regroup + Govern sub-grouping guard.

Pins three things the S2a slice established:
  1. The polymorphic NAV_GROUPS model — a group's items may be leaves
     (label, endpoint, icon) OR subsections (label, [leaves]) — and NAV_ITEMS
     still flattens to *every* leaf (no item lost when a group gains subsections).
  2. The design IA move: Arcs lives under Architecture, not Work (BVP stays in Work).
  3. The named pain point is gone: the Govern group renders as labelled
     subsections in the page DOM, not a flat 16-item list.

Without (1) a future flat→subsection edit could silently drop leaves from search/jump
(NAV_ITEMS). Without (3) a regression to a flat Govern list would pass unnoticed —
exactly the wall S2a removed.
"""
from __future__ import annotations

import pytest

from web.shared import NAV_GROUPS, NAV_ITEMS, nav_group_labels, _nav_flatten


def _is_subsection(item) -> bool:
    return len(item) == 2 and isinstance(item[1], list)


def test_nav_items_flattens_every_leaf():
    """NAV_ITEMS must equal the recursive flatten of every group — no leaf dropped
    when a group carries subsections."""
    expected = []
    for _name, items in NAV_GROUPS:
        expected.extend(_nav_flatten(items))
    assert NAV_ITEMS == expected
    # every leaf is a (label, endpoint, icon) 3-tuple with a non-empty endpoint string
    for leaf in NAV_ITEMS:
        assert len(leaf) == 3, f"leaf not a 3-tuple: {leaf}"
        assert isinstance(leaf[1], str) and leaf[1], f"empty/non-str endpoint: {leaf}"


def test_arcs_moved_to_architecture():
    """Design IA (nav-patterns.jsx): Arcs belongs under Architecture, not Work."""
    assert "Arcs" in nav_group_labels("Architecture")
    assert "Arcs" not in nav_group_labels("Work")
    assert "BVP" in nav_group_labels("Work"), "BVP should stay in Work"


def test_govern_is_subsectioned_not_flat():
    """The 16-item Govern group must carry >=3 labelled subsections (the pain point)."""
    govern = next(items for name, items in NAV_GROUPS if name == "Govern")
    subsections = [it for it in govern if _is_subsection(it)]
    assert len(subsections) >= 3, "Govern must be split into >=3 subsections"
    # and it must NOT contain bare leaves alongside subsections (fully grouped)
    leaves_at_top = [it for it in govern if not _is_subsection(it)]
    assert not leaves_at_top, f"Govern has ungrouped leaves: {leaves_at_top}"


def test_govern_renders_subsection_labels_in_dom(client):
    """Render the page and confirm the Govern dropdown shows subsection labels
    (DOM assertion, not source grep — T-1575). A flat 16-item list would have
    none of these headers."""
    from markupsafe import escape

    html = client.get("/").data.decode()
    govern = next(items for name, items in NAV_GROUPS if name == "Govern")
    sub_labels = [it[0] for it in govern if _is_subsection(it)]
    for label in sub_labels:
        # compare against the HTML-escaped form (Jinja autoescape turns & into &amp;)
        assert str(escape(label)) in html, f"Govern subsection label missing from DOM: {label}"
    # the subsection-label CSS class is actually applied in the rendered nav
    assert "nav-subsection-label" in html


@pytest.fixture
def client():
    from web.app import app

    app.config["TESTING"] = True
    app.config["SECRET_KEY"] = "test-secret-key"
    with app.test_client() as c:
        yield c
