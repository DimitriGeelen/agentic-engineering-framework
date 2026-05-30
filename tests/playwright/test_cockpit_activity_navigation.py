"""T-2113: cockpit Recent Activity task-link click must NOT bounce back.

Sibling of T-2112 (same bug class on a different surface).

#wt-activity sets hx-target='this' for its own 15s polling cycle
(arc-007 S6d / T-2020). htmx inherits hx-target to descendants — without
an explicit override on the .wt-activity-task anchors, clicking one swaps
the /tasks/T-XXX page INTO the activity widget (cockpit shell stays
visible above), and ≤15s later the polling cycle overwrites the swap with
the activity feed → bounce-back.

This test asserts the post-T-2113 invariant.
"""
from playwright.sync_api import expect


def test_cockpit_activity_task_link_does_not_bounce_back(page, base_url):
    """Click a task ID in the cockpit Recent Activity card; wait past polling cycle; assert stable."""
    page.goto(f"{base_url}/cockpit", wait_until="networkidle")

    # The polling fragment loads via hx-trigger="load, every 15s". Wait a bit
    # extra so the load-triggered fetch completes after networkidle settles.
    page.wait_for_timeout(3000)

    links = page.locator(".wt-activity-task[href^='/tasks/']")
    if links.count() == 0:
        # No task-tagged activity entries at test time. The fragment-level
        # override is still pinned by Verification command 1 (static grep)
        # and command 3 (rendered HTML grep). End-to-end skip is acceptable
        # here — the contract is structural, not data-dependent.
        return

    first = links.first
    href = first.get_attribute("href") or ""
    assert href.startswith("/tasks/T-"), f"Unexpected wt-activity-task href: {href!r}"

    # T-2113 contract: explicit hx-target override.
    assert first.get_attribute("hx-target") == "#content", (
        "wt-activity-task missing hx-target='#content' override (T-2113 fix). "
        "Without it, the click swaps into the polling div and bounces back."
    )

    first.click()
    page.wait_for_url(f"{base_url}{href}", timeout=15000)

    # Wait past one polling cycle (15s) + safety.
    page.wait_for_timeout(17000)

    assert page.url.endswith(href), (
        f"After 17s the URL bounced from {href!r} to {page.url!r} — "
        "cockpit-activity polling overwrite is back. T-2113 regression."
    )

    bc_count = page.locator("nav.wt-breadcrumb").count()
    assert bc_count == 1, (
        f"Expected exactly 1 nav.wt-breadcrumb after navigation, got {bc_count}. "
        "Two means the cockpit shell is still rendered above the task page."
    )

    h1_count = page.locator("h1").count()
    assert h1_count == 1, (
        f"Expected exactly 1 h1 after navigation, got {h1_count}. "
        "Two h1s = stale cockpit heading + new task heading both visible."
    )
