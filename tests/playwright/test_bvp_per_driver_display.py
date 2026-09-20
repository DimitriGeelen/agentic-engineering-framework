"""T-2170 Slice 2 (T-2346): /bvp facet axis-swap — executed-browser guards.

L-423 (origin T-1999): a page with inline click handlers can return HTTP 200
with all markup present while the JS is functionally dead (a SyntaxError
aborts the IIFE silently). Markup-presence assertions do not catch that class
— only executing the JS in a real browser does. These tests drive the actual
facet checkboxes and assert on the DOM state the click handlers are supposed
to produce, matching the pattern established in test_appearance_presets.py.

Covers:
  (a) facet row + one checkbox per driver present, matching the Slice-1
      per-driver score table's driver set 1:1
  (b) clicking a facet checkbox changes the Y-axis label text
  (c) clicking a second facet un-checks the first (single-active enforced
      in the DOM, not just the model)
  (d) zero browser console errors (excluding the known-benign favicon 404)
      across facet interactions
"""
from __future__ import annotations

from playwright.sync_api import expect


def _driver_ids(page):
    return page.eval_on_selector_all(
        "#bvp-axis-facets input.bvp-facet-toggle",
        "els => els.map(e => e.getAttribute('data-driver-id'))",
    )


def _table_driver_ids(page):
    return page.eval_on_selector_all(
        "#bvp-driver-scores-section th[data-driver-id]",
        "els => els.map(e => e.getAttribute('data-driver-id'))",
    )


def test_bvp_facet_row_present_one_checkbox_per_driver(page, base_url):
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    expect(page.locator("#bvp-axis-facets")).to_be_visible()
    facet_ids = _driver_ids(page)
    assert len(facet_ids) >= 4, f"expected >=4 facet checkboxes (D1-D4), got {facet_ids!r}"
    # 1:1 with the Slice-1 per-driver table's driver set (T-2170 contract) when
    # the table is present (it only renders with scored data).
    table_ids = _table_driver_ids(page)
    if table_ids:
        assert set(facet_ids) == set(table_ids), (
            f"facet driver set {facet_ids!r} must match Slice-1 table driver set {table_ids!r}"
        )


def test_bvp_facet_default_state_is_bvp_norm(page, base_url):
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    label = page.locator("#bvp-y-axis-label")
    expect(label).to_have_text("BVP_norm")
    for cb in page.locator("#bvp-axis-facets input.bvp-facet-toggle").all():
        expect(cb).not_to_be_checked()


def test_bvp_facet_click_changes_axis_label_and_single_active_enforced(page, base_url):
    """(b) clicking a facet changes the Y-axis label; (c) clicking a second
    facet un-checks the first, in the DOM (not just an in-memory model)."""
    errors = []
    page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")

    driver_ids = _driver_ids(page)
    assert len(driver_ids) >= 2, "need >=2 drivers to test single-active enforcement"
    first_id, second_id = driver_ids[0], driver_ids[1]

    first_cb = page.locator(f'input.bvp-facet-toggle[data-driver-id="{first_id}"]')
    second_cb = page.locator(f'input.bvp-facet-toggle[data-driver-id="{second_id}"]')
    label = page.locator("#bvp-y-axis-label")

    # (b) click first facet -> label changes off BVP_norm
    first_cb.click()
    expect(label).to_have_text(f"{first_id} (0-5)")
    expect(first_cb).to_be_checked()

    # (c) click second facet -> first un-checks in the DOM, label follows second
    second_cb.click()
    expect(second_cb).to_be_checked()
    expect(first_cb).not_to_be_checked()
    expect(label).to_have_text(f"{second_id} (0-5)")

    # unchecking the active facet reverts to BVP_norm
    second_cb.click()
    expect(second_cb).not_to_be_checked()
    expect(label).to_have_text("BVP_norm")

    # (d) zero console errors across all three interactions (favicon 404 is benign)
    js_errors = [e for e in errors if "favicon" not in e.lower()]
    assert not js_errors, f"console errors during facet interactions: {js_errors}"


def test_bvp_facet_click_moves_at_least_one_point(page, base_url):
    """When scored points exist, activating a facet must change at least one
    point's rendered cy (proof the redraw actually re-ran with the new
    accessor, not just that the label text changed)."""
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    points = page.locator("#scatter-quadrant circle")
    n = points.count()
    if n == 0:
        import pytest
        pytest.skip("no scored points on this corpus — nothing to move")

    driver_ids = _driver_ids(page)
    before_cys = page.eval_on_selector_all(
        "#scatter-quadrant circle", "els => els.map(e => e.getAttribute('cy'))"
    )

    page.locator(f'input.bvp-facet-toggle[data-driver-id="{driver_ids[0]}"]').click()
    page.wait_for_function(
        "() => document.getElementById('bvp-y-axis-label').textContent !== 'BVP_norm'"
    )
    after_cys = page.eval_on_selector_all(
        "#scatter-quadrant circle", "els => els.map(e => e.getAttribute('cy'))"
    )
    assert before_cys != after_cys, (
        "expected at least one point's cy to change after activating a facet "
        "(axis domain swaps [0,1] bvp_norm -> [0,5] raw score)"
    )


def test_bvp_facet_hidden_count_reported_or_all_scored(page, base_url):
    """AC3: the hint must either report a hidden-point count or state all
    points are scored for the active driver — never silent."""
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    driver_ids = _driver_ids(page)
    if not driver_ids:
        import pytest
        pytest.skip("no drivers configured")
    page.locator(f'input.bvp-facet-toggle[data-driver-id="{driver_ids[0]}"]').click()
    hint = page.locator("#bvp-facet-hint")
    expect(hint).to_contain_text("scored")
