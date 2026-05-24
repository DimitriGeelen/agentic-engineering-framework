"""T-2033: arc-007 nav-layout polish — computed-layout guards for sidebar + icon rail.

Pins the behaviour the static unit test cannot see (element-presence is not enough — T-1575):

  F1  in rail mode an opened group flyout is visible and within the viewport (was clipped to
      nothing because the rail's overflow-y:auto forced overflow-x to compute to auto).
  F2  neither sidebar nor rail can be scrolled horizontally at desktop width (the margin-left
      offset used to push full-width content off by 232px / 60px).
  F3  the sidebar's brand→first-group gap is tight (was 158px of empty filler rows).

Runs against the isolated conftest harness (port 3099), never :3000.
"""
import os

from playwright.sync_api import Page

ARTEFACT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "web", "static", "ux-review",
)


def _set_nav(page: Page, nav: str):
    page.evaluate("(n)=>document.documentElement.setAttribute('data-wt-nav', n)", nav)
    page.evaluate("()=>void document.documentElement.offsetWidth")


class TestNavLayoutPolish:
    def test_f1_rail_flyout_visible_and_unclipped(self, page: Page, base_url):
        page.goto(f"{base_url}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        page.set_viewport_size({"width": 1440, "height": 900})
        _set_nav(page, "rail")
        res = page.evaluate(
            """()=>{
              const det = document.querySelector('nav.site-nav details.dropdown');
              det.open = true;
              void document.documentElement.offsetWidth;
              const ul = det.querySelector('ul');
              const r = ul.getBoundingClientRect();
              const navOX = getComputedStyle(document.querySelector('nav.site-nav')).overflow;
              return { w: r.width, h: r.height, right: r.right,
                       cw: document.documentElement.clientWidth, navOverflow: navOX };
            }"""
        )
        assert res["navOverflow"] == "visible", f"rail nav must be overflow:visible, got {res['navOverflow']}"
        assert res["w"] > 0 and res["h"] > 0, "rail flyout has no box (still clipped) — F1"
        assert res["right"] <= res["cw"] + 1, f"rail flyout escapes viewport: right={res['right']} cw={res['cw']}"

    def test_f2_no_horizontal_scroll_sidebar_and_rail(self, page: Page, base_url):
        page.goto(f"{base_url}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        page.set_viewport_size({"width": 1440, "height": 900})
        for nav in ("sidebar", "rail"):
            _set_nav(page, nav)
            res = page.evaluate(
                """()=>{
                  window.scrollTo(0,0);
                  window.scrollTo(9999,0);
                  const sx = window.scrollX;
                  window.scrollTo(0,0);
                  return { scrolledX: sx,
                           overflowX: getComputedStyle(document.documentElement).overflowX };
                }"""
            )
            # root overflow-x:clip suppresses the visible scrollbar; allow ≤2px sub-pixel
            # rounding of percentage-width content (the 232/60px gross bug must be gone).
            assert res["overflowX"] == "clip", f"{nav}: root overflow-x must be clip, got {res['overflowX']}"
            assert res["scrolledX"] <= 2, f"{nav}: horizontal scroll {res['scrolledX']}px (F2 regression)"

    def test_f3_sidebar_gap_is_tight(self, page: Page, base_url):
        page.goto(f"{base_url}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        page.set_viewport_size({"width": 1440, "height": 900})
        _set_nav(page, "sidebar")
        gap = page.evaluate(
            """()=>{
              const b = document.querySelector('nav.site-nav .brand');
              const f = document.querySelector('nav.site-nav .nav-items details summary');
              return Math.round(f.getBoundingClientRect().top - b.getBoundingClientRect().bottom);
            }"""
        )
        # was 158px (two empty 56px filler rows); now just the brand's bottom spacing.
        assert gap < 60, f"sidebar brand→first-group gap still large: {gap}px (F3 regression)"

    def test_capture_review_artefacts(self, page: Page, base_url):
        os.makedirs(ARTEFACT_DIR, exist_ok=True)
        page.goto(f"{base_url}/", timeout=60000)
        page.wait_for_load_state("domcontentloaded")
        page.set_viewport_size({"width": 1440, "height": 900})
        _set_nav(page, "sidebar")
        page.wait_for_timeout(200)
        out = os.path.join(ARTEFACT_DIR, "T-2033-sidebar-after.png")
        page.screenshot(path=out)
        assert os.path.exists(out)
        _set_nav(page, "rail")
        page.evaluate("()=>{const d=document.querySelector('nav.site-nav details.dropdown'); d.open=true;}")
        page.wait_for_timeout(200)
        out2 = os.path.join(ARTEFACT_DIR, "T-2033-rail-flyout-after.png")
        page.screenshot(path=out2)
        assert os.path.exists(out2)
