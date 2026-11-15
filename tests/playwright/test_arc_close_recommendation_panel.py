"""T-1960: /arcs/<slug>/close — Agent Recommendation panel renders above form.

The panel reads the arc's anchor-task `## Recommendation` block and surfaces
verdict / rationale / evidence inline, so the human's close decision starts
from the agent's advisory rather than a blank form.

DOM-content + behavioural assertions per T-1575 (not bare element grep).
"""

from playwright.sync_api import expect

from tests.playwright.arc_corpus import pick_arc


def _arc_with_close_recommendation():
    """T-5160: an open arc whose close-out or anchor task holds a CLOSE or
    KEEP-OPEN recommendation. Since T-4320 an anchor's GO / NO-GO / DEFER is not
    shown as a close recommendation, so an arc with only that has no panel."""
    return pick_arc("in-progress", close_recommendation=True)


def test_arc_close_renders_recommendation_panel(page, base_url):
    """An open arc with a close recommendation must render the .anchor-rec
    panel on its /close page."""
    arc = _arc_with_close_recommendation()
    page.goto(f"{base_url}/arcs/{arc.slug}/close", wait_until="domcontentloaded")
    panel = page.locator(".anchor-rec")
    assert panel.count() == 1, "expected exactly one .anchor-rec panel"
    expect(panel).to_be_visible()


def test_arc_close_panel_verdict_badge_present(page, base_url):
    """Panel must display a verdict badge with one of the canonical verdicts."""
    arc = _arc_with_close_recommendation()
    page.goto(f"{base_url}/arcs/{arc.slug}/close", wait_until="domcontentloaded")
    badge = page.locator(".anchor-rec .verdict-badge").first
    text = (badge.text_content() or "").strip()
    assert text == arc.close_rec_verdict, (
        f"verdict badge shows {text!r}; {arc.close_rec_task} recommends "
        f"{arc.close_rec_verdict!r}"
    )


def test_arc_close_panel_links_to_anchor_task(page, base_url):
    """Panel must hyperlink the task the recommendation was read from."""
    arc = _arc_with_close_recommendation()
    page.goto(f"{base_url}/arcs/{arc.slug}/close", wait_until="domcontentloaded")
    anchor_link = page.locator(f'.anchor-rec a[href="/tasks/{arc.close_rec_task}"]').first
    expect(anchor_link).to_be_visible()


def test_arc_close_panel_renders_rationale(page, base_url):
    """The panel must render the recommendation's rationale as readable content."""
    arc = _arc_with_close_recommendation()
    page.goto(f"{base_url}/arcs/{arc.slug}/close", wait_until="domcontentloaded")
    rationale_block = page.locator(".anchor-rec .rec-body").first
    text = (rationale_block.text_content() or "").strip()
    # Rationale should be substantive (> 50 chars), not empty/placeholder.
    assert len(text) > 50, f"expected substantive rationale text, got len={len(text)}"


def test_arc_close_panel_positioned_above_form(page, base_url):
    """Panel must precede the close form in the DOM (so human reads it first)."""
    arc = _arc_with_close_recommendation()
    page.goto(f"{base_url}/arcs/{arc.slug}/close", wait_until="domcontentloaded")
    panel_box = page.locator(".anchor-rec").bounding_box()
    form_box = page.locator('form[action$="/close"]').bounding_box()
    assert panel_box is not None and form_box is not None, "both elements must be in viewport"
    assert panel_box["y"] < form_box["y"], (
        f"panel (y={panel_box['y']}) should appear above form (y={form_box['y']})"
    )
