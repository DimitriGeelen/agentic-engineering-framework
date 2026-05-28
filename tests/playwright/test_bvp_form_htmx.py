"""T-2079: /bvp forms use htmx, never native form-submit-to-API-URL.

Origin: a human submitted the Add-driver form and ended up on a 405 page at
`/api/bvp/driver/add`. Server log showed the POST itself returned 200; the 405
was from a GET on the API URL one second later. Root cause: the form declared
`method="POST" action="/api/bvp/driver/add"` alongside a vanilla `fetch()` JS
handler. When anything stops the JS submit listener attaching (any earlier
script error, double-click race), the native form submit fires and the browser
navigates to the JSON API URL — a refresh then issues a GET → 405.

This test pins the structural fix: the three /bvp POST surfaces are driven by
htmx attributes, the native `method="POST" action="/api/bvp/..."` attribute
pair is gone, and submitting the add form does NOT navigate the URL away from
/bvp. Per T-971: an Agent AC for a UI feature ships a Playwright guard so the
class can't return silently.
"""

import re

from playwright.sync_api import expect


# -------------------------------------------------------------------------
# Structural guards — what the rendered DOM must / must not contain.
# -------------------------------------------------------------------------

def test_no_native_form_action_to_api(page, base_url):
    """The native `<form method="POST" action="/api/bvp/...">` pattern is gone.

    This is the exact pattern that caused T-2079: it lets the browser navigate
    to the JSON API URL if JS fails. The fix is structural — the attribute
    pair must not be on any form in the rendered page.
    """
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    html = page.content()
    matches = re.findall(r'<form\b[^>]*method="POST"[^>]*action="/api/bvp/', html)
    assert matches == [], (
        f"/bvp still contains native <form method=POST action=/api/bvp/...>: {matches}. "
        "Convert to hx-post (T-2079)."
    )


def test_driver_add_form_uses_htmx(page, base_url):
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    form = page.locator("#bvp-driver-add-form")
    expect(form).to_have_attribute("hx-post", "/api/bvp/driver/add")
    expect(form).to_have_attribute("hx-target", "#da-result")
    # Native submit attributes must NOT be set.
    assert form.get_attribute("action") is None, "driver-add form still has action= attribute"
    assert form.get_attribute("method") is None, "driver-add form still has method= attribute"


def test_commit_weights_form_uses_htmx(page, base_url):
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    form = page.locator("#bvp-commit-form")
    expect(form).to_have_attribute("hx-post", "/api/bvp/commit-weights")
    expect(form).to_have_attribute("hx-target", "#bvp-commit-result")
    assert form.get_attribute("action") is None, "commit-weights form still has action= attribute"
    assert form.get_attribute("method") is None, "commit-weights form still has method= attribute"


def test_remove_buttons_use_htmx_hx_prompt(page, base_url):
    """Per-row Remove buttons must drive the request via htmx with hx-prompt
    for rationale collection — not a vanilla click handler doing fetch()."""
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    buttons = page.locator("button.dr-remove-btn")
    n = buttons.count()
    if n == 0:
        # No free drivers — nothing to assert. The structural test
        # `test_no_native_form_action_to_api` still passes.
        return
    btn0 = buttons.nth(0)
    hx_post = btn0.get_attribute("hx-post")
    assert hx_post and hx_post.startswith("/api/bvp/driver/remove?driver="), (
        f"remove button hx-post should carry driver= in query, got {hx_post!r}"
    )
    assert btn0.get_attribute("hx-prompt"), "remove button missing hx-prompt for rationale"


# -------------------------------------------------------------------------
# Behavioural guard — the failure mode itself: submitting must NOT navigate
# the page URL away from /bvp.
# -------------------------------------------------------------------------

def test_add_form_submit_keeps_user_on_bvp(page, base_url):
    """The exact failure mode T-2079 closes: pressing Submit on the add-driver
    form must not navigate the browser to the JSON API URL.

    We populate the form fields with a unique driver name and submit; the URL
    must remain on /bvp throughout. Whether the backend actually adds the
    driver is asserted elsewhere (commit-weights tests, CLI fw bvp tests) —
    here we care only that the URL stays put.
    """
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    expect(page.locator("#bvp-driver-add-form")).to_be_visible()

    # Disable the after-request reload so the test sees the post-submit URL
    # cleanly — the production reload would itself stay on /bvp but reloads
    # add timing noise that masks regressions if the navigation IS broken.
    page.evaluate(
        """
        const f = document.getElementById('bvp-driver-add-form');
        f.removeAttribute('hx-on::after-request');
        f.removeAttribute('hx-on:htmx:after-request');
        """
    )

    page.fill("#da-name", "t2079probe")
    page.fill(
        "#da-rationale",
        "T-2079 Playwright guard — verifying form submit does not navigate URL away from /bvp.",
    )
    # Submit and wait for the htmx response to land in the target div.
    page.click("#da-submit-btn")
    page.wait_for_selector("#da-result span", timeout=5000)

    # The URL must still be /bvp (path component) — never /api/bvp/driver/add.
    url = page.url
    assert "/bvp" in url and "/api/bvp/driver/add" not in url, (
        f"Submit navigated to {url} — the exact T-2079 failure mode. "
        "htmx hx-post should keep navigation client-side."
    )

    # Clean up: remove the driver we just added so re-runs work.
    csrf = page.locator('meta[name="csrf-token"]').get_attribute("content")
    page.request.post(
        f"{base_url}/api/bvp/driver/remove",
        headers={
            "HX-Request": "true",
            "HX-Prompt": "T-2079 Playwright cleanup - removing the probe driver added by the navigation guard test.",
            "X-CSRF-Token": csrf,
        },
        params={"driver": "t2079probe"},
    )
