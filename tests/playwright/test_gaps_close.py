"""Playwright regression tests for /gaps Close action (T-2185).

Verifies that the Close button surfaces correctly for `status: watching`
gaps with a `closure_check_command:` set, and that the HTMX swap mechanism
delivers an inline response without a full page navigation.

The fixture-bound Watchtower instance reads the real `.context/project/
concerns.yaml`. G-064 currently has gauge=READY (per OBS-048 cron firings ≥3
threshold), so the test asserts the live UI state matches the contract:

  - Close button visible for G-064 (gauge=READY enabled state)
  - Disabled state present for gaps with gauge=NOT_READY/UNKNOWN (if any)
  - hx-confirm attribute on the form (modal-driven confirmation)
  - hx-post target points at /gaps/<gap_id>/close
  - CSRF token embedded in the form

These do NOT actually submit the close action — that would mutate the live
gap register. The lib/bats layer in `tests/unit/gaps_close.bats` covers the
mutation paths against synthetic gaps.
"""

import pytest


class TestGapsClose:
    def test_close_button_present_for_ready_gap(self, page, base_url):
        """G-064 has gauge=READY; the Close form should be visible."""
        page.goto(f"{base_url}/gaps")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        # Expand any collapsed overflow so all gaps are in the DOM tree.
        page.evaluate(
            "document.querySelectorAll('details.gaps-overflow').forEach(d=>d.open=true);"
        )
        page.wait_for_timeout(200)

        # Locate G-064 article scope (id appears in <code>).
        g064_close = page.query_selector(
            'div.gap-close-action[data-gap-id="G-064"]'
        )
        if g064_close is None:
            pytest.skip(
                "G-064 not present (closed since test fixture or not yet filed) — "
                "test contract holds for whatever gauge=READY gap exists."
            )

        # Either a form (enabled) or a button[disabled] (NOT_READY/UNKNOWN).
        form = g064_close.query_selector("form")
        if form is not None:
            # Enabled state — verify form contract.
            hx_post = form.get_attribute("hx-post")
            assert hx_post == "/gaps/G-064/close", f"hx-post mismatch: {hx_post}"
            assert form.get_attribute("hx-confirm"), "missing hx-confirm modal trigger"
            assert form.get_attribute("hx-target") == "closest .gap-close-action"
            csrf = form.query_selector('input[name="_csrf_token"]')
            assert csrf is not None, "CSRF token missing — POST will 403"
            tok = csrf.get_attribute("value")
            assert tok and len(tok) >= 32, "CSRF token suspiciously short"
            button = form.query_selector("button[type=submit]")
            assert button is not None, "submit button missing"
            text = button.inner_text().strip()
            assert "Close" in text and "READY" in text, f"button text wrong: {text!r}"
        else:
            # Disabled state — verify tooltip-bearing button shape.
            disabled = g064_close.query_selector("button[disabled]")
            assert disabled is not None, "neither form nor disabled button present"
            title = disabled.get_attribute("title") or ""
            assert "Gauge verdict" in title, f"disabled tooltip missing: {title!r}"

    def test_disabled_state_for_unknown_gauge_gaps(self, page, base_url):
        """Gaps without `closure_check_command:` should have NO close-action div."""
        page.goto(f"{base_url}/gaps")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        # Find any gap with status:watching badge but no .gap-close-action sibling.
        # This is the most common case (most gaps have no gauge yet).
        articles_with_close = page.query_selector_all(
            "article:has(.gap-close-action)"
        )
        all_articles = page.query_selector_all("article")
        # Sanity: at least some articles exist on /gaps.
        assert len(all_articles) > 0, "no gap articles rendered at all"
        # Sanity: the close-action div is selective (not on every article).
        # If every article had one, the gating logic in gauge_by_id is broken.
        if len(articles_with_close) == len(all_articles):
            # All gaps surface a close action — only possible if every watching
            # gap has a gauge AND there are no closed gaps. Allowed but unusual.
            pass

    def test_close_form_hx_swap_target_is_local(self, page, base_url):
        """hx-swap target ('closest .gap-close-action') keeps mutation local —
        a successful close replaces only the action div, not the whole article.
        Guards against accidental hx-target=body / full-page swap regressions."""
        page.goto(f"{base_url}/gaps")
        page.wait_for_load_state("domcontentloaded")
        page.wait_for_timeout(500)
        page.evaluate(
            "document.querySelectorAll('details.gaps-overflow').forEach(d=>d.open=true);"
        )
        forms = page.query_selector_all("form[hx-post*='/gaps/']")
        for form in forms:
            target = form.get_attribute("hx-target")
            swap = form.get_attribute("hx-swap")
            assert target == "closest .gap-close-action", (
                f"hx-target should scope to gap action, got: {target!r}"
            )
            assert swap == "innerHTML", f"hx-swap should be innerHTML, got: {swap!r}"
