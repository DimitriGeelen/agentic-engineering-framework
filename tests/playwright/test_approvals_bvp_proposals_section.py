"""T-2335: /approvals — BVP Driver Proposals section renders for pending proposals.

Asserts DOM-content + behavioural shape per T-1575 (not bare element grep).

Pending proposals come from .context/bvp-driver-proposals.jsonl (T-2331 write,
T-2332 /bvp read surface). When zero pending proposals exist at run time the
section is suppressed — each test returns early in that case (mirrors the
Arc-Closure section test, which tolerates zero qualifying arcs).
"""

from playwright.sync_api import expect


def test_approvals_bvp_section_present_when_proposals_exist(page, base_url):
    """When pending proposals exist, the BVP Driver Proposals h2 must be present."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    cards = page.locator(".approval-card.bvp-proposal")
    if cards.count() == 0:
        return  # No pending proposals at run time; section suppressed — acceptable.
    heading = page.locator("#section-bvp-proposals")
    expect(heading).to_be_visible()


def test_approvals_bvp_summary_card(page, base_url):
    """Summary count strip must include a BVP Drivers card with a positive int."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    label = page.locator(".approval-stat .stat-label").filter(has_text="BVP Drivers")
    if label.count() == 0:
        return  # Zero pending proposals at run time — card suppressed.
    expect(label.first).to_be_visible()
    card = label.first.locator("xpath=..")
    value_text = (card.locator(".stat-value").text_content() or "").strip()
    assert value_text.isdigit() and int(value_text) >= 1, (
        f"BVP Drivers summary value should be a positive int, got {value_text!r}"
    )


def test_approvals_bvp_card_has_name_and_weight(page, base_url):
    """Each .bvp-proposal card must show a driver name and a 'weight N' label."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    cards = page.locator(".approval-card.bvp-proposal")
    if cards.count() == 0:
        return
    first = cards.first
    pid = first.get_attribute("data-proposal-id") or ""
    assert pid, "data-proposal-id attribute must be populated"
    card_text = first.text_content() or ""
    import re
    assert re.search(r"weight\s+\d+", card_text), (
        f"BVP proposal card should show a weight, got: {card_text!r}"
    )


def test_approvals_bvp_card_links_to_bvp(page, base_url):
    """Review CTA must link to /bvp (where the operator approves/rejects, T-2332)."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    cards = page.locator(".approval-card.bvp-proposal")
    if cards.count() == 0:
        return
    review_link = cards.first.locator('a[href="/bvp"]').first
    expect(review_link).to_be_visible()
