# T-1452 — CSRF Token Missing on htmx POSTs (RCA)

**Type:** Inception (RCA)
**Date:** 2026-04-25
**Decision:** GO (structural fix, Option 2)
**Source task:** `.tasks/completed/T-1452-rca-reviewt-xxx-page-buttons-silently-fa.md`

## Problem Statement

`/review/T-XXX` page buttons silently fail. Three mutating htmx POSTs return server errors but the UI shows no diagnostic — the page is unresponsive to clicks. Root cause: htmx requests sent without CSRF tokens are rejected by the Flask CSRF middleware, but the rejection is not surfaced to the user.

## Recommendation

**GO with structural fix (Option 2):** extract a shared `static/csrf-htmx.js` module from `base.html` so any standalone template (review, approvals, future kiosk views) inherits CSRF token injection automatically. Add a Playwright regression test asserting CSRF token is present on every htmx POST.

**Rationale:** This bug class is recurrence-prone. Any future standalone template (mobile second-screen, embedded widgets, kiosk views) hits the same trap. A 30-line extracted JS module is one-time cost; the Playwright test prevents recurrence via DOM-level coverage. Total scope ~2–3 hours.

**Evidence:**
- 3 mutations broken right now → user-visible UX failure
- Same bug class will hit any new standalone template
- Pattern matches existing shared-asset approach (`pico.min.css`, `htmx.min.js` already shared)
- Cost-benefit: structural fix takes ~1.5x the time of minimal fix but eliminates a whole recurrence class

## Outcome

Build task T-1454 implemented the structural fix (closed 2026-04-25). Watchtower's `_csrf_token` field is now injected on the 5 hx-post forms in the approvals page; broader template extraction tracked as follow-on if needed.
