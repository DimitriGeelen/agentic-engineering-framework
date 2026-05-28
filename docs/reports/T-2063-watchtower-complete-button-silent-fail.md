# T-2063 — Watchtower Complete button silent-fail

**Task:** [T-2063](/tasks/T-2063) (Inception)
**Date:** 2026-05-28
**Decision:** GO — extract htmx toast handlers to web/static/htmx-toast.js

## Summary

User reported the /review/T-XXX Complete button does nothing visible — the POST returns 403 (CSRF or auth class) but the error never surfaces because `review.html` is a STANDALONE template that does NOT extend `base.html`. The `htmx:responseError` + `htmx:sendError` toast handlers at `base.html:970-978` are therefore never loaded on /review pages.

## Decision: GO

**Sharpened candidate (b)' — extract toast handlers to `web/static/htmx-toast.js`, load from /review pages.**

Empirical exploration narrowed root cause to a STANDALONE-TEMPLATE class:
- csrf-htmx.js was already extracted (T-1453)
- Toast handlers were not — structural asymmetry
- Cause-A (the 403 itself) needs browser-side evidence we don't have yet
- Closing cause-B first means the user can SEE the next 4xx instead of guessing

This is the right ordering: visibility before diagnosis.

## Follow-up

File (a)' as sibling build task for the residual CSRF-flow proximate cause once the toast extraction lands and surfaces the real 4xx code.

See task body for full Recommendation block and Decisions trace.
