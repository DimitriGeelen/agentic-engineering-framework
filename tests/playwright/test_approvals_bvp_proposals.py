"""T-2335: /approvals — BVP Driver Proposals section render (live surface).

Graceful-skip pattern per test_approvals_arc_closure_section.py: the section
only renders when .context/bvp-driver-proposals.jsonl has pending rows at run
time. With zero pending proposals the section is suppressed by design — the
test returns early rather than failing.
"""

from playwright.sync_api import expect


def test_approvals_bvp_proposals_section(page, base_url):
    """When pending proposals exist, the section + Approve/Reject buttons render."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    heading = page.locator("#section-bvp-proposals")
    if heading.count() == 0:
        # No pending proposals at run time — section suppressed by design.
        return
    expect(heading).to_be_visible()
    cards = page.locator(".approval-card.bvp-proposal")
    assert cards.count() >= 1, "section heading present but no proposal cards"
    first = cards.first
    expect(first.get_by_role("button", name="Approve")).to_be_visible()
    expect(first.get_by_role("button", name="Reject")).to_be_visible()


def test_approvals_bvp_stat_chip_matches_cards(page, base_url):
    """Summary strip chip (BVP Proposals) count must match rendered cards."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    label = page.locator(".approval-stat .stat-label").filter(has_text="BVP Proposals")
    if label.count() == 0:
        return  # Zero pending proposals — chip suppressed, acceptable.
    card = label.first.locator("xpath=..")
    value_text = (card.locator(".stat-value").text_content() or "").strip()
    assert value_text.isdigit() and int(value_text) >= 1
    assert int(value_text) == page.locator(".approval-card.bvp-proposal").count()
