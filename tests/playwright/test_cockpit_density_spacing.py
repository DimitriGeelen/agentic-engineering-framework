"""Playwright guard for T-2029 — cockpit spacing responds to the density axis.

Before S3b the density control's SPACING axis was inert (no template consumed it). Now every
cockpit rem/px padding/margin/gap is calc(<value> * var(--wt-density-scale)), so spacing
scales 0.875 / 1 / 1.125 for compact / cozy / comfortable.

Subtlety (measured, not assumed — T-2031 lesson): the density control ALSO shifts the root
font-size (--pico-font-size 100/112.5/125%), so rem-based px values move for two reasons at
once. To isolate the density-scale factor we normalise the measured margin by the root
font-size at each density — that cancels the rem-anchor shift and leaves the pure scale ratio.

Runs against the isolated port-3099 harness (conftest), never :3000.
"""
import os

from playwright.sync_api import Page

from tests.playwright.target import TEST_URL
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)


def _measure(page: Page, density: str):
    """Return (margin_bottom_px, root_font_px) for the always-present .wt-header."""
    page.evaluate(
        "(d)=>document.documentElement.setAttribute('data-wt-density', d)", density
    )
    page.wait_for_timeout(400)  # let the spacing transition settle
    return page.evaluate(
        """()=>{
          const h=document.querySelector('.wt-header');
          const mb=parseFloat(getComputedStyle(h).marginBottom);
          const root=parseFloat(getComputedStyle(document.documentElement).fontSize);
          return {mb, root};
        }"""
    )


class TestCockpitDensitySpacing:
    def test_cozy_is_baseline_and_compact_scales(self, page: Page):
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        assert page.locator(".wt-header").count() == 1

        cozy = _measure(page, "cozy")
        compact = _measure(page, "compact")

        # .wt-header margin-bottom = calc(1.5rem * density-scale). Normalising by the root
        # font-size gives the value in rem units, isolating the density-scale from the
        # rem-anchor shift the font axis also causes.
        cozy_rem = cozy["mb"] / cozy["root"]
        compact_rem = compact["mb"] / compact["root"]

        # Cozy (scale=1) is the unscaled baseline: 1.5rem.
        assert abs(cozy_rem - 1.5) < 0.05, f"cozy not baseline 1.5rem: {cozy_rem:.3f}rem"
        # Compact applies density-scale 0.875 → 1.5 * 0.875 = 1.3125rem.
        assert abs(compact_rem - 1.5 * 0.875) < 0.05, (
            f"compact density-scale not ~0.875: {compact_rem:.3f}rem "
            f"(ratio {compact_rem / cozy_rem:.3f})"
        )

    def test_comfortable_loosens(self, page: Page):
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        cozy = _measure(page, "cozy")
        comfortable = _measure(page, "comfortable")
        cozy_rem = cozy["mb"] / cozy["root"]
        comf_rem = comfortable["mb"] / comfortable["root"]
        # Comfortable applies density-scale 1.125 → 1.5 * 1.125 = 1.6875rem.
        assert abs(comf_rem - 1.5 * 1.125) < 0.05, (
            f"comfortable density-scale not ~1.125: {comf_rem:.3f}rem"
        )

    def test_capture_review_artefacts(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        for density in ("compact", "cozy", "comfortable"):
            page.evaluate(
                "(d)=>document.documentElement.setAttribute('data-wt-density', d)", density
            )
            page.wait_for_timeout(400)
            out = os.path.join(ARTEFACT_DIR, f"T-2029-cockpit-density-{density}.png")
            page.screenshot(path=out)
            assert os.path.exists(out)
