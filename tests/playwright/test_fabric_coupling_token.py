"""Playwright guard for T-2028 (arc-007 S5b) — fabric coupling-note danger token re-themes.

The coupling-note (`color:var(--wt-danger)`) only renders when a component carries a
coupling_note, so we use the probe-element technique (T-2025): on the /fabric page
(where foundations.css is loaded) append a throwaway element styled with
`color:var(--wt-danger)` and assert its computed colour differs paper↔console — i.e.
the danger token follows the selected preset. Satisfies T-1575 (not source-grep alone).

Read-only page → net-zero. Runs against the isolated port-3099 harness, never :3000.
"""
import os

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)


def _set_palette(page: Page, name: str):
    page.evaluate(f"() => document.documentElement.setAttribute('data-wt-palette', '{name}')")
    page.wait_for_timeout(80)


def _probe_color(page: Page) -> str:
    return page.evaluate(
        """() => {
            let el = document.getElementById('__probe');
            if (!el) {
                el = document.createElement('p');
                el.id = '__probe';
                el.textContent = 'coupling probe';
                el.style.color = 'var(--wt-danger)';
                document.body.appendChild(el);
            }
            return getComputedStyle(el).color;
        }"""
    )


class TestFabricCouplingToken:
    def test_danger_token_rethemes_per_palette(self, page: Page):
        page.goto(f"{TEST_URL}/fabric", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        _set_palette(page, "paper")
        c_paper = _probe_color(page)
        _set_palette(page, "console")
        c_console = _probe_color(page)
        assert c_paper != c_console, (
            f"--wt-danger did not re-theme on /fabric: {c_paper!r} == {c_console!r}"
        )
        assert c_paper.startswith("rgb"), f"unexpected colour value: {c_paper!r}"

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        page.goto(f"{TEST_URL}/fabric", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        _set_palette(page, "bone")
        page.wait_for_timeout(150)
        out = os.path.join(ARTEFACT_DIR, "T-2028-fabric-coupling-token.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 900})
        assert os.path.exists(out)
