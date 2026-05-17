"""T-1876 (T-NEW-12): /arcs/<slug> reads arc_id frontmatter for constituents.

Sibling of T-1874 (lib/arc.sh) and T-1875 (audit fallback): the arc-detail
page must include tasks whose membership is declared via `arc_id:`
frontmatter (T-1849 canonical, populated by T-1850 migration), not only the
legacy `arc:<slug>` tag scan.

DOM-content assertion, NOT element-presence grep (T-1575): we inspect the
rendered page content for the task IDs, then count distinct matches.
"""

import re


# All known arc-grooming arc tasks at the time of this test's authoring.
# Tests assert ≥10 of these appear; new tasks added to the arc after writing
# this test will not break it (lower bound check).
_EXPECTED_ARC_GROOMING_TASKS = [
    "T-1846",  # inception parent
    "T-1847",  # workspace scaffold
    "T-1848", "T-1849", "T-1850", "T-1851", "T-1852",
    "T-1853", "T-1854", "T-1855", "T-1856", "T-1857",
    "T-1874", "T-1875", "T-1876",  # migration-blindness sibling cluster
]


def _task_ids_in(page) -> set[str]:
    """Return distinct T-NNNN task IDs that appear in the rendered DOM body."""
    body_text = page.locator("body").text_content() or ""
    return set(re.findall(r"\bT-\d{4}\b", body_text))


def test_arcs_detail_slug_url_lists_arc_id_members(page, base_url):
    page.goto(f"{base_url}/arcs/arc-grooming", wait_until="domcontentloaded")
    found = _task_ids_in(page)
    expected = set(_EXPECTED_ARC_GROOMING_TASKS)
    overlap = found & expected
    assert len(overlap) >= 10, (
        f"Expected ≥10 arc-grooming tasks on /arcs/arc-grooming, "
        f"found {len(overlap)}: {sorted(overlap)}"
    )


def test_arcs_detail_numeric_url_lists_same_members(page, base_url):
    """Dual identity: /arcs/arc-005 must render the same constituent set."""
    page.goto(f"{base_url}/arcs/arc-grooming", wait_until="domcontentloaded")
    slug_form = _task_ids_in(page) & set(_EXPECTED_ARC_GROOMING_TASKS)

    page.goto(f"{base_url}/arcs/arc-005", wait_until="domcontentloaded")
    numeric_form = _task_ids_in(page) & set(_EXPECTED_ARC_GROOMING_TASKS)

    assert slug_form == numeric_form, (
        f"Dual-identity contract broken: slug form has {sorted(slug_form)} "
        f"vs arc-NNN form {sorted(numeric_form)}"
    )
    assert len(slug_form) >= 10


def test_arcs_detail_stats_total_nonzero(page, base_url):
    """Stats panel must report non-zero total now that membership is visible."""
    page.goto(f"{base_url}/arcs/arc-grooming", wait_until="domcontentloaded")
    body_text = page.locator("body").text_content() or ""
    # Stats appear as "Total: <N>" or in a labelled cell — look for a number
    # adjacent to a "total" indicator. Be lenient on exact wording.
    m = re.search(r"[Tt]otal[\s:]+(\d+)", body_text)
    assert m is not None, (
        "Could not locate a 'Total: N' indicator on the page — "
        "either the stats panel format changed or it isn't rendering."
    )
    assert int(m.group(1)) >= 10, (
        f"Stats total = {m.group(1)} — expected ≥10 for arc-grooming."
    )


def test_arcs_detail_unknown_arc_returns_404(page, base_url):
    """Sanity: real 404 path still returns 404 (regression guard)."""
    response = page.goto(
        f"{base_url}/arcs/definitely-not-an-arc-slug",
        wait_until="domcontentloaded",
    )
    assert response is not None
    assert response.status == 404
