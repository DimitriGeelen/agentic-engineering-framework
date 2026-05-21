"""T-1960: /arcs/<slug>/close — Agent Recommendation panel renders above form.

The panel reads the arc's anchor-task `## Recommendation` block and surfaces
verdict / rationale / evidence inline, so the human's close decision starts
from the agent's advisory rather than a blank form.

DOM-content + behavioural assertions per T-1575 (not bare element grep).
"""

from playwright.sync_api import expect


def test_arc_close_renders_recommendation_panel(page, base_url):
    """value-prioritisation arc (arc-006) anchor task T-1915 has ## Recommendation GO.
    The /close page must render the .anchor-rec panel with the GO verdict badge.
    """
    page.goto(f"{base_url}/arcs/value-prioritisation/close", wait_until="domcontentloaded")
    panel = page.locator(".anchor-rec")
    assert panel.count() == 1, "expected exactly one .anchor-rec panel"
    expect(panel).to_be_visible()


def test_arc_close_panel_verdict_badge_present(page, base_url):
    """Panel must display a verdict badge with one of the canonical verdicts."""
    page.goto(f"{base_url}/arcs/value-prioritisation/close", wait_until="domcontentloaded")
    badge = page.locator(".anchor-rec .verdict-badge").first
    text = (badge.text_content() or "").strip()
    assert text in {"GO", "NO-GO", "DEFER", "CLOSE", "KEEP-OPEN"}, (
        f"verdict badge text {text!r} not one of GO/NO-GO/DEFER/CLOSE/KEEP-OPEN"
    )


def test_arc_close_panel_links_to_anchor_task(page, base_url):
    """Panel must hyperlink the anchor task ID (T-1915 for value-prioritisation)."""
    page.goto(f"{base_url}/arcs/value-prioritisation/close", wait_until="domcontentloaded")
    anchor_link = page.locator('.anchor-rec a[href="/tasks/T-1915"]').first
    expect(anchor_link).to_be_visible()


def test_arc_close_panel_renders_rationale(page, base_url):
    """T-1915 has a non-empty rationale — the panel must render it as readable content."""
    page.goto(f"{base_url}/arcs/value-prioritisation/close", wait_until="domcontentloaded")
    rationale_block = page.locator(".anchor-rec .rec-body").first
    text = (rationale_block.text_content() or "").strip()
    # Rationale should be substantive (> 50 chars), not empty/placeholder.
    assert len(text) > 50, f"expected substantive rationale text, got len={len(text)}"


def test_arc_close_panel_positioned_above_form(page, base_url):
    """Panel must precede the close form in the DOM (so human reads it first)."""
    page.goto(f"{base_url}/arcs/value-prioritisation/close", wait_until="domcontentloaded")
    panel_box = page.locator(".anchor-rec").bounding_box()
    form_box = page.locator('form[action$="/close"]').bounding_box()
    assert panel_box is not None and form_box is not None, "both elements must be in viewport"
    assert panel_box["y"] < form_box["y"], (
        f"panel (y={panel_box['y']}) should appear above form (y={form_box['y']})"
    )
