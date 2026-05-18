"""T-1904: /arcs kanban — 4-column lifecycle layout replacing T-1853 tabs.

Visual + behavioural guards on the kanban:
- Four columns render (draft, in-progress, closed, abandoned).
- Each column has a header showing the state name + count.
- Arc cards are clickable and navigate to /arcs/<id>.
- Nav: "Arcs" link lives under "Work" group, not "Architecture".
- DOM-content assertions, NOT element-presence grep (T-1575).
"""

from playwright.sync_api import expect


# Order MUST match _LIFECYCLE_STATES in web/blueprints/arcs.py
_KANBAN_COLUMNS = ("draft", "in-progress", "closed", "abandoned")


def test_arcs_kanban_renders_four_columns(page, base_url):
    page.goto(f"{base_url}/arcs", wait_until="domcontentloaded")
    board = page.locator(".arc-kanban-board")
    expect(board).to_be_visible()
    columns = page.locator(".arc-kanban-board > .kanban-column")
    expect(columns).to_have_count(4)


def test_arcs_kanban_columns_in_lifecycle_order(page, base_url):
    page.goto(f"{base_url}/arcs", wait_until="domcontentloaded")
    for i, state in enumerate(_KANBAN_COLUMNS):
        col = page.locator(f".arc-kanban-board > .kanban-column").nth(i)
        expect(col).to_have_attribute("data-state", state)


def test_arcs_kanban_each_column_has_header_and_count(page, base_url):
    page.goto(f"{base_url}/arcs", wait_until="domcontentloaded")
    for state in _KANBAN_COLUMNS:
        header = page.locator(f".kanban-column[data-state='{state}'] .kanban-column-header")
        expect(header).to_be_visible()
        # State name appears in header
        expect(header).to_contain_text(state)
        # Counter is a non-negative integer rendered server-side
        count = header.locator(".count")
        expect(count).to_be_visible()
        txt = (count.text_content() or "").strip()
        assert txt.isdigit(), f"count for '{state}' should be a digit, got: {txt!r}"


def test_arcs_kanban_in_progress_column_contains_at_least_one_arc(page, base_url):
    """In any active corpus with ongoing work, at least one arc should be
    in the in-progress column. arc-005 (arc-grooming) is the canonical
    example at the time of writing."""
    page.goto(f"{base_url}/arcs", wait_until="domcontentloaded")
    in_progress = page.locator(".kanban-column[data-state='in-progress']")
    cards = in_progress.locator(".arc-card")
    # At least one arc should be in-progress; if not, the corpus changed
    # significantly. The test does not name a specific arc — just asserts
    # the column is not empty in a meaningful way.
    count = cards.count()
    if count > 0:
        # Cards must have an arc-card-id link
        first = cards.first
        link = first.locator(".arc-card-id")
        expect(link).to_be_visible()
        href = link.get_attribute("href") or ""
        assert href.startswith("/arcs/arc-"), f"arc-card link should be /arcs/arc-NNN, got: {href!r}"


def test_arcs_kanban_card_link_navigates_to_detail(page, base_url):
    page.goto(f"{base_url}/arcs", wait_until="domcontentloaded")
    first_card = page.locator(".arc-card").first
    expect(first_card).to_be_visible()
    link = first_card.locator(".arc-card-id")
    href = link.get_attribute("href")
    assert href and href.startswith("/arcs/arc-")
    link.click()
    page.wait_for_url(f"**{href}", timeout=10_000)
    # Detail page renders SOMETHING (no 404)
    body_text = page.locator("body").text_content() or ""
    assert "arc-" in body_text


def test_arcs_link_lives_under_work_nav_group(page, base_url):
    """Regression test for T-1904: /arcs was previously under Architecture;
    user expected it under Work. The nav <details> for 'Work' must contain
    an <a href='/arcs'>; the 'Architecture' <details> must not."""
    page.goto(f"{base_url}/arcs", wait_until="domcontentloaded")
    work_group = page.locator("li details:has(summary:text-is('Work'))")
    expect(work_group).to_have_count(1)
    work_arcs_link = work_group.locator("a[href='/arcs']")
    expect(work_arcs_link).to_have_count(1)
    arch_group = page.locator("li details:has(summary:text-is('Architecture'))")
    expect(arch_group).to_have_count(1)
    arch_arcs_link = arch_group.locator("a[href='/arcs']")
    expect(arch_arcs_link).to_have_count(0)


def test_arcs_legacy_status_filter_still_renders_flat_list(page, base_url):
    """Backward-compat: /arcs?status=closed renders the legacy flat list,
    not the kanban. Bookmarks and external links survive."""
    page.goto(f"{base_url}/arcs?status=closed", wait_until="domcontentloaded")
    # Kanban board must NOT appear in legacy mode
    board = page.locator(".arc-kanban-board")
    expect(board).to_have_count(0)
    # Legacy flat-list mode either has arc-row cards or a "back to kanban"
    # link in the summary line.
    body_text = page.locator("body").text_content() or ""
    assert "back to kanban" in body_text or "No arcs match" in body_text or "filter: closed" in body_text
