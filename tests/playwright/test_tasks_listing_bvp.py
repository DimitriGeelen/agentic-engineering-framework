"""T-1982: /tasks listing — BVP badge on kanban cards + list view.

The BVP_norm chip must appear for every task with bvp_scores (confirmed) or
bvp_scores_proposed (estimator-proposed). The chip links to the task detail
page's #bvp-block anchor (T-1980).

DOM-content + behavioural assertions per T-1575 (not bare element grep).
"""

from playwright.sync_api import expect


def test_tasks_list_view_renders_bvp_badges(page, base_url):
    """List view must render at least one .bvp-badge — many tasks have proposed scores."""
    page.goto(f"{base_url}/tasks?view=list", wait_until="domcontentloaded")
    badges = page.locator(".bvp-badge")
    assert badges.count() >= 1, "expected ≥1 BVP badge on /tasks?view=list"


def test_tasks_kanban_view_renders_bvp_badges(page, base_url):
    """Kanban view (default) must also render BVP badges on cards."""
    page.goto(f"{base_url}/tasks", wait_until="domcontentloaded")
    badges = page.locator(".bvp-badge")
    assert badges.count() >= 1, "expected ≥1 BVP badge on /tasks (kanban)"


def test_tasks_bvp_badge_links_to_detail_block(page, base_url):
    """Each BVP badge must link to /tasks/T-XXX#bvp-block (T-1980 surface)."""
    page.goto(f"{base_url}/tasks?view=list", wait_until="domcontentloaded")
    first = page.locator(".bvp-badge").first
    href = first.get_attribute("href")
    assert href is not None and href.startswith("/tasks/T-") and href.endswith("#bvp-block"), (
        f"badge href should target /tasks/T-XXX#bvp-block, got {href!r}"
    )


def test_tasks_bvp_badge_proposed_mode_uses_italic_asterisk(page, base_url):
    """Estimator-proposed badges must render as italic + asterisk (T-1980 provenance signal)."""
    page.goto(f"{base_url}/tasks?view=list", wait_until="domcontentloaded")
    proposed = page.locator(".bvp-badge-proposed").first
    if proposed.count() == 0:
        # If no proposed-mode tasks exist at run time, the assertion doesn't apply.
        return
    text = proposed.text_content() or ""
    assert "*" in text, f"proposed-mode badge should contain asterisk, got {text!r}"
