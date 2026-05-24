"""Playwright guard for T-2025 (arc-007 S3c) — approvals stylesheet re-themes per palette.

Proves the browser behaviour: the approvals page's tokenised rules (e.g.
`.badge-approved { color: var(--wt-success) }`) change their computed colour when the
foundation palette (`[data-wt-palette]` on <html>) switches — i.e. the page honours the
selected preset (the human's 2026-05-24 decision). Because badge/card elements only
render when approvals exist, the re-theme assertion uses a probe element carrying the
real class (it picks up the page's live stylesheet rule); the review screenshot captures
the actual page under a distinctive palette for the Human [REVIEW] (T-1575).

Read-only page → inherently net-zero. Runs against the isolated port-3099 harness
(conftest), never :3000.
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
    page.wait_for_timeout(80)  # let the style engine recalc


def _probe_color(page: Page, css_class: str) -> str:
    """Computed text colour of a throwaway element carrying the page's class."""
    return page.evaluate(
        """(cls) => {
            const el = document.createElement('span');
            el.className = cls;
            el.textContent = 'probe';
            document.body.appendChild(el);
            const c = getComputedStyle(el).color;
            el.remove();
            return c;
        }""",
        css_class,
    )


class TestApprovalsStyleTokens:
    def test_badge_rule_rethemes_per_palette(self, page: Page):
        page.goto(f"{TEST_URL}/approvals", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        _set_palette(page, "paper")
        c_paper = _probe_color(page, "status-badge badge-approved")
        _set_palette(page, "console")
        c_console = _probe_color(page, "status-badge badge-approved")
        assert c_paper != c_console, (
            f"approvals .badge-approved did not re-theme: {c_paper!r} == {c_console!r}"
        )
        assert c_paper.startswith("rgb"), f"unexpected colour value: {c_paper!r}"

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        page.goto(f"{TEST_URL}/approvals", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        _set_palette(page, "bone")  # distinctive amber palette so re-theming is visible
        page.wait_for_timeout(150)
        out = os.path.join(ARTEFACT_DIR, "T-2025-approvals-style-tokens.png")
        page.screenshot(path=out, clip={"x": 0, "y": 0, "width": 1280, "height": 900})
        assert os.path.exists(out)
