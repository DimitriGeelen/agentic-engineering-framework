"""T-2009 (arc-007 S2b): path-derived breadcrumb guard.

`nav_breadcrumb(endpoint, path)` derives the trail from the URL's first path
segment matched against nav-leaf URLs. Pins:
  - list page  → Group › Section (section is current, unlinked)
  - detail page → Group › Section(link) › detail (detail current, unlinked)
  - mixed-blueprint page (/gaps lives in the `discovery` blueprint but the Govern
    nav group) resolves to Govern, NOT Knowledge — the reason we derive by URL path
    not blueprint name.
  - home and off-nav pages → [] (silent rather than misleading).
"""
from __future__ import annotations

import pytest

from web.app import app
from web.shared import nav_breadcrumb


@pytest.fixture
def ctx():
    with app.test_request_context("/"):
        yield


def _labels(crumbs):
    return [label for label, _url in crumbs]


def test_home_has_no_breadcrumb(ctx):
    assert nav_breadcrumb(None, "/") == []


def test_list_page_two_levels(ctx):
    crumbs = nav_breadcrumb(None, "/tasks")
    assert _labels(crumbs) == ["Work", "Tasks"]
    # last crumb (current page) is unlinked
    assert crumbs[-1][1] is None


def test_detail_page_three_levels_with_linked_section(ctx):
    crumbs = nav_breadcrumb(None, "/tasks/T-2008")
    assert _labels(crumbs) == ["Work", "Tasks", "T-2008"]
    # the section crumb links to its list; the detail crumb is current/unlinked
    section = crumbs[1]
    assert section[0] == "Tasks" and section[1] == "/tasks"
    assert crumbs[-1][1] is None


def test_nested_arc_detail(ctx):
    # T-2034: Arcs lives under Work (was Architecture under T-2008).
    crumbs = nav_breadcrumb(None, "/arcs/arc-007")
    assert _labels(crumbs) == ["Work", "Arcs", "arc-007"]
    assert crumbs[1][1] == "/arcs"


def test_mixed_blueprint_resolves_by_path_not_blueprint(ctx):
    """/gaps is served by the `discovery` blueprint (which also serves Knowledge
    pages) but belongs to the Govern nav group. Path-based derivation must say
    Govern — a blueprint-name heuristic would wrongly say Knowledge."""
    crumbs = nav_breadcrumb(None, "/gaps")
    assert _labels(crumbs) == ["Govern", "Gaps"]


def test_off_nav_page_is_silent(ctx):
    # settings + review pages aren't in the main nav → no (misleading) breadcrumb
    assert nav_breadcrumb(None, "/settings/appearance") == []
    assert nav_breadcrumb(None, "/review/T-2008") == []
