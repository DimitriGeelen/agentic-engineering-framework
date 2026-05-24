"""Playwright guard for T-2032 — the settings gear is visible and navigates to the page.

The bug: /settings/appearance was reachable only by typing the URL (no nav affordance). This
test asserts the gear icon is present+visible in the top bar, that its colour contrasts the
bar (T-2031 white-on-white lesson applies to nav chrome), and that clicking it lands on
/settings/appearance. DOM/navigation assertions, not grep (T-1575).

Runs against the isolated port-3099 harness (conftest), never :3000.
"""
import os

from playwright.sync_api import Page, expect

TEST_URL = "http://localhost:3099"
ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)


class TestSettingsNavLink:
    def test_gear_visible_in_topbar(self, page: Page):
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        gear = page.locator("li.nav-settings a")
        expect(gear).to_have_count(1)
        expect(gear).to_be_visible()
        expect(page.locator("li.nav-settings svg")).to_be_visible()

    def test_gear_navigates_to_appearance(self, page: Page):
        # The body is hx-boost="true" — nav is an AJAX swap + history push, not a full
        # page load — so wait for the URL to change rather than for domcontentloaded.
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        page.locator("li.nav-settings a").click()
        page.wait_for_url("**/settings/appearance", timeout=10000)
        assert "/settings/appearance" in page.url, f"gear did not navigate; url={page.url}"

    def test_gear_contrasts_bar_on_light_palette(self, page: Page):
        # T-2031 regression class: nav-chrome icon must not be same-colour as its background.
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        page.evaluate(
            "()=>{document.documentElement.setAttribute('data-wt-palette','paper');"
            "document.documentElement.setAttribute('data-theme','light');}"
        )
        page.wait_for_timeout(400)
        r = page.evaluate(
            """()=>{
              const a=document.querySelector('li.nav-settings a');
              const color=getComputedStyle(a).color;
              let el=a,bg='rgba(0, 0, 0, 0)';
              while(el){const b=getComputedStyle(el).backgroundColor;
                if(b&&b!=='rgba(0, 0, 0, 0)'&&b!=='transparent'){bg=b;break;} el=el.parentElement;}
              return {color, bg};
            }"""
        )
        assert r["color"] != r["bg"], (
            f"gear invisible in paper/light: color {r['color']} == bg {r['bg']}"
        )

    def test_capture_review_artefact(self, page: Page):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        page.goto(f"{TEST_URL}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        out = os.path.join(ARTEFACT_DIR, "T-2032-settings-gear-topbar.png")
        page.screenshot(path=out, clip={"x": 880, "y": 0, "width": 400, "height": 110})
        assert os.path.exists(out)
