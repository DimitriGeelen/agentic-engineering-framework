"""T-2349 (T-2347a slice A1): arc detail page leads with a Close-arc button;
CLI moves into a collapsed fallback.

Contract (T-971 rule):
  1. A non-closed arc's detail page shows a `.close-arc-button` anchor whose
     href is `/arcs/<slug>/close`, and the `fw arc close` CLI block sits inside
     a `<details class="close-arc-cli-fallback">` (collapsed by default).
  2. A closed arc renders neither the button nor the CLI fallback.

Uses a temporary fixture arc YAML dropped into `.context/arcs/` — the blueprint
reads arc YAMLs from disk at request time.
"""
import pathlib

import pytest


PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[2]
ARCS_DIR = PROJECT_ROOT / ".context" / "arcs"

OPEN_SLUG = "t2349-fixture-open"
CLOSED_SLUG = "t2349-fixture-closed"

OPEN_ARC = """id: arc-990
name: T-2349 open fixture arc
status: in-progress
headline_mechanic: operator clicks Close-arc button and observes the guided close form
anchor_task: T-2349
created: 2026-07-05T00:00:00Z
"""

CLOSED_ARC = """id: arc-991
name: T-2349 closed fixture arc
status: closed
headline_mechanic: operator observes a closed arc renders no close affordances
anchor_task: T-2349
decision: success — fixture
closed_at: 2026-07-05T00:00:00Z
created: 2026-07-05T00:00:00Z
"""


@pytest.fixture
def open_arc():
    p = ARCS_DIR / f"{OPEN_SLUG}.yaml"
    p.write_text(OPEN_ARC)
    yield OPEN_SLUG
    try:
        p.unlink()
    except FileNotFoundError:
        pass


@pytest.fixture
def closed_arc():
    p = ARCS_DIR / f"{CLOSED_SLUG}.yaml"
    p.write_text(CLOSED_ARC)
    yield CLOSED_SLUG
    try:
        p.unlink()
    except FileNotFoundError:
        pass


def test_open_arc_shows_close_button_and_collapsed_cli(page, open_arc):
    from tests.playwright.conftest import TEST_URL

    resp = page.goto(f"{TEST_URL}/arcs/{open_arc}", wait_until="domcontentloaded")
    assert resp.status == 200

    btn = page.locator(".close-arc-button")
    assert btn.count() == 1, "Close-arc button missing on non-closed arc"
    assert btn.get_attribute("href") == f"/arcs/{open_arc}/close"

    fallback = page.locator("details.close-arc-cli-fallback")
    assert fallback.count() == 1, "CLI fallback details missing"
    assert fallback.get_attribute("open") is None, "CLI fallback must be collapsed by default"
    assert "fw arc close" in page.content()


def test_closed_arc_renders_no_close_affordances(page, closed_arc):
    from tests.playwright.conftest import TEST_URL

    resp = page.goto(f"{TEST_URL}/arcs/{closed_arc}", wait_until="domcontentloaded")
    assert resp.status == 200
    assert page.locator(".close-arc-button").count() == 0
    assert page.locator("details.close-arc-cli-fallback").count() == 0
