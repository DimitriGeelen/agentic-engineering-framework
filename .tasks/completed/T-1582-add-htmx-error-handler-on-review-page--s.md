---
id: T-1582
name: "Add htmx error handler on /review page — surface 4xx/5xx as visible toast (T-1574 follow-up)"
description: >
  Add htmx error handler on /review page — surface 4xx/5xx as visible toast (T-1574 follow-up)

status: work-completed
workflow_type: build
owner: human
horizon: null
tags: []
components: [tests/playwright/test_review_page.py, web/templates/review.html]
related_tasks: []
created: 2026-04-28T13:31:04Z
last_update: 2026-04-29T08:33:49Z
date_finished: 2026-04-28T13:55:57Z
---

# T-1582: Add htmx error handler on /review page — surface 4xx/5xx as visible toast (T-1574 follow-up)

## Context

`web/templates/review.html` is a standalone template (T-1453 deliberately did not extend `base.html` so the mobile-first /review surface stays self-contained). Consequence: the htmx error handler in `base.html:407-414` (toast on `htmx:responseError` / `htmx:sendError`) does not apply to /review. T-1574's RCA explicitly flagged this: *"a generic htmx error handler at the review.html layer would catch future silent failures in the same class."*

Without it, any 4xx/5xx response from `/api/task/<id>/complete`, `/api/task/<id>/ac/toggle`, `/inception/<id>/decide`, etc. is silently dropped by htmx — buttons appear unresponsive (the original T-1574 symptom).

Same class as the cockpit Recommendation rendering arc (one fix in base.html, second surface forgotten).

## Acceptance Criteria

### Agent
- [x] `review.html` includes a `#toast-container` div before `</body>` matching `base.html:336` shape
- [x] `review.html` `<style>` block contains `.wt-toast` rules + `toast-in` / `toast-out` keyframes mirroring `base.html:357-372`
- [x] `review.html` `<script>` block contains `showToast(msg, type)` helper + `htmx:responseError` listener (extracts response text, max 100 chars, falls back to "Save failed") + `htmx:sendError` listener ("Network error — check server") matching `base.html:392-414` semantics
- [x] Visible verification via `curl -sf "$(bin/fw watchtower url)/review/T-1565"` shows `id="toast-container"`, `.wt-toast` CSS, `function showToast`, and both `htmx:responseError` / `htmx:sendError` listeners in the served HTML
- [x] Existing /review polling, AC toggling, inception decide buttons still work (no regression — Watchtower restart + manual smoke check via curl that page returns 200 and contains expected form IDs)
- [x] Recommendation-rendering tests in `tests/unit/test_extract_recommendation.py` still pass (24 tests — sanity check that no shared-template regression slipped in)

### Human
- [x] [REVIEW] Force a 500 on /review and confirm a red toast appears (reclassified per T-954 — DOM evidence: `id="toast-container"`, `htmx:responseError`, `htmx:sendError`, `.wt-toast`, `function showToast` all present in served HTML; toast machinery wired identically to base.html:407-414; T-1597 W1 confirm-GO with explicit classification gripe; T-1600 captures real-500 Playwright follow-up; user-authorized batch close)
  **Steps:**
  1. Open `http://192.168.10.107:3000/review/T-1565` in a browser
  2. Open DevTools → Network tab
  3. Right-click the GO button → Inspect → temporarily change the form's `hx-post` URL to `/inception/INVALID_TASK/decide` (or use DevTools console: `htmx.ajax('POST', '/inception/INVALID_TASK/decide', {target:'body'})`)
  4. Click GO with rationale filled in
  **Expected:** A red toast slides in from the top-right with the error text (or "Save failed"); the button does NOT silently hang
  **If not:** Note the network response code in DevTools and the absence/wrong colour of the toast

## Verification

curl -sf "$(bin/fw watchtower url)/review/T-1565" | grep -q 'id="toast-container"'
curl -sf "$(bin/fw watchtower url)/review/T-1565" | grep -q 'htmx:responseError'
curl -sf "$(bin/fw watchtower url)/review/T-1565" | grep -q 'htmx:sendError'
curl -sf "$(bin/fw watchtower url)/review/T-1565" | grep -q '.wt-toast'
curl -sf "$(bin/fw watchtower url)/review/T-1565" | grep -q 'function showToast'
curl -sf -o /dev/null -w '%{http_code}' "$(bin/fw watchtower url)/review/T-1565" | grep -q '^200$'
python3 -m pytest tests/unit/test_extract_recommendation.py -q --no-header 2>&1 | grep -q '24 passed'

## RCA

**Symptom:** Buttons on /review/T-XXX silently fail when their POST returns 4xx/5xx — no toast, no inline message, the user assumes the click was lost (originally observed for T-1574's inception Complete-button case before that fix landed).

**Root cause:** `review.html` is a standalone template (T-1453 split csrf-htmx.js out into a shared static file but kept the rest of the page self-contained for mobile UX), so the htmx-error→toast handler installed in `base.html:407-414` never runs on /review. Same class as the F5/L-298 family of cross-surface drift bugs: one shared affordance, multiple surfaces, only the cockpit gets the upgrade.

**Why structurally allowed:** No invariant test pins "/review surfaces htmx errors visibly." The base.html handler is wired up for the cockpit but there is no contract that says every standalone template providing htmx forms must also surface response errors. Originally the only standalone template was the long-defunct PWA shell; review.html quietly inherited the gap when T-1453 split csrf out without splitting toast.

**Prevention:** The verification curl-greps pin the presence of toast-container and the two htmx error listeners on /review specifically. Follow-up structural option (NOT in this task): extract toast machinery into `web/static/toast-htmx.js` once a third standalone template arises — same trigger T-1453 used for the csrf split.

## Recommendation

**Recommendation:** GO

**Rationale:** /review now installs the same htmx error→toast handler that `base.html` provides for the cockpit. 4xx/5xx responses on inception decide, AC toggle, Tier-0 approve, and complete-button POSTs surface visibly instead of silently disappearing. Closes the explicit follow-up gap T-1574 flagged ("a generic htmx error handler at the review.html layer would catch future silent failures in the same class"). All 6 verification curl-greps pass; 24 extract_recommendation unit tests still pass (sanity).

**Evidence:**
- `web/templates/review.html` — `.wt-toast` CSS rules + `toast-in`/`toast-out` keyframes (mirroring `base.html:357-372`); `#toast-container` div before `</body>`; inline `<script>` with `showToast(msg, type)` + `htmx:responseError` listener (extracts response text, max 100 chars, falls back to "Save failed") + `htmx:sendError` listener ("Network error — check server").
- All 6 verification commands pass on live `http://192.168.10.107:3000/review/T-1565`: toast-container present, both htmx error listeners present, `.wt-toast` CSS present, `function showToast` present, page returns HTTP 200.
- `bin/fw test unit -- tests/unit/test_extract_recommendation.py` → 24/24 pass (no regression in shared parsing).
- Standalone-template policy preserved: review.html stays self-contained per T-1453's design (no extends added). Future extraction to `web/static/toast-htmx.js` is noted as a structural follow-up if a third standalone template ever needs the same machinery.

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-28T13:31:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1582-add-htmx-error-handler-on-review-page--s.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-7a127451
- **Timestamp:** 2026-04-28T13:55:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-04-28T13:55:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
