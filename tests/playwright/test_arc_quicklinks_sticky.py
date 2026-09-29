"""The arc page's quick-link bar stays pinned after a jump (T-3564).

Round 2 shipped `position: sticky` on the bar and a string check would have
passed, but the bar sat inside the header card, and a sticky element cannot
leave its parent, so it scrolled away with the card. An independent render
review caught it from a screenshot. This pins the GEOMETRY, not the CSS:
after jumping to a section, the bar is at the top of the viewport and the
section heading lands below it, not under it.
"""
import pytest

ARC = "/arcs/readme-first-run"   # carries T-3563 story fields, so #decisions exists


@pytest.mark.timeout(180)
def test_quicklinks_bar_pinned_after_jump(page, base_url):
    page.goto(f"{base_url}{ARC}", timeout=120_000)
    page.wait_for_load_state("domcontentloaded")
    geo = page.evaluate(
        """() => {
            document.getElementById('decisions').scrollIntoView({block: 'start'});
            const nav = document.querySelector('nav.arc-quicklinks').getBoundingClientRect();
            const h = document.getElementById('decisions').getBoundingClientRect();
            return {scrollY: window.scrollY, navTop: nav.top, navBottom: nav.bottom, headTop: h.top};
        }"""
    )
    assert geo["scrollY"] > 500, f"page did not scroll, nothing proven: {geo}"
    assert abs(geo["navTop"]) <= 2, f"quick-link bar scrolled away instead of pinning: {geo}"
    assert geo["headTop"] >= geo["navBottom"] - 1, f"section heading hidden under the bar: {geo}"


@pytest.mark.timeout(180)
def test_every_quicklink_targets_an_existing_section(page, base_url):
    page.goto(f"{base_url}{ARC}", timeout=120_000)
    page.wait_for_load_state("domcontentloaded")
    dead = page.evaluate(
        """() => [...document.querySelectorAll('nav.arc-quicklinks a[href^="#"]')]
                 .map(a => a.getAttribute('href'))
                 .filter(h => !document.getElementById(h.slice(1)))"""
    )
    count = page.locator("nav.arc-quicklinks a[href^='#']").count()
    assert count >= 3, f"expected a populated quick-link bar, got {count} links"
    assert dead == [], f"quick links with no target: {dead}"
