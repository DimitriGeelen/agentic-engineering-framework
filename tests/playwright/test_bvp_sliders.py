"""T-1929: /bvp live weight sliders + commit — visual + behavioural guards.

The sliders section must render whenever the policy has drivers,
independent of whether any task/arc is scored. Slider drag must
update the live-weight label and enable the Commit button; reset
must restore server values. Commit POST must enforce R6 (≥30-char
rationale) server-side and reject short payloads.

DOM-content + behavioural assertions per T-1575 (not bare element grep).
"""

from playwright.sync_api import expect


def test_bvp_sliders_section_renders(page, base_url):
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    expect(page.locator("#bvp-sliders")).to_be_visible()
    expect(page.locator("#bvp-sliders h3", has_text="Live weight sliders")).to_be_visible()


def test_bvp_sliders_one_per_driver(page, base_url):
    """Each policy driver gets one slider — the default policy has D1-D4."""
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    sliders = page.locator(".bvp-slider")
    # Default policy ships D1, D2, D3, D4 (and possibly free drivers).
    # We assert ≥4, not exactly 4, so a free driver doesn't break the test.
    n = sliders.count()
    assert n >= 4, f"expected ≥4 sliders for D1-D4, got {n}"


def test_bvp_slider_drag_updates_live_label_and_enables_commit(page, base_url):
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    # Commit button starts disabled (no diff yet)
    commit_btn = page.locator("#bvp-commit-btn")
    expect(commit_btn).to_be_disabled()
    # Move D2 slider via setting its value + dispatching the input event
    slider = page.locator(".bvp-slider[data-driver='D2']")
    slider.evaluate(
        "(el) => { el.value = String(Number(el.value) + 1); el.dispatchEvent(new Event('input', {bubbles: true})); }"
    )
    # Commit button now enabled
    expect(commit_btn).to_be_enabled()
    # Live label reflects the new weight
    server_weight_el = page.locator("#bvp-sliders tr[data-driver='D2'] .server-weight")
    live_weight_el   = page.locator("#bvp-sliders tr[data-driver='D2'] .live-weight")
    server = int(server_weight_el.text_content().strip())
    live   = int(live_weight_el.text_content().strip())
    assert live == server + 1, f"expected live={server + 1}, got {live}"


def test_bvp_reset_restores_server_values(page, base_url):
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    slider = page.locator(".bvp-slider[data-driver='D1']")
    slider.evaluate(
        "(el) => { el.value = '1'; el.dispatchEvent(new Event('input', {bubbles: true})); }"
    )
    expect(page.locator("#bvp-commit-btn")).to_be_enabled()
    page.locator("#bvp-reset-btn").click()
    expect(page.locator("#bvp-commit-btn")).to_be_disabled()
    server_weight = int(
        page.locator("#bvp-sliders tr[data-driver='D1'] .server-weight").text_content().strip()
    )
    live = int(
        page.locator("#bvp-sliders tr[data-driver='D1'] .live-weight").text_content().strip()
    )
    assert live == server_weight, "reset should restore server values"


def test_bvp_commit_short_rationale_rejected_server_side(page, base_url):
    """R6: POST with <30-char rationale must be rejected — not silently
    accepted (server-side enforcement, not just UI minlength)."""
    resp = page.request.post(
        f"{base_url}/api/bvp/commit-weights",
        form={
            "rationale": "too short",
            "changes": '[{"driver":"D1","weight":8}]',
        },
    )
    assert resp.status == 400, f"expected 400, got {resp.status}: {resp.text()}"
    assert "30 characters" in resp.text() or "≥30" in resp.text()


def test_bvp_commit_bad_driver_name_rejected(page, base_url):
    """Driver name must match the regex; injection-style values rejected."""
    rationale = "a" * 35
    resp = page.request.post(
        f"{base_url}/api/bvp/commit-weights",
        form={
            "rationale": rationale,
            "changes": '[{"driver":"D1 ; rm -rf /","weight":8}]',
        },
    )
    assert resp.status == 400, f"expected 400, got {resp.status}: {resp.text()}"


def test_bvp_commit_weight_out_of_range_rejected(page, base_url):
    rationale = "validating weight bounds 0-9 inclusive only"
    resp = page.request.post(
        f"{base_url}/api/bvp/commit-weights",
        form={
            "rationale": rationale,
            "changes": '[{"driver":"D1","weight":99}]',
        },
    )
    assert resp.status == 400


def test_bvp_commit_form_textarea_has_minlength(page, base_url):
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    textarea = page.locator("#bvp-commit-form textarea[name='rationale']")
    expect(textarea).to_have_attribute("minlength", "30")
    expect(textarea).to_have_attribute("required", "")
