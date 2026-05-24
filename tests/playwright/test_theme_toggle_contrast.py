"""Playwright regression guard for T-2031 — dark-mode toggle stays visible on light palettes.

The bug: in the `paper` palette + `light` mode the toggle icon was white (#fff, from Pico's
button rule overriding --pico-color with the accent-ink) on a white surface → invisible.
This test sets that exact combo and asserts the toggle's computed colour differs from the
background colour behind it (i.e. it is not white-on-white). Also checks a dark combo so the
fix isn't "always dark".

Runs against the isolated port-3099 harness (conftest), never :3000.
"""
import os

from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)


def _apply(page: Page, palette: str, mode: str):
    page.evaluate(
        "([p,m])=>{document.documentElement.setAttribute('data-wt-palette',p);"
        "document.documentElement.setAttribute('data-theme',m);}",
        [palette, mode],
    )
    page.wait_for_timeout(400)  # let the colour transition settle


def _toggle_vs_bg(page: Page):
    return page.evaluate(
        """()=>{
          const t=document.querySelector('.theme-toggle');
          const color=getComputedStyle(t).color;
          let el=t,bg='rgba(0, 0, 0, 0)';
          while(el){const b=getComputedStyle(el).backgroundColor;
            if(b&&b!=='rgba(0, 0, 0, 0)'&&b!=='transparent'){bg=b;break;} el=el.parentElement;}
          return {color, bg};
        }"""
    )


class TestThemeToggleContrast:
    def test_visible_in_paper_light(self, page: Page):
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        assert page.locator(".theme-toggle").count() == 1
        _apply(page, "paper", "light")
        r = _toggle_vs_bg(page)
        assert r["color"] != r["bg"], (
            f"toggle invisible in paper/light: color {r['color']} == bg {r['bg']}"
        )

    def test_visible_in_console_dark(self, page: Page):
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        _apply(page, "console", "dark")
        r = _toggle_vs_bg(page)
        assert r["color"] != r["bg"], (
            f"toggle invisible in console/dark: color {r['color']} == bg {r['bg']}"
        )

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        _apply(page, "paper", "light")
        out = os.path.join(ARTEFACT_DIR, "T-2031-toggle-paper-light.png")
        page.screenshot(path=out, clip={"x": 900, "y": 0, "width": 380, "height": 110})
        assert os.path.exists(out)
