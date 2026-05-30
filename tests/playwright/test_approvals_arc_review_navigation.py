"""T-2112: /approvals 'Review' click must NOT bounce back into the polling div.

Root cause (see T-2112 task body): #approvals-content sets hx-target='this' for
its own 10s polling (T-669 / T-2060). htmx INHERITS hx-target to descendant
anchors. Without an explicit hx-target='#content' on the Review button (and
sibling cross-page nav links), the boost-swap lands the destination INSIDE
the polling div, and ≤10s later the polling cycle overwrites it — i.e.
"bounces back" to /approvals.

This test asserts the post-fix invariant: after clicking Review and waiting
>polling-interval, the URL still points at /arcs/<slug>/review AND the
breadcrumb / page-heading count is 1 (not 2, not 0).

If there are no close-ready arcs at test time, the test is a no-op (the
Review buttons don't render).
"""
from playwright.sync_api import expect


def test_approvals_review_does_not_bounce_back(page, base_url):
    """Click Review on the first arc-closure card; wait past polling cycle; assert URL+DOM stable."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")

    # Find the first Review button inside an arc-closure card. If none, skip.
    review_buttons = page.locator(".approval-card.arc-closure a[href*='/review']")
    if review_buttons.count() == 0:
        return  # No close-ready arcs at test time — nothing to assert.

    first = review_buttons.first
    href = first.get_attribute("href") or ""
    assert href.startswith("/arcs/") and href.endswith("/review"), (
        f"Unexpected Review href: {href!r}"
    )

    # T-2112 contract: explicit hx-target override on the anchor itself.
    assert first.get_attribute("hx-target") == "#content", (
        "Review anchor missing hx-target='#content' override (T-2112 fix). "
        "Without it, the click swaps into the polling div and bounces back."
    )

    first.click()

    # Wait for navigation + at least one polling-cycle window (10s) + safety.
    page.wait_for_url(f"{base_url}{href}", timeout=15000)
    page.wait_for_timeout(12000)  # polling fires every 10s

    # URL must STILL be the review page (not bounced back to /approvals).
    assert page.url.endswith(href), (
        f"After 12s the URL bounced from {href!r} to {page.url!r} — "
        "polling overwrite is back. T-2112 regression."
    )

    # DOM must show ONE breadcrumb (the review page's), not the leftover
    # approvals shell breadcrumb stacked above the new content.
    bc_count = page.locator("nav.wt-breadcrumb").count()
    assert bc_count == 1, (
        f"Expected exactly 1 nav.wt-breadcrumb after navigation, got {bc_count}. "
        "Two means the approvals shell is still visible above the new page "
        "(the T-2112 symptom)."
    )

    # H1 count: exactly one (the review heading), not two (stale 'Approvals' + 'Review arc').
    h1_count = page.locator("h1").count()
    assert h1_count == 1, (
        f"Expected exactly 1 h1 after navigation, got {h1_count}. "
        "Two h1s means the approvals shell is still rendered above the review page."
    )
