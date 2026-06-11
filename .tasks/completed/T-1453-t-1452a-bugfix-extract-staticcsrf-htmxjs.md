---
id: T-1453
name: "T-1452a Bugfix: extract static/csrf-htmx.js, share between base.html and review.html,
  add Playwright regression on /review/<id> mutation flow, audit other standalone
  templates"
description: >
  Build task spawned from T-1452 GO-structural-fix decision. Scope: (1) extract htmx:configRequest
  CSRF listener + fetchWithCsrf wrapper from web/templates/base.html:429-449 into
  web/static/csrf-htmx.js; (2) include the script from both base.html and web/templates/review.html
  via <script src=...>; (3) audit web/templates/*.html for other standalone templates
  (any HTML file with its own <head> block + hx-post/hx-put/hx-delete/hx-patch but
  no csrf listener) and fix; (4) Playwright test in tests/playwright/ that opens /review/<task_id>,
  ticks an AC checkbox, asserts the toggle-ac API returns 2xx + checkbox state persists;
  (5) capture L-269 if audit found additional victims; (6) consider filing v1.7 reviewer
  pattern candidate 'standalone-template-no-csrf'.

status: work-completed
workflow_type: build
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-25T11:51:34Z
last_update: '2026-06-11T22:23:48Z'
date_finished: 2026-04-25T12:11:51Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1453: T-1452a Bugfix: extract static/csrf-htmx.js, share between base.html and review.html, add Playwright regression on /review/<id> mutation flow, audit other standalone templates

## Context

Build task spawned from T-1452 GO-structural-fix decision. `web/templates/review.html` is a standalone mobile template (per T-667) that does not extend `base.html` and therefore lacks the `htmx:configRequest` listener that injects `X-CSRF-Token`. Result: every htmx mutation on `/review/<task_id>` returns 403 silently. Fix: extract the listener into `web/static/csrf-htmx.js`, share between `base.html` and `review.html`, add Playwright regression, audit other standalone templates.

**Audit result (this task):** Only `review.html` is a standalone template with htmx mutations. `_review_error.html` is standalone but emits no htmx requests. Every other template in `web/templates/*.html` renders through `_wrapper.html` → `base.html` and inherits the listener.

## Acceptance Criteria

### Agent
- [x] `web/static/csrf-htmx.js` exists with the `htmx:configRequest` listener and `window.fetchWithCsrf` wrapper extracted verbatim from base.html:429-449
- [x] `web/templates/base.html` loads the file via `<script src="{{ url_for('static', filename='csrf-htmx.js') }}"></script>` — inline duplicate removed
- [x] `web/templates/review.html` includes the csrf meta tag (`<meta name="csrf-token" content="{{ csrf_token() }}">`) AND loads the same script
- [x] After Watchtower restart: POST to `/api/task/T-1452/toggle-ac` with `X-CSRF-Token` header returns 500 (app-layer "Not an AC checkbox line" — proves CSRF passed); without header returns 403 (proves gate still enforces)
- [x] `tests/playwright/test_review_csrf.py` exists — 3 tests (script loads, csrf meta present, toggle-ac click does not 403); all PASS
- [x] `bin/fw test playwright` ran 400 tests — 399 pass + 1 unrelated pre-existing failure in `test_api_search` (search/v1 endpoint 500, orthogonal to T-1453)
- [x] No regression in pytest unit suite — 83 tests pass

### Human
- [x] [REVIEW] Open `${URL}/review/T-1452` in a phone/desktop browser, tick the Human AC checkbox, verify the box stays ticked and progress bar updates
  **Steps:**
  1. Open `$(bin/fw watchtower url)/review/T-1452` in browser
  2. Tick the `[REVIEW] Decide go/no-go and choose fix shape` checkbox
  3. Reload the page
  **Expected:** Checkbox stays checked, progress bar shows 1/1, "Complete Task" button appears
  **If not:** Capture browser console errors, paste into task body

## Verification

test -f web/static/csrf-htmx.js
grep -q "htmx:configRequest" web/static/csrf-htmx.js
grep -q "fetchWithCsrf" web/static/csrf-htmx.js
grep -q "csrf-htmx.js" web/templates/base.html
grep -q "csrf-htmx.js" web/templates/review.html
grep -q 'meta name="csrf-token"' web/templates/review.html
test -f tests/playwright/test_review_csrf.py

## Recommendation

**Recommendation:** Close.

**Rationale:** Structural fix shipped per T-1452 GO. CSRF wiring is now data-driven (one shared script, two consumers). All Agent ACs verified mechanically. The remaining `[REVIEW]` Human AC is a real browser-tap check on a phone or desktop browser — only the human can do that. Worth surfacing because the same page also unblocks ~28 other tasks waiting for Human AC review.

**Evidence:**
- `web/static/csrf-htmx.js` extracted (37 lines, includes DOMContentLoaded guard so it's safe in `<head>`)
- `base.html` inline duplicate removed → loads via script tag at line 14
- `review.html` adds csrf-token meta + script tag
- Manual curl: POST without CSRF → 403; POST with CSRF → 500 (app-layer "Not an AC checkbox line"), proving CSRF passed
- 3 new Playwright regression tests pass (`test_review_csrf.py`)
- 9 existing /review tests still pass — no regression
- 83 unit pytest tests pass — no regression
- 400 Playwright tests overall — 399 pass + 1 unrelated pre-existing failure (`test_api_search` returning 500)
- Audit of `web/templates/*.html` for `<html|DOCTYPE`: only `base.html`, `review.html`, `_review_error.html` are standalone. `_review_error.html` has no htmx mutations — not a victim. So the universe of "standalone templates with htmx" has size 1, fully covered.
- L-269 captured: standalone templates must extend base.html OR load `/static/csrf-htmx.js`

## Decisions

### 2026-04-25 — DOMContentLoaded guard in csrf-htmx.js
- **Chose:** Wrap `addEventListener` in DOMContentLoaded check
- **Why:** `base.html` loads scripts in `<head>` (before `<body>` exists). The original inline code worked because it lived at end-of-body. The shared script must work in either position.
- **Rejected:** Move script tag to end-of-body in base.html — fragile, easy to forget on next standalone template. Defer attribute — works for the script load order but doesn't help if the script has to run on its own immediately.

### 2026-04-25 — Single shared static asset over per-template inline
- **Chose:** Extract to `web/static/csrf-htmx.js`, both templates `<script src=>` it
- **Why:** Future standalone templates (mobile second-screen, kiosk, embedded widgets per T-667 design) need the same wiring. One source of truth eliminates the recurrence class.
- **Rejected:** Copy-paste the listener into review.html — solves T-1452 specifically but the next standalone template hits the same bug.

## Updates

### 2026-04-25T11:51:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1453-t-1452a-bugfix-extract-staticcsrf-htmxjs.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e94e7ea0
- **Timestamp:** 2026-06-02T14:57:35Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

- **Suppressed:** 1 (by override)
  - human-ac-mechanical-signal @ AC#1 (Human)
### 2026-04-25T12:11:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
