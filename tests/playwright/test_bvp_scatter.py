"""T-1928: /bvp static quadrant scatter — visual + structural guards.

The page has two render paths:
  empty:    no tasks/arcs have bvp_scores set → empty-state copy + quadrant
            label list (4 quadrants HV-LC/HV-HC/LV-LC/LV-HC).
  populated: ≥1 entity scored → scatter SVG + raw-data details table.

Both paths must render the page heading and the 4 quadrant tokens
somewhere in the DOM so the human can orient. Visual rhythm is
exercised by DOM-content assertions, not bare element-presence grep
(T-1575).
"""

from playwright.sync_api import expect


def test_bvp_page_renders_heading(page, base_url):
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    expect(page.locator("h2")).to_contain_text("BVP Quadrant Scatter")


def test_bvp_page_shows_four_quadrant_tokens(page, base_url):
    """The four BVP quadrant tokens (HV-LC / HV-HC / LV-LC / LV-HC) must
    appear on the page — either as scatter overlay labels (populated) or
    as the explanatory bullet list (empty state)."""
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    body = page.locator("body")
    for token in ("HV-LC", "HV-HC", "LV-LC", "LV-HC"):
        expect(body).to_contain_text(token)


def test_bvp_page_shows_driver_weights_section(page, base_url):
    """Driver weights are load-bearing — without them the math has no
    inputs. Surface them in a collapsible details element."""
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    expect(page.locator("summary", has_text="Current driver weights")).to_be_visible()


def test_bvp_page_references_cost_composite_formula(page, base_url):
    """The F8 mechanic must remain diagnosable (artefact §4). Either the
    scatter axis label (populated) or the empty-state copy must mention
    one of the three composite components."""
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    body = page.locator("body")
    has_blast_radius = body.filter(has_text="blast_radius").count() > 0
    has_tier = body.filter(has_text="tier").count() > 0
    has_effort = body.filter(has_text="effort").count() > 0
    has_bvp_confirm = body.filter(has_text="bvp confirm").count() > 0
    assert has_blast_radius or has_tier or has_effort or has_bvp_confirm, (
        "Page must mention at least one cost composite component or scoring verb"
    )


def test_bvp_link_lives_under_work_group_in_nav(page, base_url):
    """T-1575: visual rhythm — BVP belongs under 'Work' (alongside Tasks,
    Arcs, Inception), not 'Govern' or 'Architecture'."""
    page.goto(f"{base_url}/", wait_until="domcontentloaded")
    # Each <li> contains a <details> with a summary group label and a
    # nested <ul> of items. Find the Work group, assert /bvp is inside.
    work_group = page.locator("li > details").filter(
        has=page.locator("summary", has_text="Work")
    )
    expect(work_group).to_have_count(1)
    expect(work_group.locator("a[href='/bvp']")).to_have_count(1)


# ── T-1941: arc dot payload carries bvp_mode + tooltip surfaces it ──


def test_bvp_payload_carries_arc_bvp_mode(page, base_url):
    """T-1941 contract: every arc point in the embedded `<script
    id="bvp-data">` JSON payload must carry a `bvp_mode` field with one of
    the 4 mode slugs (or empty string for the unreachable defensive case).

    Reading the script element directly avoids any reliance on global
    runtime scope (the page's `payload` const and `tipHTML` are
    function-scoped, by design — not globals).
    """
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    arcs_modes = page.evaluate(
        """() => {
            const el = document.getElementById('bvp-data');
            if (!el) return null;
            const payload = JSON.parse(el.textContent);
            return (payload.arcs || []).map(a => a.bvp_mode);
        }"""
    )
    assert arcs_modes is not None, (
        "<script id='bvp-data'> element missing from /bvp page"
    )
    # Page might be empty (no scored arcs); only assert when there's data.
    if arcs_modes:
        allowed = {"", "direct-confirmed", "direct-proposed",
                   "derived-confirmed", "derived-proposed"}
        unknown = [m for m in arcs_modes if m not in allowed]
        assert not unknown, (
            f"arc payload contains unknown bvp_mode value(s): {unknown!r}"
        )
        # In the current corpus value-prioritisation renders derived-proposed;
        # at least ONE arc dot must carry a non-empty mode slug (otherwise the
        # 4-tier ladder isn't actually plumbed).
        assert any(m for m in arcs_modes), (
            f"no arc dot has a populated bvp_mode (got: {arcs_modes!r})"
        )


def test_bvp_template_includes_source_provenance_in_tooltip_builder(page, base_url):
    """T-1941: the inlined tooltip-builder JS must include the `source:`
    + `<code>${d.bvp_mode}</code>` substring AND guard on `d.kind === 'arc'`.

    We assert the source HTML (not the rendered tooltip — D3 tooltips need
    actual hover events to fire; the source contract is more reliable).
    """
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    page_html = page.content()
    # The build line in bvp.html (T-1941 addition):
    #   if (d.kind === "arc" && d.bvp_mode) { ... source: <code>${d.bvp_mode}</code> ... }
    assert 'd.kind === "arc"' in page_html or "d.kind === 'arc'" in page_html, (
        "tooltip builder missing kind=='arc' guard — task dots would falsely "
        "emit provenance label"
    )
    assert "d.bvp_mode" in page_html, (
        "tooltip builder doesn't reference d.bvp_mode — provenance won't render"
    )
    assert "source:" in page_html.lower(), (
        "tooltip builder missing 'source:' literal — provenance label absent"
    )
