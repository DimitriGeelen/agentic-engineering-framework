"""T-1879 (T-NEW-14 migration-blindness sweep): landing-page arc cards
render with non-zero task counts, and `/tasks?arc=<id>` filter populates.

Render-surface gate P-013 (T-1766) applies to web/blueprints/core.py and
web/blueprints/tasks.py — counts displayed on the index must reflect the
arc_id-frontmatter migration (T-1850), not a zero from a missed grep.

DOM-content assertion per T-1575 — count substring + filter-page T-NNNN
matches, NOT element-presence grep.
"""
import re

from tests.playwright.arc_corpus import pick_arc


def _arc_card_counts(page) -> dict[str, int]:
    """Return {arc_id: task_count} read card by card from the landing page.

    Each card is one row holding a link to `/tasks?arc=<arc id>` and the text
    "<N> task(s)". T-5160: read per row. The earlier version collected every
    arc-NNN and every "<N> tasks" in the page text and paired them by position,
    which gave an arc another arc's count once the cards were no longer in
    id order.
    """
    out: dict[str, int] = {}
    links = page.locator('a[href*="/tasks?arc="]')
    for i in range(links.count()):
        link = links.nth(i)
        arc_id = (link.text_content() or "").strip()
        row_text = link.locator("xpath=..").text_content() or ""
        m = re.search(r"(\d+)\s+tasks?\b", row_text)
        if arc_id and m:
            # First occurrence wins (the landing page lists each arc once in cards)
            out.setdefault(arc_id, int(m.group(1)))
    return out


def test_landing_arc_cards_show_nonzero_counts(page, base_url):
    # T-5160: the arc is the in-progress arc with the most member tasks, chosen
    # at run time (the landing page lists in-progress arcs only).
    arc = pick_arc("in-progress", min_members=1, numeric_id=True, most_members=True)
    page.goto(f"{base_url}/", wait_until="domcontentloaded")
    counts = _arc_card_counts(page)
    assert arc.numeric_id in counts, (
        f"{arc.numeric_id} ({arc.slug}) missing from landing-page arc cards. "
        f"Found: {sorted(counts)}"
    )
    # The corpus count includes the arc file's own constituent_tasks: list and
    # may move while the suite runs, so the guard is a floor, not equality.
    floor = max(1, int(len(arc.members) * 0.8))
    assert counts[arc.numeric_id] >= floor, (
        f"{arc.slug} card shows {counts[arc.numeric_id]} tasks — the corpus has "
        f"{len(arc.members)}, expected ≥{floor} (T-1879 migration-blindness "
        f"regression guard)."
    )
    # No arc card should be zero — that's the migration-blindness signal.
    zeros = [a for a, n in counts.items() if n == 0]
    assert not zeros, (
        f"Arc cards with zero counts (migration-blindness regression): {zeros}"
    )


def test_tasks_filter_by_arc_returns_members(page, base_url):
    """`/tasks?arc=<slug>` must list the arc's tasks — not empty."""
    arc = pick_arc("in-progress", min_slug_members=4)
    page.goto(f"{base_url}/tasks?arc={arc.slug}", wait_until="domcontentloaded")
    body_text = page.locator("body").text_content() or ""
    task_ids = set(re.findall(r"\bT-\d{3,}\b", body_text))
    overlap = task_ids & arc.slug_members
    assert len(overlap) >= 4, (
        f"Expected ≥4 of the {len(arc.slug_members)} tasks filed under "
        f"{arc.slug} at /tasks?arc={arc.slug}, found {len(overlap)}: {sorted(overlap)}"
    )
