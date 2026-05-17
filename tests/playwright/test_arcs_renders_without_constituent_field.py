"""T-1851 (T-NEW-4): Watchtower /arcs/<slug> renders cleanly for arcs that
omit the legacy `constituent_tasks:` frontmatter field.

Background: T-1849 introduced arc_id: as the canonical immutable id;
T-1850 migrated existing arcs; T-1851 deprecates the per-arc
`constituent_tasks:` list in favour of arc_id-frontmatter reverse lookup.
Arcs created AFTER T-1851 ships will not have the field — the renderer
must tolerate its absence (200 + no Python Traceback in the page body).

Fixture writes a synthetic arc YAML to .context/arcs/, yields, cleans up.
The Watchtower process reads filesystem live, so no restart is needed.

Render-surface gate P-013 (T-1766): web/blueprints/arcs.py is a render
surface; this test is the DOM-content assertion (T-1575) that pins the
no-traceback contract.
"""
import os
import pytest

_SYNTH_SLUG = "t1851-render-check-synthetic"


@pytest.fixture
def synthetic_arc_no_constituent_tasks():
    """Create an arc YAML without `constituent_tasks:`; remove on teardown."""
    project_root = os.environ.get(
        "PROJECT_ROOT",
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    )
    arc_path = os.path.join(project_root, ".context", "arcs", f"{_SYNTH_SLUG}.yaml")
    body = (
        f"id: arc-999-t1851-synth\n"
        f"slug: {_SYNTH_SLUG}\n"
        f"name: \"T-1851 render-check (synthetic, deleted on teardown)\"\n"
        f"status: draft\n"
        f"created_at: 2026-05-18T00:00:00Z\n"
        f"headline_mechanic: \"user renders /arcs/{_SYNTH_SLUG} with no traceback\"\n"
        # NOTE: deliberately no `constituent_tasks:` field — that's the contract.
    )
    with open(arc_path, "w") as f:
        f.write(body)
    try:
        yield _SYNTH_SLUG
    finally:
        try:
            os.unlink(arc_path)
        except FileNotFoundError:
            pass


def test_arcs_detail_renders_without_constituent_tasks(
    page, base_url, synthetic_arc_no_constituent_tasks
):
    slug = synthetic_arc_no_constituent_tasks
    response = page.goto(f"{base_url}/arcs/{slug}", wait_until="domcontentloaded")
    assert response is not None, f"No response from /arcs/{slug}"
    assert response.status == 200, (
        f"/arcs/{slug} returned {response.status} — expected 200. "
        "Renderer likely tripped on missing `constituent_tasks:` field."
    )
    body_text = page.locator("body").text_content() or ""
    # Flask debug tracebacks render "Traceback (most recent call last):" in body.
    # In production-mode 500s the page is "Internal Server Error" without that
    # phrase — guard both shapes.
    assert "Traceback" not in body_text, (
        f"/arcs/{slug} body contains a Python Traceback — renderer crashed:\n"
        f"{body_text[:500]}"
    )
    assert "Internal Server Error" not in body_text, (
        f"/arcs/{slug} rendered a 500 error page — renderer crashed silently."
    )
    # Sanity: the synthetic arc's name appears, proving the body was actually
    # rendered from this arc's data (not a generic 200 from a cached / error page).
    assert "T-1851 render-check" in body_text, (
        f"Synthetic arc's name not found on /arcs/{slug} — body may be "
        f"a generic shell or error page rather than the arc detail."
    )


def test_legacy_arc_with_constituent_tasks_still_renders(page, base_url):
    """Regression guard — the in-tree migrated arcs (which still carry
    constituent_tasks: for backward compat until T-1850 sweeps them) must
    keep rendering. T-1851 must not break the legacy shape."""
    response = page.goto(f"{base_url}/arcs/arc-grooming", wait_until="domcontentloaded")
    assert response is not None and response.status == 200
    body_text = page.locator("body").text_content() or ""
    assert "Traceback" not in body_text
    assert "Internal Server Error" not in body_text
