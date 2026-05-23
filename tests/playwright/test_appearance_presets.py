"""T-1999: regression guard for the /settings/appearance preset JS (arc-007 S1).

Origin bug (T-1988): a malformed ternary in appearance.html's inline <script>
threw `SyntaxError: Unexpected token ';'`, aborting the whole IIFE. The page
still returned HTTP 200 with all 6 presets present, so curl/grep checks (and
S1's own ACs) passed — but EVERY preset/axis button was inert because no click
handler attached. Only executing the JS in a real browser surfaced it.

These tests execute the JS, which is the coverage that was missing:
  - clicking a preset re-themes <html> (palette/type/mode attributes flip)
  - the choice persists across navigation to another page (saved per-browser)
  - no JS console errors on load (a future SyntaxError shows here directly)
"""
from __future__ import annotations


def _html_attrs(page):
    return page.evaluate(
        "() => { const h=document.documentElement, o={};"
        " for (const a of h.attributes) o[a.name]=a.value; return o; }"
    )


def test_appearance_preset_click_rethemes(page, base_url):
    """Clicking the Console preset must flip <html> to dark/console/plex.

    If the inline script throws (the origin bug), no click handler attaches and
    the attributes never change — this assertion fails. The console-error check
    catches a SyntaxError even more directly.
    """
    errors = []
    page.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
    page.goto(f"{base_url}/settings/appearance", wait_until="domcontentloaded")

    before = _html_attrs(page)
    assert before.get("data-wt-palette") != "console", "unexpected pre-set Console state"

    page.click('button[data-preset="console"]')
    page.wait_for_function(
        "() => document.documentElement.getAttribute('data-wt-palette') === 'console'"
    )
    after = _html_attrs(page)
    assert after["data-wt-palette"] == "console"
    assert after["data-theme"] == "dark"
    assert after["data-wt-type"] == "plex"

    # A SyntaxError in the inline <script> appears here (favicon 404 is benign).
    js_errors = [e for e in errors if "favicon" not in e.lower()]
    assert not js_errors, f"console errors on appearance page: {js_errors}"


def test_appearance_choice_persists_across_nav(page, base_url):
    """The chosen preset must survive navigation to another page.

    save() POSTs to /settings/appearance/save (CSRF token from the meta tag);
    the server persists it per-browser and re-applies on the next page load.
    """
    page.goto(f"{base_url}/settings/appearance", wait_until="domcontentloaded")
    page.click('button[data-preset="console"]')
    page.wait_for_function(
        "() => document.documentElement.getAttribute('data-wt-palette') === 'console'"
    )
    # Give the async save() a beat to complete before navigating away.
    page.wait_for_function(
        "() => (document.getElementById('wt-status')||{}).textContent"
        " && document.getElementById('wt-status').textContent.indexOf('Saved') === 0"
    )

    page.goto(f"{base_url}/tasks", wait_until="domcontentloaded")
    attrs = _html_attrs(page)
    assert attrs.get("data-wt-palette") == "console", "preset did not persist across navigation"
    assert attrs.get("data-theme") == "dark"
