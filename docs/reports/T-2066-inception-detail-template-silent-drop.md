# T-2066 — `inception_detail.html` silently drops Context/RCA/AC/Verification/Decisions

**Task:** [T-2066](/tasks/T-2066) (Inception)
**Date:** 2026-05-28
**Decision:** GO — option (a) add render slots + matching Jinja blocks

## Summary

User reported that the inception detail page on Watchtower (`/inception/T-XXXX`) shows only Problem Statement / Exploration Plan / Recommendation — silently dropping the Context, RCA, Acceptance Criteria, Verification, and Decisions sections that the task body actually contains. The template was scoped narrowly when first written; everything outside the inception-specific blocks gets parsed but not rendered.

## Decision: GO

**Option (a) — add render slots for Context / RCA / Acceptance Criteria / Verification / Decisions, plus matching Jinja blocks in `inception_detail.html`.**

Symmetry with `task_detail.html` — same section set surfaces on both pages. Render-surface gate (T-1766) applies: any change to `web/templates/inception_detail.html` requires `[REVIEW]` Human AC for visual confirmation that the new sections render cleanly without breaking the existing layout.

See task body for full Recommendation and Decisions trace.
