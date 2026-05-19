"""T-1930: /arcs/<id> BVP signals extensions — visual + structural guards.

The arc detail page must render a "BVP signals" section that:
  - Always renders for any arc (even with no scores or proposed drivers).
  - Shows the arc-level BVP_norm + BVP_raw stat boxes.
  - Surfaces an "Approve none" form (R6 — ≥30 chars justification).
  - Includes the per-driver breakdown collapsible.

T-1575: DOM-content assertions, not bare element-presence grep.
"""

from playwright.sync_api import expect


# Use the value-prioritisation arc as the test target — it exists in the
# corpus at the time of writing and is the canonical arc-006 detail page.
_ARC_SLUG = "value-prioritisation"


def test_arc_detail_renders_bvp_signals_section(page, base_url):
    page.goto(f"{base_url}/arcs/{_ARC_SLUG}", wait_until="domcontentloaded")
    section = page.locator("#bvp-signals")
    expect(section).to_be_visible()
    expect(section).to_have_attribute("data-arc-bvp", _ARC_SLUG)


def test_arc_detail_bvp_section_has_h2_heading(page, base_url):
    page.goto(f"{base_url}/arcs/{_ARC_SLUG}", wait_until="domcontentloaded")
    expect(page.locator("#bvp-signals h2", has_text="BVP signals")).to_be_visible()


def test_arc_detail_shows_norm_and_raw_stat_boxes(page, base_url):
    page.goto(f"{base_url}/arcs/{_ARC_SLUG}", wait_until="domcontentloaded")
    bvp = page.locator("#bvp-signals")
    expect(bvp.locator(".stat-box", has_text="Arc BVP_norm")).to_be_visible()
    expect(bvp.locator(".stat-box", has_text="Arc BVP_raw")).to_be_visible()


def test_arc_detail_shows_per_driver_breakdown(page, base_url):
    page.goto(f"{base_url}/arcs/{_ARC_SLUG}", wait_until="domcontentloaded")
    expect(
        page.locator("#bvp-signals summary", has_text="Per-driver breakdown")
    ).to_be_visible()


def test_arc_detail_shows_approve_none_form(page, base_url):
    """Approve none must be discoverable; required justification ≥30 chars."""
    page.goto(f"{base_url}/arcs/{_ARC_SLUG}", wait_until="domcontentloaded")
    expect(
        page.locator("#bvp-signals summary", has_text="Approve none")
    ).to_be_visible()
    form = page.locator(f"#bvp-signals form[action='/api/arc/{_ARC_SLUG}/approve-none']")
    expect(form).to_have_count(1)
    textarea = form.locator("textarea[name='justification']")
    expect(textarea).to_have_attribute("minlength", "30")
    expect(textarea).to_have_attribute("required", "")


def test_arc_detail_approve_none_short_justification_rejected(page, base_url):
    """POST with <30-char justification must be rejected by the server,
    not silently accepted (R6)."""
    resp = page.request.post(
        f"{base_url}/api/arc/{_ARC_SLUG}/approve-none",
        form={"justification": "too short"},
    )
    assert resp.status == 400, f"expected 400, got {resp.status}: {resp.text()}"
    assert "≥30 characters" in resp.text() or "30 characters" in resp.text()


def test_arc_detail_coherence_section_renders(page, base_url):
    """Coherence area renders even when empty (passing state visible)."""
    page.goto(f"{base_url}/arcs/{_ARC_SLUG}", wait_until="domcontentloaded")
    bvp = page.locator("#bvp-signals")
    # Either a "Coherence warnings" h3 or the passing-state muted note —
    # one of the two must appear.
    has_warn_header = bvp.locator("h3", has_text="Coherence warnings").count() > 0
    has_passing_note = bvp.filter(has_text="No coherence warnings").count() > 0
    assert has_warn_header or has_passing_note, (
        "Coherence area should render either warnings or passing note"
    )
