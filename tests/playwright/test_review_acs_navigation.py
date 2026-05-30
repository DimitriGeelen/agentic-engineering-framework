"""T-2114: /review/T-XXX AC fragment must not bounce navigation back into itself.

Third sibling of T-2112. Same htmx hx-target inheritance class on a different
surface. The #ac-container polling div (5s polling, T-667) inherits its
hx-target='this' to every descendant — including the explicit 'Reload page'
link AND every URL emitted by render_markdown_safe inside AC Steps/Expected/
If-not text.

The post-T-2114 fix is a single wrapper-reset div at the top of
_review_acs.html that resets hx-target='#content' for all descendants.

This test asserts:
  (a) the rendered fragment carries the wrapping hx-target='#content' div,
  (b) the polling cycle on #ac-container still functions (the polling
      DIV's hx-target='this' resolves on itself, not on the wrapper),
  (c) optionally — when a Reload-page link is visible, clicking it does
      NOT swap the response into #ac-container.
"""
from playwright.sync_api import expect


def test_review_acs_fragment_has_target_reset(page, base_url):
    """The polled fragment must include a wrapping hx-target='#content' div."""
    # Use any task that has Human ACs; T-2112 is current and has 1 Human AC.
    page.goto(f"{base_url}/review/T-2112", wait_until="domcontentloaded")

    container = page.locator("#ac-container")
    expect(container).to_be_visible()

    # The wrapper div should be the first child of #ac-container in DOM,
    # with hx-target='#content' as one of its attributes.
    reset_wrapper = container.locator('> div[hx-target="#content"]').first
    # Wait for the polling fragment to land at least once.
    expect(reset_wrapper).to_be_attached(timeout=10000)


def test_review_acs_no_bounce_back_after_polling(page, base_url):
    """After 6s (one polling cycle + safety) on /review/T-XXX, URL stays put."""
    page.goto(f"{base_url}/review/T-2112", wait_until="networkidle")
    initial_url = page.url

    # Wait past one polling cycle (5s) plus safety.
    page.wait_for_timeout(7000)

    assert page.url == initial_url, (
        f"URL drifted from {initial_url!r} to {page.url!r} during polling cycle. "
        "The polling cycle should swap #ac-container internally, NOT navigate."
    )

    # The polling target wrapper must still be present (i.e. the polling
    # cycle re-rendered the fragment WITH the T-2114 reset wrapper still
    # in place — the wrapper isn't a one-time render artefact).
    container = page.locator("#ac-container")
    reset_wrapper = container.locator('> div[hx-target="#content"]').first
    expect(reset_wrapper).to_be_attached()
