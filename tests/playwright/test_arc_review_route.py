"""T-1963: /arcs/<slug>/review — read-only review surface.

Parity with /review/T-XXX for tasks: consume the recommendation here, act
on /close. Closed/abandoned arcs still render (unlike /close which 302s).

DOM-content + behavioural assertions per T-1575.
"""

from playwright.sync_api import expect

from tests.playwright.arc_corpus import pick_arc


def test_arc_review_renders_for_in_progress_arc(fixture_page, arc_fixture_url, close_rec_arc):
    """An open arc with a close recommendation (CLOSE / KEEP-OPEN, T-4320)
    must render the rec panel. T-5168: runs against the fixture project, because
    the live corpus often holds no such arc."""
    page, base_url, arc = fixture_page, arc_fixture_url, close_rec_arc
    page.goto(f"{base_url}/arcs/{arc.slug}/review", wait_until="domcontentloaded")
    expect(page.locator(".arc-review-hdr")).to_be_visible()
    expect(page.locator(".anchor-rec")).to_be_visible()


def test_arc_review_panel_links_to_anchor_task(fixture_page, arc_fixture_url, close_rec_arc):
    """Recommendation panel must hyperlink the task it was read from (T-5168: fixture project)."""
    page, base_url, arc = fixture_page, arc_fixture_url, close_rec_arc
    page.goto(f"{base_url}/arcs/{arc.slug}/review", wait_until="domcontentloaded")
    anchor_link = page.locator(f'.anchor-rec a[href="/tasks/{arc.close_rec_task}"]').first
    expect(anchor_link).to_be_visible()


def test_arc_review_approve_override_cta_to_close(page, base_url):
    """In-progress arc: 'Approve / Override' CTA must link to /close."""
    arc = pick_arc("in-progress")
    page.goto(f"{base_url}/arcs/{arc.slug}/review", wait_until="domcontentloaded")
    close_cta = page.locator(f'a[href="/arcs/{arc.slug}/close"]').first
    expect(close_cta).to_be_visible()
    text = (close_cta.text_content() or "").strip()
    assert "Approve" in text or "Override" in text, (
        f"primary CTA should mention Approve/Override, got {text!r}"
    )


def test_arc_review_no_form_fields(page, base_url):
    """Read-only — no <form>, no <input>, no <textarea> on the page."""
    arc = pick_arc("in-progress")
    page.goto(f"{base_url}/arcs/{arc.slug}/review", wait_until="domcontentloaded")
    # T-5160: "main, body" resolved to <body> and caught the command palette's text input,
    # which base.html places outside <main id="content">. The review content lives in main.
    main = page.locator("main#content")
    expect(main).to_have_count(1)
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
    """A closed arc's page must still render (no 302), with closed notice."""
    arc = pick_arc("closed")
    response = page.goto(
        f"{base_url}/arcs/{arc.slug}/review",
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


def test_arc_review_headline_mechanic_box_visible_with_text(page, base_url):
    """T-2110: the .headline-mechanic-box must render with the arc's headline_mechanic
    text inside it. Pins the structural rendering after the contrast fix — if a future
    refactor accidentally drops the box or detaches it from the headline_mechanic
    field, this test fails before the human report does.

    T-5160: the arc is any in-progress arc with a populated headline_mechanic,
    chosen at run time.
    """
    arc = pick_arc("in-progress", headline_mechanic=True)
    page.goto(f"{base_url}/arcs/{arc.slug}/review", wait_until="domcontentloaded")
    box = page.locator(".headline-mechanic-box")
    expect(box).to_be_visible()
    text = (box.text_content() or "").strip()
    assert len(text) > 20, (
        f".headline-mechanic-box should contain the arc's headline_mechanic text; "
        f"got {text!r} ({len(text)} chars)"
    )
