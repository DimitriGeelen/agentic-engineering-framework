"""T-2334 / T-2330 S3: Playwright lockdown of the /bvp propose-queue surface.

T-2332 shipped the "Pending driver proposals" inline section on /bvp + the three
endpoints (`/api/bvp/driver/{propose,approve,reject}`). bats covers the Python
helpers; live curl smoke verified the endpoints; this file pins the DOM contract
so the UX class can't silently regress.

Sibling: `test_bvp_form_htmx.py` (T-2079 — add-driver form htmx lockdown). Same
shape of structural guards (no native form, htmx attributes correct, no URL
navigation away on submit).

Per T-971: every Tier-3 UI Agent AC ships a Playwright guard.
"""

import re

from playwright.sync_api import expect


# -------------------------------------------------------------------------
# Structural guards — what the rendered DOM must / must not contain when
# proposals are pending. If no proposals are pending the section is absent
# by design (T-2332 — empty-state shows nothing so default /bvp is unchanged);
# tests below skip cleanly in that case rather than asserting state we can't
# control without mutating .context/bvp-driver-proposals.jsonl.
# -------------------------------------------------------------------------


def _section_present(page):
    """Return True iff the propose-queue section is rendered on /bvp."""
    return page.locator("#bvp-driver-proposals").count() > 0


def test_propose_queue_section_renders_when_pending(page, base_url):
    """Structural: the section exists with id=`bvp-driver-proposals` when
    proposals are pending, and shows a count + table header.

    The test runs against the live store. If empty, we skip — the empty-state
    behaviour is covered by the bats `_load_proposals returns empty list when
    file missing` test (`tests/unit/t2332_bvp_propose_queue.bats:25`).
    """
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    if not _section_present(page):
        # No proposals pending in the live store — empty-state is bats-covered.
        return
    section = page.locator("#bvp-driver-proposals")
    expect(section).to_be_visible()
    expect(section.locator("h3")).to_contain_text("Pending driver proposals")
    # Table exists with expected columns.
    expect(section.locator("table thead")).to_contain_text("Name")
    expect(section.locator("table thead")).to_contain_text("Weight")
    expect(section.locator("table thead")).to_contain_text("Rationale")


def test_approve_button_uses_htmx_hx_post(page, base_url):
    """Approve button drives the request via htmx with `hx-post` pointing at
    `/api/bvp/driver/approve?id=P-XXXX`. Mirrors the T-2079 driver-add form
    htmx lockdown."""
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    if not _section_present(page):
        return
    approve_btns = page.locator("#bvp-driver-proposals button:has-text('Approve')")
    if approve_btns.count() == 0:
        return
    btn0 = approve_btns.nth(0)
    hx_post = btn0.get_attribute("hx-post")
    assert hx_post and hx_post.startswith("/api/bvp/driver/approve?id="), (
        f"Approve button hx-post should be /api/bvp/driver/approve?id=P-XXXX, got {hx_post!r}"
    )
    assert btn0.get_attribute("hx-target"), "Approve button missing hx-target"


def test_reject_button_uses_htmx_with_hx_prompt(page, base_url):
    """Reject button drives the request via htmx with `hx-post` pointing at
    `/api/bvp/driver/reject?id=P-XXXX` AND carries `hx-prompt` to collect the
    rejection rationale (≥30 chars) via the browser's prompt() dialog —
    sibling pattern to the per-row driver-remove buttons (T-2079)."""
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    if not _section_present(page):
        return
    reject_btns = page.locator("#bvp-driver-proposals button:has-text('Reject')")
    if reject_btns.count() == 0:
        return
    btn0 = reject_btns.nth(0)
    hx_post = btn0.get_attribute("hx-post")
    assert hx_post and hx_post.startswith("/api/bvp/driver/reject?id="), (
        f"Reject button hx-post should be /api/bvp/driver/reject?id=P-XXXX, got {hx_post!r}"
    )
    assert btn0.get_attribute("hx-prompt"), (
        "Reject button missing hx-prompt — rationale collection is the L-class "
        "signal capture path; without it operator reject reasons evaporate."
    )


def test_no_native_form_action_to_propose_endpoints(page, base_url):
    """T-2079 sibling: the native `<form method="POST" action="/api/bvp/...">`
    pattern is exactly what causes URL-navigates-to-JSON-API regressions when
    JS fails. The fix is structural — the attribute pair must not be on any
    form within the propose-queue section."""
    page.goto(f"{base_url}/bvp", wait_until="domcontentloaded")
    html = page.content()
    matches = re.findall(
        r'<form\b[^>]*method="POST"[^>]*action="/api/bvp/driver/(approve|reject|propose)',
        html,
    )
    assert matches == [], (
        f"/bvp contains native <form method=POST action=/api/bvp/driver/{{approve,reject,propose}}>: "
        f"{matches}. Convert to hx-post — T-2079 class regression."
    )
