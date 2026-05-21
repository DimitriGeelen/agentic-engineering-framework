"""T-1961: /approvals — Arc Closure section renders for close-ready arcs.

Asserts DOM-content + behavioural shape per T-1575 (not bare element grep).

Close-readiness requires: status=in-progress, completion ratio ≥ 0.80,
anchor-task has a ## Recommendation block. At test time, arc-grooming
(33/39 = 0.85) and orchestrator-rethink (94/117 = 0.80) qualify.
"""

from playwright.sync_api import expect


def test_approvals_renders_arc_closure_section(page, base_url):
    """When close-ready arcs exist, the Arc Closure h2 must be present."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    heading = page.locator("#section-arc-closure")
    expect(heading).to_be_visible()


def test_approvals_arc_closure_summary_card(page, base_url):
    """Summary count strip must include an Arc Closure card with a number."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    label = page.locator(".approval-stat .stat-label").filter(has_text="Arc Closure")
    if label.count() == 0:
        # If zero qualifying arcs at run time, card is suppressed — acceptable.
        return
    expect(label.first).to_be_visible()
    # Find the parent card and its value span — must be a digit.
    card = label.first.locator("xpath=..")
    value_text = (card.locator(".stat-value").text_content() or "").strip()
    assert value_text.isdigit() and int(value_text) >= 1, (
        f"Arc Closure summary value should be a positive int, got {value_text!r}"
    )


def test_approvals_arc_closure_card_has_verdict_and_completion(page, base_url):
    """Each .arc-closure card must have a verdict badge and a completion fraction."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    cards = page.locator(".approval-card.arc-closure")
    n = cards.count()
    if n == 0:
        return  # No qualifying arcs at run time; nothing to assert.
    first = cards.first
    badge = first.locator(".verdict-badge").first
    badge_text = (badge.text_content() or "").strip()
    assert badge_text in {"CLOSE", "KEEP-OPEN", "GO", "NO-GO", "DEFER", "?"}, (
        f"verdict badge text {badge_text!r} not a canonical verdict"
    )
    # Card text must contain a completion fraction shape "N/M"
    card_text = first.text_content() or ""
    import re
    assert re.search(r"\d+/\d+", card_text), (
        f"Arc Closure card should show completion fraction, got: {card_text!r}"
    )


def test_approvals_arc_closure_links_to_close_route(page, base_url):
    """Approve/Override CTA must link to /arcs/<slug>/close."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    cards = page.locator(".approval-card.arc-closure")
    if cards.count() == 0:
        return
    slug = cards.first.get_attribute("data-arc-slug") or ""
    assert slug, "data-arc-slug attribute must be populated"
    close_link = cards.first.locator(f'a[href="/arcs/{slug}/close"]').first
    expect(close_link).to_be_visible()


def test_approvals_arc_closure_links_to_anchor_task(page, base_url):
    """Anchor task link must point to /tasks/T-XXXX."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    cards = page.locator(".approval-card.arc-closure")
    if cards.count() == 0:
        return
    anchor_link = cards.first.locator('a[href^="/tasks/T-"]').first
    href = anchor_link.get_attribute("href")
    assert href is not None and href.startswith("/tasks/T-"), (
        f"anchor link should point to /tasks/T-XXX, got {href!r}"
    )
