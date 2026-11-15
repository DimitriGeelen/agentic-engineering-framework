"""T-1961: /approvals — Arc Closure section renders for close-ready arcs.

Asserts DOM-content + behavioural shape per T-1575 (not bare element grep).

Which arcs are in the queue is the page's own L1 + L2 predicate (T-3552), so
the tests take whatever cards are shown. What a card must show depends on the
arc's state, read from the corpus at run time (T-5160): an arc whose close-out
or anchor task holds a CLOSE / KEEP-OPEN recommendation is reviewable (verdict
badge, Approve / Override link); any other arc in the queue is BLOCKED and
offers no close link (T-2986, T-4320).
"""
import re

from playwright.sync_api import expect

from tests.playwright.arc_corpus import all_arcs


def _corpus_arc(slug):
    for arc in all_arcs():
        if arc.slug == slug:
            return arc
    raise AssertionError(f"/approvals shows an Arc Closure card for {slug!r}, "
                         f"which has no file under .context/arcs/")


def test_approvals_renders_arc_closure_section(page, base_url):
    """When close-ready arcs exist, the Arc Closure h2 must be present."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    heading = page.locator("#section-arc-closure")
    expect(heading).to_be_visible()


def test_approvals_arc_closure_summary_card(page, base_url):
    """Summary count strip must include an Arc Closure card with a number."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    label = page.locator(".approval-stat .stat-label").filter(has_text="Arc Closure")
    if label.count() == 0:
        # If zero qualifying arcs at run time, card is suppressed — acceptable.
        return
    expect(label.first).to_be_visible()
    # Find the parent card and its value span — must be a digit.
    card = label.first.locator("xpath=..")
    value_text = (card.locator(".stat-value").text_content() or "").strip()
    assert value_text.isdigit() and int(value_text) >= 1, (
        f"Arc Closure summary value should be a positive int, got {value_text!r}"
    )


def test_approvals_arc_closure_card_has_verdict_and_completion(page, base_url):
    """Each .arc-closure card must show the verdict its arc's state calls for,
    and a completion fraction."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    cards = page.locator(".approval-card.arc-closure")
    n = cards.count()
    if n == 0:
        return  # No qualifying arcs at run time; nothing to assert.
    for i in range(n):
        card = cards.nth(i)
        slug = card.get_attribute("data-arc-slug") or ""
        assert slug, "data-arc-slug attribute must be populated"
        arc = _corpus_arc(slug)
        badge_text = (card.locator(".verdict-badge").first.text_content() or "").strip()
        expected = arc.close_rec_verdict or "BLOCKED"
        assert badge_text == expected, (
            f"{slug}: verdict badge shows {badge_text!r}, expected {expected!r} "
            f"(close recommendation in corpus: {arc.close_rec_task or 'none'})"
        )
        # Card text must contain a completion fraction shape "N/M"
        card_text = card.text_content() or ""
        assert re.search(r"\d+/\d+", card_text), (
            f"Arc Closure card should show completion fraction, got: {card_text!r}"
        )


def test_approvals_arc_closure_links_to_close_route(page, base_url):
    """A reviewable card's Approve/Override CTA links to /arcs/<slug>/close; a
    blocked card (no close recommendation) offers no close link (T-2986)."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    cards = page.locator(".approval-card.arc-closure")
    for i in range(cards.count()):
        card = cards.nth(i)
        slug = card.get_attribute("data-arc-slug") or ""
        assert slug, "data-arc-slug attribute must be populated"
        close_link = card.locator(f'a[href="/arcs/{slug}/close"]')
        if _corpus_arc(slug).close_rec_task:
            expect(close_link.first).to_be_visible()
        else:
            expect(close_link).to_have_count(0)
        expect(card.locator(f'a[href="/arcs/{slug}/review"]').first).to_be_visible()


def test_approvals_arc_closure_links_to_anchor_task(page, base_url):
    """Anchor task link must point to /tasks/T-XXXX."""
    page.goto(f"{base_url}/approvals", wait_until="domcontentloaded")
    cards = page.locator(".approval-card.arc-closure")
    if cards.count() == 0:
        return
    anchor_link = cards.first.locator('a[href^="/tasks/T-"]').first
    href = anchor_link.get_attribute("href")
    assert href is not None and href.startswith("/tasks/T-"), (
        f"anchor link should point to /tasks/T-XXX, got {href!r}"
    )
