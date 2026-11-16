"""T-1960: /arcs/<slug>/close — Agent Recommendation panel renders above form.

The panel reads the arc's anchor-task `## Recommendation` block and surfaces
verdict / rationale / evidence inline, so the human's close decision starts
from the agent's advisory rather than a blank form.

DOM-content + behavioural assertions per T-1575 (not bare element grep).
"""

from playwright.sync_api import expect

# T-5168: these tests run against the fixture project (tests/fixtures/arc-close-panel,
# served by conftest's `arc_fixture_server`), not the live corpus. The panel needs an
# open arc whose close-out or anchor task holds a CLOSE or KEEP-OPEN recommendation
# (since T-4320 an anchor's GO / NO-GO / DEFER is not shown as one). The live corpus
# often has no such arc, and the tests then skipped. `close_rec_arc` is that arc.


def test_arc_close_renders_recommendation_panel(fixture_page, arc_fixture_url, close_rec_arc):
    """An open arc with a close recommendation must render the .anchor-rec
    panel on its /close page."""
    page, base_url, arc = fixture_page, arc_fixture_url, close_rec_arc
    page.goto(f"{base_url}/arcs/{arc.slug}/close", wait_until="domcontentloaded")
    panel = page.locator(".anchor-rec")
    assert panel.count() == 1, "expected exactly one .anchor-rec panel"
    expect(panel).to_be_visible()


def test_arc_close_panel_verdict_badge_present(fixture_page, arc_fixture_url, close_rec_arc):
    """Panel must display a verdict badge with one of the canonical verdicts."""
    page, base_url, arc = fixture_page, arc_fixture_url, close_rec_arc
    page.goto(f"{base_url}/arcs/{arc.slug}/close", wait_until="domcontentloaded")
    badge = page.locator(".anchor-rec .verdict-badge").first
    text = (badge.text_content() or "").strip()
    assert text == arc.close_rec_verdict, (
        f"verdict badge shows {text!r}; {arc.close_rec_task} recommends "
        f"{arc.close_rec_verdict!r}"
    )


def test_arc_close_panel_links_to_anchor_task(fixture_page, arc_fixture_url, close_rec_arc):
    """Panel must hyperlink the task the recommendation was read from."""
    page, base_url, arc = fixture_page, arc_fixture_url, close_rec_arc
    page.goto(f"{base_url}/arcs/{arc.slug}/close", wait_until="domcontentloaded")
    anchor_link = page.locator(f'.anchor-rec a[href="/tasks/{arc.close_rec_task}"]').first
    expect(anchor_link).to_be_visible()


def test_arc_close_panel_renders_rationale(fixture_page, arc_fixture_url, close_rec_arc):
    """The panel must render the recommendation's rationale as readable content."""
    page, base_url, arc = fixture_page, arc_fixture_url, close_rec_arc
    page.goto(f"{base_url}/arcs/{arc.slug}/close", wait_until="domcontentloaded")
    rationale_block = page.locator(".anchor-rec .rec-body").first
    text = (rationale_block.text_content() or "").strip()
    # Rationale should be substantive (> 50 chars), not empty/placeholder.
    assert len(text) > 50, f"expected substantive rationale text, got len={len(text)}"


def test_arc_close_panel_positioned_above_form(fixture_page, arc_fixture_url, close_rec_arc):
    """Panel must precede the close form in the DOM (so human reads it first)."""
    page, base_url, arc = fixture_page, arc_fixture_url, close_rec_arc
    page.goto(f"{base_url}/arcs/{arc.slug}/close", wait_until="domcontentloaded")
    panel_box = page.locator(".anchor-rec").bounding_box()
    form_box = page.locator('form[action$="/close"]').bounding_box()
    assert panel_box is not None and form_box is not None, "both elements must be in viewport"
    assert panel_box["y"] < form_box["y"], (
        f"panel (y={panel_box['y']}) should appear above form (y={form_box['y']})"
    )
