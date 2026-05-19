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
