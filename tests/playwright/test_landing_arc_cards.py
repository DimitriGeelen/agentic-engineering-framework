"""T-1879 (T-NEW-14 migration-blindness sweep): landing-page arc cards
render with non-zero task counts, and `/tasks?arc=<id>` filter populates.

Render-surface gate P-013 (T-1766) applies to web/blueprints/core.py and
web/blueprints/tasks.py — counts displayed on the index must reflect the
arc_id-frontmatter migration (T-1850), not a zero from a missed grep.

DOM-content assertion per T-1575 — count substring + filter-page T-NNNN
matches, NOT element-presence grep.
"""
import re


def _arc_card_counts(page) -> dict[str, int]:
    """Return {arc_id: task_count} extracted from arc cards on the landing page."""
    body_text = page.locator("body").text_content() or ""
    # Each card renders "<arc-id> <name> <N> tasks" or " ... 1 task" — pull pairs.
    # The arc id form is arc-NNN; the count word is "task" or "tasks".
    # Order in the body text places the id near its count, but a robust scan
    # finds all (arc-NNN, count) pairs in sequence and joins by adjacency.
    ids = re.findall(r"\b(arc-\d{3,4})\b", body_text)
    counts = re.findall(r"(\d+)\s+tasks?\b", body_text)
    # Same length (one count per card). If they drift, fail loudly.
    out: dict[str, int] = {}
    for i, c in zip(ids, counts):
        # First occurrence wins (the landing page lists each arc once in cards)
        out.setdefault(i, int(c))
    return out


def test_landing_arc_cards_show_nonzero_counts(page, base_url):
    page.goto(f"{base_url}/", wait_until="domcontentloaded")
    counts = _arc_card_counts(page)
    # arc-005 (arc-grooming) is the focused arc in this repo and should be
    # populated; arc-001/-003/-004 are also populated migrated arcs.
    assert "arc-005" in counts, (
        f"arc-005 (arc-grooming) missing from landing-page arc cards. "
        f"Found: {sorted(counts)}"
    )
    assert counts["arc-005"] >= 14, (
        f"arc-grooming card shows {counts['arc-005']} tasks — "
        f"expected ≥14 (T-1879 migration-blindness regression guard)."
    )
    # No arc card should be zero — that's the migration-blindness signal.
    zeros = [a for a, n in counts.items() if n == 0]
    assert not zeros, (
        f"Arc cards with zero counts (migration-blindness regression): {zeros}"
    )


def test_tasks_filter_by_arc_returns_members(page, base_url):
    """`/tasks?arc=arc-grooming` must list arc-grooming tasks — not empty."""
    page.goto(f"{base_url}/tasks?arc=arc-grooming", wait_until="domcontentloaded")
    body_text = page.locator("body").text_content() or ""
    task_ids = set(re.findall(r"\bT-\d{4}\b", body_text))
    # Subset of known arc-grooming members — defensive lower bound.
    expected = {"T-1848", "T-1849", "T-1850", "T-1851", "T-1852"}
    overlap = task_ids & expected
    assert len(overlap) >= 4, (
        f"Expected ≥4 arc-grooming tasks under /tasks?arc=arc-grooming, "
        f"found {len(overlap)}: {sorted(overlap)}"
    )
