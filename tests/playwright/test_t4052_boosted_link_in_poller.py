"""T-4052: a boosted link inside an hx-target="this" polling container must navigate.

base.html boosts the body with hx-target="#content"; polling containers override that
with hx-target="this" (T-2060) and boosted links inside them inherited it, so the task
page was swapped INTO the container and the next poll reverted it while the URL still
named the task. Fix: an htmx:beforeSwap listener retargets boosted swaps to #content.
"""
import re

import pytest
from playwright.sync_api import Page

from tests.playwright.target import url

# approvals polls every 10 s, cockpit #wt-activity every 15 s: wait past two intervals.
APPROVALS_WAIT_MS = 22_000
COCKPIT_WAIT_MS = 33_000
TASK_HREF = re.compile(r"^/(tasks|inception|review)/")


def _first_link(page: Page, container: str):
    for link in page.locator(f"{container} a[href]").all():
        href = link.get_attribute("href") or ""
        if TASK_HREF.match(href):
            return link, href
    return None, None


def _assert_navigated(page: Page, href: str | None, container_id: str, wait_ms: int):
    assert href
    page.wait_for_url(re.compile(re.escape(href) + r"$"), timeout=10_000)
    page.wait_for_timeout(wait_ms)
    assert page.url.endswith(href), f"URL changed away from {href}: {page.url}"
    assert page.locator(f"#{container_id}").count() == 0, (
        f"#{container_id} still in the DOM: the page was swapped into the poller"
    )
    assert page.locator("#content h1").count() >= 1
    assert page.locator("#content h1").first.inner_text().strip() != ""
    # The list page's own header must be gone (it came back on the poll before the fix).
    assert page.locator("#content .page-header h1", has_text="Approvals").count() == 0


def test_approvals_boosted_link_survives_polls(page: Page):
    page.goto(url("/approvals"))
    page.wait_for_selector("#approvals-content")
    link, href = _first_link(page, "#approvals-content")
    if link is None:
        pytest.skip("no task link on /approvals in this corpus")
    link.click()
    _assert_navigated(page, href, "approvals-content", APPROVALS_WAIT_MS)


def test_cockpit_activity_boosted_link_survives_polls(page: Page):
    page.goto(url("/"))
    page.wait_for_selector("#wt-activity", state="attached")
    page.wait_for_timeout(1500)  # hx-trigger "load" fills the list
    link, href = _first_link(page, "#wt-activity")
    if link is None:
        pytest.skip("no task link in the cockpit activity list in this corpus")
    link.click()
    _assert_navigated(page, href, "wt-activity", COCKPIT_WAIT_MS)


def test_approvals_control_still_polls_in_place(page: Page):
    """A page left alone keeps refreshing #approvals-content with one page header."""
    page.goto(url("/approvals"))
    page.wait_for_selector("#approvals-content")
    marker = "t4052-marker"
    page.evaluate(
        "m => { const c = document.getElementById('approvals-content');"
        " c.insertAdjacentHTML('afterbegin', '<span id=\"' + m + '\"></span>'); }",
        marker,
    )
    assert page.locator(f"#{marker}").count() == 1
    page.wait_for_timeout(APPROVALS_WAIT_MS)
    assert page.locator(f"#{marker}").count() == 0, "poll did not refresh the container"
    assert page.locator("#approvals-content").count() == 1
    assert page.locator(".page-header h1", has_text="Approvals").count() == 1
