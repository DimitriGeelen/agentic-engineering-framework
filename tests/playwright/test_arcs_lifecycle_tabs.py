"""T-1853 (T-NEW-5b): /arcs lifecycle filter tabs.

Visual + behavioural guards on the four-state lifecycle filter strip:
- All four tabs (draft, in-progress, closed, abandoned) render plus an "all" tab.
- Default landing view marks `in-progress` active.
- Counter badges per state are present.
- Clicking each tab navigates with ?status=<label> and marks that tab active.
- DOM-content assertion, NOT element-presence grep (T-1575): we read the page
  content/structure, not just `grep -c "draft"`.
"""

from playwright.sync_api import expect


# Order MUST match _LIFECYCLE_STATES + ("all",) in web/blueprints/arcs.py
_TAB_ORDER = ("draft", "in-progress", "closed", "abandoned", "all")


def test_arcs_index_renders_all_four_lifecycle_tabs_plus_all(page, base_url):
    page.goto(f"{base_url}/arcs", wait_until="domcontentloaded")
    tablist = page.locator("ul.arc-tabs")
    expect(tablist).to_be_visible()
    for label in _TAB_ORDER:
        tab = tablist.locator(f"a[data-filter='{label}']")
        expect(tab).to_be_visible()
        expect(tab).to_contain_text(label)


def test_arcs_default_landing_marks_in_progress_active(page, base_url):
    page.goto(f"{base_url}/arcs", wait_until="domcontentloaded")
    active = page.locator("ul.arc-tabs a.active")
    expect(active).to_have_count(1)
    expect(active).to_have_attribute("data-filter", "in-progress")
    expect(active).to_have_attribute("aria-selected", "true")


def test_arcs_each_filter_marks_matching_tab_active(page, base_url):
    for label in _TAB_ORDER:
        page.goto(f"{base_url}/arcs?status={label}", wait_until="domcontentloaded")
        active = page.locator("ul.arc-tabs a.active")
        expect(active).to_have_count(1)
        expect(active).to_have_attribute("data-filter", label)


def test_arcs_unknown_filter_clamps_to_default(page, base_url):
    page.goto(f"{base_url}/arcs?status=garbage", wait_until="domcontentloaded")
    active = page.locator("ul.arc-tabs a.active")
    expect(active).to_have_count(1)
    expect(active).to_have_attribute("data-filter", "in-progress")


def test_arcs_tabs_carry_counter_badges(page, base_url):
    page.goto(f"{base_url}/arcs", wait_until="domcontentloaded")
    for label in _TAB_ORDER:
        badge = page.locator(f"ul.arc-tabs a[data-filter='{label}'] .tab-count")
        expect(badge).to_be_visible()
        # Counter text is a non-negative integer rendered server-side.
        txt = badge.text_content() or ""
        assert txt.strip().isdigit(), f"counter for '{label}' should be a digit, got: {txt!r}"


def test_arcs_clicking_closed_tab_shows_filter_summary(page, base_url):
    page.goto(f"{base_url}/arcs", wait_until="domcontentloaded")
    page.locator("ul.arc-tabs a[data-filter='closed']").click()
    # Wait for the URL to reflect the click — robust against the race
    # between event firing and page.url being read.
    page.wait_for_url("**/arcs?status=closed", timeout=10_000)
    page.wait_for_load_state("domcontentloaded")
    assert "status=closed" in page.url
    active = page.locator("ul.arc-tabs a.active")
    expect(active).to_have_attribute("data-filter", "closed")
    # Page shows either matching arcs OR the empty-state message — both are
    # valid; a corpus may legitimately have zero closed arcs. The assertion is
    # that the page rendered cleanly under the filter, not a specific count.
    body_text = page.locator("body").text_content() or ""
    assert "filter: closed" in body_text or "No arcs match filter" in body_text
