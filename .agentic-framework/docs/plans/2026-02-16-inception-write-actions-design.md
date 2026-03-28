# Phase 2: Inception Write Actions Design

**Date:** 2026-02-16
**Task:** T-089
**Status:** Approved (user granted full autonomy)

## Goal

Add write actions to the Watchtower inception UI so users can create assumptions, validate/invalidate them, and record go/no-go decisions directly from the browser — eliminating the need to switch to CLI for these operations.

## Architecture

HTMX forms -> Flask POST routes -> `fw` CLI subprocess -> YAML/Markdown files -> HTMX fragment refresh

This reuses the existing CLI logic (no duplication) and maintains the zero-JS HTMX-only pattern.

## Write Actions

### 1. Add Assumption (inception detail page)

- Inline form in Assumptions section: text input + submit button
- `POST /inception/<task_id>/add-assumption`
- Calls: `fw assumption add "<statement>" --task <task_id>`
- HTMX: refreshes assumption list on success

### 2. Validate/Invalidate Assumption (inception detail + assumptions page)

- Each untested assumption gets Validate/Invalidate buttons
- Clicking reveals inline evidence input
- `POST /assumptions/<id>/resolve` with action + evidence
- Calls: `fw assumption validate|invalidate A-XXX --evidence "..."`
- HTMX: refreshes assumption card to show new status

### 3. Record Decision (inception detail page)

- Shown only when decision is "pending"
- Three buttons: GO / NO-GO / DEFER, each opens rationale textarea
- `POST /inception/<task_id>/decide` with decision + rationale
- Calls: `fw inception decide <task_id> <decision> --rationale "..."`
- HTMX: refreshes decision banner, disables form

## Files Modified

- `web/blueprints/inception.py` — 3 new POST routes
- `web/templates/inception_detail.html` — assumption form + decision form
- `web/templates/assumptions.html` — validate/invalidate buttons

## Alternatives Rejected

- **Direct YAML manipulation in Python** — duplicates CLI logic, two code paths
- **JavaScript fetch + REST API** — breaks HTMX-only pattern, adds dependency
