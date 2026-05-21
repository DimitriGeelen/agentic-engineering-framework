"""T-1977: /arcs/<id> live scoped-driver weight sliders — DOM + behavioural guards.

The sliders section must render whenever the arc has approved scoped_drivers.
Slider drag must update the live-weight label, set the changes payload, and
enable the Commit button. Commit POST returns 400 on rationale <30 chars.

DOM-content + behavioural assertions per T-1575 (not bare element grep).
Mirrors test_bvp_sliders.py pattern at arc scope.
"""

import json

from playwright.sync_api import expect


# value-prioritisation arc (arc-006) currently has 3 approved scoped drivers
# at the time of writing. Use it as the canonical fixture.
_ARC_SLUG = "value-prioritisation"


def test_arc_scoped_sliders_section_renders(page, base_url):
    page.goto(f"{base_url}/arcs/{_ARC_SLUG}", wait_until="domcontentloaded")
    table = page.locator("#scoped-sliders-table")
    expect(table).to_be_visible()


def test_arc_scoped_sliders_one_per_approved_driver(page, base_url):
    """Each approved scoped driver gets one slider."""
    page.goto(f"{base_url}/arcs/{_ARC_SLUG}", wait_until="domcontentloaded")
    sliders = page.locator(".scoped-slider")
    n = sliders.count()
    # Arc has 1-3 scoped drivers (M2 cap). All three present at time of writing.
    assert 1 <= n <= 3, f"expected 1-3 scoped sliders, got {n}"


def test_arc_scoped_slider_has_range_input(page, base_url):
    """T-1575 DOM assertion — slider must be a real <input type=range>, not a styled div."""
    page.goto(f"{base_url}/arcs/{_ARC_SLUG}", wait_until="domcontentloaded")
    first_slider = page.locator(".scoped-slider").first
    assert first_slider.evaluate("(el) => el.tagName") == "INPUT"
    assert first_slider.get_attribute("type") == "range"
    assert first_slider.get_attribute("min") == "1"
    assert first_slider.get_attribute("max") == "6"


def test_arc_scoped_commit_form_exists(page, base_url):
    page.goto(f"{base_url}/arcs/{_ARC_SLUG}", wait_until="domcontentloaded")
    form = page.locator("#scoped-commit-form")
    expect(form).to_be_visible()
    # Route must point at the new endpoint (T-1977).
    assert form.get_attribute("action") == f"/api/arc/{_ARC_SLUG}/set-scoped-weight"
    # Rationale textarea + commit button must be present.
    expect(form.locator("textarea[name='rationale']")).to_be_visible()
    expect(form.locator("#scoped-commit-btn")).to_be_visible()


def test_arc_scoped_slider_drag_updates_live_label_and_enables_commit(page, base_url):
    """Drag the first slider one step; live label updates and commit unlocks."""
    page.goto(f"{base_url}/arcs/{_ARC_SLUG}", wait_until="domcontentloaded")
    commit_btn = page.locator("#scoped-commit-btn")
    expect(commit_btn).to_be_disabled()

    slider = page.locator(".scoped-slider").first
    driver = slider.get_attribute("data-driver")
    original = int(slider.evaluate("(el) => el.value"))
    new_val = original + 1 if original < 6 else original - 1
    slider.evaluate(
        "(el, v) => { el.value = String(v); el.dispatchEvent(new Event('input', {bubbles: true})); }",
        new_val,
    )

    live = page.locator(f".scoped-live-weight[data-driver='{driver}']")
    assert live.text_content() == str(new_val)
    expect(commit_btn).to_be_enabled()

    payload = page.locator("#scoped-changes-payload").get_attribute("value")
    changes = json.loads(payload)
    assert {"name": driver, "weight": new_val} in changes
