"""T-1980: /tasks/T-XXX BVP block — DOM-content assertions.

The task detail page must render a BVP block that:
  - Always renders for any task (confirmed / proposed / no-scores modes).
  - Shows mode via data-bvp-mode attribute and a visible badge.
  - For scored tasks: shows BVP_norm, BVP_raw, Cost rows + per-driver scores.
  - For unscored tasks: shows the "No scores yet" hint linking to /bvp.

T-1575: DOM-content assertions, not bare element-presence grep.
"""

import re
from playwright.sync_api import expect


# T-1978 is in proposed-mode at the time of writing (estimator wrote scores;
# none confirmed). Use it as the canonical "has scores" target.
_PROPOSED_TASK = "T-1978"


def test_task_detail_renders_bvp_block(page, base_url):
    page.goto(f"{base_url}/tasks/{_PROPOSED_TASK}", wait_until="domcontentloaded")
    section = page.locator("section.bvp-block")
    expect(section).to_be_visible()


def test_task_detail_bvp_block_has_h3_heading(page, base_url):
    page.goto(f"{base_url}/tasks/{_PROPOSED_TASK}", wait_until="domcontentloaded")
    expect(page.locator("section.bvp-block h3", has_text="BVP")).to_be_visible()


def test_task_detail_bvp_block_has_mode_attribute(page, base_url):
    """data-bvp-mode is the structural pin for the three render modes."""
    page.goto(f"{base_url}/tasks/{_PROPOSED_TASK}", wait_until="domcontentloaded")
    section = page.locator("section.bvp-block")
    mode = section.get_attribute("data-bvp-mode")
    assert mode in ("confirmed", "proposed", "none"), f"unexpected mode: {mode!r}"


def test_task_detail_bvp_block_shows_norm_when_scored(page, base_url):
    """Scored tasks render BVP_norm with a 3-decimal number."""
    page.goto(f"{base_url}/tasks/{_PROPOSED_TASK}", wait_until="domcontentloaded")
    section = page.locator("section.bvp-block")
    mode = section.get_attribute("data-bvp-mode")
    if mode == "none":
        # If the task happens to have no scores at the time tests run, the
        # numeric pin doesn't apply — assert the hint instead.
        expect(section.locator("p.muted", has_text="No BVP scores yet")).to_be_visible()
        return
    # Composite block — find the BVP_norm row td content (3-decimal float, optionally italicised with *)
    composite_td = section.locator("th:has-text('BVP_norm') + td")
    expect(composite_td).to_be_visible()
    text = composite_td.text_content() or ""
    assert re.search(r"\d+\.\d{3}\*?", text), f"BVP_norm cell missing numeric value: {text!r}"


def test_task_detail_bvp_block_links_to_bvp_page(page, base_url):
    """The 'View on /bvp →' link must be present for cross-surface navigation."""
    page.goto(f"{base_url}/tasks/{_PROPOSED_TASK}", wait_until="domcontentloaded")
    link = page.locator('section.bvp-block a[href="/bvp"]')
    expect(link).to_be_visible()
