"""T-1963: /arcs/<slug>/review — read-only review surface.

Parity with /review/T-XXX for tasks: consume the recommendation here, act
on /close. Closed/abandoned arcs still render (unlike /close which 302s).

DOM-content + behavioural assertions per T-1575.
"""

from playwright.sync_api import expect


def test_arc_review_renders_for_in_progress_arc(page, base_url):
    """value-prioritisation (anchor T-1915 with rec) must render the rec panel."""
    page.goto(f"{base_url}/arcs/value-prioritisation/review", wait_until="domcontentloaded")
    expect(page.locator(".arc-review-hdr")).to_be_visible()
    expect(page.locator(".anchor-rec")).to_be_visible()


def test_arc_review_panel_links_to_anchor_task(page, base_url):
    """Recommendation panel must hyperlink the anchor task (T-1915)."""
    page.goto(f"{base_url}/arcs/value-prioritisation/review", wait_until="domcontentloaded")
    anchor_link = page.locator('.anchor-rec a[href="/tasks/T-1915"]').first
    expect(anchor_link).to_be_visible()


def test_arc_review_approve_override_cta_to_close(page, base_url):
    """In-progress arc: 'Approve / Override' CTA must link to /close."""
    page.goto(f"{base_url}/arcs/value-prioritisation/review", wait_until="domcontentloaded")
    close_cta = page.locator('a[href="/arcs/value-prioritisation/close"]').first
    expect(close_cta).to_be_visible()
    text = (close_cta.text_content() or "").strip()
    assert "Approve" in text or "Override" in text, (
        f"primary CTA should mention Approve/Override, got {text!r}"
    )


def test_arc_review_no_form_fields(page, base_url):
    """Read-only — no <form>, no <input>, no <textarea> on the page."""
    page.goto(f"{base_url}/arcs/value-prioritisation/review", wait_until="domcontentloaded")
    main = page.locator("main, body").first
    assert main.locator('form').count() == 0, "review page must not contain any <form>"
    # Some shared shell elements might contain CSRF meta tags, so we don't ban <input>
    # globally — only ban editable types that suggest a form fragment.
    for editable_type in ("text", "textarea", "checkbox", "radio"):
        if editable_type == "textarea":
            assert main.locator("textarea").count() == 0
        else:
            assert main.locator(f'input[type="{editable_type}"]').count() == 0, (
                f"review page must not contain an editable input of type {editable_type!r}"
            )


def test_arc_review_renders_for_closed_arc_without_redirect(page, base_url):
    """dispatch-safety is closed — page must still render (no 302), with closed notice."""
    response = page.goto(
        f"{base_url}/arcs/dispatch-safety/review",
        wait_until="domcontentloaded",
    )
    assert response is not None and response.status == 200, (
        f"closed arc /review must NOT redirect; got status {response.status if response else None}"
    )
    expect(page.locator(".arc-review-hdr")).to_be_visible()
    body_text = (page.locator("body").text_content() or "").lower()
    assert "closed" in body_text, "closed arc page should mention closed status"


def test_arc_review_nonexistent_arc_404(page, base_url):
    """Unknown arc slug must 404."""
    response = page.goto(
        f"{base_url}/arcs/this-arc-does-not-exist-xyz/review",
        wait_until="domcontentloaded",
    )
    assert response is not None and response.status == 404, (
        f"unknown arc must 404, got {response.status if response else None}"
    )
