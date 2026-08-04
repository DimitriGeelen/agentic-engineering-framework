"""Playwright guard for T-2027 (arc-007 S5a) — Arcs badges re-theme per palette.

Proves the browser behaviour: the `.badge-warn` rule on /arcs (now
`background:var(--wt-warn)`) resolves to a different computed colour when the
foundation palette (`[data-wt-palette]` on <html>) switches — i.e. the Arcs section
honours the selected preset (the human's 2026-05-24 decision).

The OK/WARN badges only render for certain arc states, so we use the probe-element
technique (T-2025): append a throwaway `<span class="badge badge-warn">` and measure
the live stylesheet rule's computed background across paper↔console. Captures a review
screenshot under a distinctive palette for the Human [REVIEW].

Read-only page → inherently net-zero. Runs against the isolated port-3099 harness
(conftest), never :3000.
"""
import os

from playwright.sync_api import Page

from tests.playwright.target import TEST_URL
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)


def _set_palette(page: Page, name: str):
    page.evaluate(f"() => document.documentElement.setAttribute('data-wt-palette', '{name}')")
    page.wait_for_timeout(80)  # let the style engine recalc


def _probe_bg(page: Page, classes: str) -> str:
    """Append a throwaway span with the given classes and read its computed background."""
    return page.evaluate(
        """(cls) => {
            let el = document.getElementById('__probe');
            if (!el) {
                el = document.createElement('span');
                el.id = '__probe';
                el.textContent = 'probe';
                document.body.appendChild(el);
            }
            el.className = cls;
            return getComputedStyle(el).backgroundColor;
        }""",
        classes,
    )


class TestArcsPagesTokens:
    def test_warn_badge_rethemes_per_palette(self, page: Page):
        page.goto(f"{TEST_URL}/arcs", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        _set_palette(page, "paper")
        c_paper = _probe_bg(page, "badge badge-warn")
        _set_palette(page, "console")
        c_console = _probe_bg(page, "badge badge-warn")
        assert c_paper != c_console, (
            f"arcs .badge-warn did not re-theme: {c_paper!r} == {c_console!r}"
        )
        assert c_paper.startswith("rgb"), f"unexpected colour value: {c_paper!r}"

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        page.goto(f"{TEST_URL}/arcs", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        _set_palette(page, "bone")  # distinctive amber palette so re-theming is visible
        page.wait_for_timeout(150)
        out = os.path.join(ARTEFACT_DIR, "T-2027-arcs-pages-tokens.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 900})
        assert os.path.exists(out)
