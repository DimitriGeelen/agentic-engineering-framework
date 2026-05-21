"""T-1970: Pin badge contrast on /arcs surfaces against WCAG AA (4.5:1).

Origin: T-1968 v1 shipped an arc-badge contrast fix that read like a fix but
left `--pico-primary` as the text colour — a Pico variable whose value at
runtime is a link colour, not the page text colour. Playwright caught it.
T-1970 extended the sweep to `.badge-info`/`.badge-ok`/`.badge-muted` which
exhibited the same Pico-variable-name anti-pattern (1.00 / 3.55 / 4.44
contrast respectively).

This test pins the fix: any element with the badge classes shown below
must compute ≥4.5 contrast between `color` and the effective background.
Grep-based template checks cannot catch the "rgb(1,114,173) on rgb(1,114,173)"
class of bug — only computed-style sampling can. T-1575 codifies this rule.
"""
import pytest
from playwright.sync_api import Page

TEST_URL = "http://localhost:3099"

# Per T-1970: classes we shipped fixes for. Their contrast is pinned in
# arc_detail.html + arcs_index.html. Any future edit that drops contrast
# below 4.5 will fail this test.
TARGET_CLASSES = [".badge-info", ".badge-ok", ".badge-muted"]

# WCAG AA for normal text. Large text gets 3.0; we apply the stricter bar
# because badges are small (0.7-0.8em).
WCAG_AA = 4.5


CONTRAST_PROBE = r"""
(cls) => {
  function lum(rgb) {
    const m = rgb.match(/\d+/g).map(Number);
    const [r,g,b] = m.slice(0,3).map(c => {
      c /= 255;
      return c <= 0.03928 ? c/12.92 : Math.pow((c+0.055)/1.055, 2.4);
    });
    return 0.2126*r + 0.7152*g + 0.0722*b;
  }
  function contrast(a, b) {
    const la = lum(a), lb = lum(b);
    const [hi, lo] = la > lb ? [la, lb] : [lb, la];
    return (hi + 0.05) / (lo + 0.05);
  }
  const els = document.querySelectorAll(cls);
  if (els.length === 0) return { count: 0, contrast: null };
  const el = els[0];
  const cs = getComputedStyle(el);
  return {
    count: els.length,
    fg: cs.color,
    bg: cs.backgroundColor,
    contrast: contrast(cs.color, cs.backgroundColor),
    sample: el.textContent.trim().slice(0, 40),
  };
}
"""


class TestBadgeContrast:
    """Pin /arcs surface badge contrast against WCAG AA."""

    @pytest.mark.parametrize("cls", TARGET_CLASSES)
    def test_arc_detail_badge_contrast(self, page: Page, cls: str):
        page.goto(f"{TEST_URL}/arcs/arc-006")
        page.wait_for_load_state("domcontentloaded")
        result = page.evaluate(CONTRAST_PROBE, cls)
        if result["count"] == 0:
            pytest.skip(f"No {cls} present on /arcs/arc-006 in current fixture")
        assert result["contrast"] >= WCAG_AA, (
            f"{cls} on /arcs/arc-006 — contrast {result['contrast']:.2f} "
            f"below WCAG AA {WCAG_AA}. fg={result['fg']} bg={result['bg']} "
            f"sample={result['sample']!r}"
        )

    @pytest.mark.parametrize("cls", TARGET_CLASSES)
    def test_arcs_index_badge_contrast(self, page: Page, cls: str):
        page.goto(f"{TEST_URL}/arcs")
        page.wait_for_load_state("domcontentloaded")
        result = page.evaluate(CONTRAST_PROBE, cls)
        if result["count"] == 0:
            pytest.skip(f"No {cls} present on /arcs in current fixture")
        assert result["contrast"] >= WCAG_AA, (
            f"{cls} on /arcs — contrast {result['contrast']:.2f} "
            f"below WCAG AA {WCAG_AA}. fg={result['fg']} bg={result['bg']} "
            f"sample={result['sample']!r}"
        )
