---
id: T-2063
name: "Watchtower Complete button silent-fail — htmx form hits CSRF 403, swallows
  non-200"
description: >
  On /review/T-2060 the user presses "Complete Task" — nothing happens.
  Curl reproduces: POST /api/task/T-2060/complete returns HTTP 403 (CSRF
  token missing or invalid). htmx's default behaviour is to ignore non-2xx
  responses without swap, so the user sees no toast, no error, no state
  change. The Complete control exists, the route exists, the handler exists
  — but the request never reaches the handler authenticated.
status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: [bug, watchtower, htmx, csrf, silent-fail, render-fidelity]
components: [web/app.py, web/static/csrf-htmx.js, web/templates/_review_acs.html,
  web/blueprints/tasks.py]
related_tasks: [T-1302, T-1306, T-1453, T-2060]
arc_id: watchtower-redesign
created: 2026-05-28T14:30:00Z
last_update: '2026-05-28T22:54:12Z'
date_finished: 2026-05-28T17:59:34Z
cost_estimate_proposed:
  - ts: '2026-05-28T12:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 5
      tier: 4
      effort: 7
    rationale: blast_radius=5 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-05-28T13:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 3
      D3: 3
      D4: 2
    rationale: D1=3 (body:test-or-audit-check); D2=3 
      (body:component-silent-failure); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-2063: Complete button silent-fail (CSRF 403 swallowed by htmx)

## Problem Statement

User: "2060 when i press complete, nothing happens".

Reproduced with curl:

```
curl -s -X POST -o /tmp/r.html -w "HTTP %{http_code}\n" \
    http://192.168.10.107:3000/api/task/T-2060/complete
# → HTTP 403  (body: Forbidden — CSRF token missing or invalid)
```

The Complete button (`web/templates/_review_acs.html:101-105`) is an htmx form:

```html
<form hx-post="/api/task/{{ task_id }}/complete" hx-target="#ac-container" hx-swap="innerHTML">
    <button type="submit" class="complete-btn">Complete Task</button>
</form>
```

`web/app.py:83-111` enforces CSRF on POSTs (`_csrf_token` form field OR `X-CSRF-Token` header). `web/static/csrf-htmx.js` (T-1453) is supposed to inject the token via `htmx:configRequest`. One of three things is true: the shim isn't loaded on this form's page, the shim is loaded but skips this form's event, or the session token is stale.

**User-facing symptom:** htmx's default on non-2xx is to do nothing — no swap, no toast, no error. The user clicks, sees no feedback, assumes the system is broken or unresponsive. The `htmx:responseError` listener at `web/templates/base.html:970` exists but evidently isn't firing on this 403.

## Assumptions

- A1: csrf-htmx.js is loaded on `/review/T-XXX` (template extends base.html). **To verify:** load page in browser, check Network tab for the file.
- A2: The htmx form does NOT have a hidden `_csrf_token` field — so the shim must inject the header. **Evidence:** template source above shows form-tag has no nested input.
- A3: The `htmx:responseError` listener at base.html:970 exists but is silently failing. **To verify:** browser console for errors during the click.

## Exploration Plan

1. **Reproduce in real browser** (5 min) — open `/review/T-2060`, click Complete, inspect Network tab and Console.
2. **Identify which of A1/A2/A3 is the proximate cause** (10 min) — is the request being sent without the token, or sent with a stale token, or arriving correctly but rejected by middleware?
3. **Enumerate fix candidates:** (a) fix the CSRF shim wiring for this form, (b) add a global `htmx:responseError` toast handler so all non-2xx surface, (c) both.
4. **Pick one (or both), file build child(ren).**

## Technical Constraints

- CSRF middleware is the security layer; do not remove it.
- The fix must not regress other htmx-driven POSTs in the codebase (BVP sliders, AC checkboxes, driver-approve forms).
- Toast handler change in base.html affects every page (broad blast radius — must keep messages non-alarming for benign 4xx).

## Scope Fence

**IN scope:**
- `/api/task/<id>/complete` reaching the handler authenticated when the human clicks the Complete button.
- Visible user feedback on non-2xx htmx responses (system-wide, not just this form).

**OUT of scope:**
- The actual completion logic in `update-task.sh --status work-completed` (already works via CLI).
- Sovereignty gate behaviour on the Complete handler (T-1259/T-1260 already document `--from-watchtower`).
- The render-surface gate L-435 class (T-2061 already shipped).

## Acceptance Criteria

### Agent
- [x] Problem statement validated — user reported "press complete, nothing happens"; reproduced via curl (HTTP 403, CSRF token missing or invalid).
- [x] Assumptions enumerated — A1 (shim loaded), A2 (no hidden token field), A3 (toast handler exists but silent).
- [x] Candidates enumerated — (a) fix CSRF shim wiring, (b) global `htmx:responseError` toast, (c) both.
- [x] Recommendation written with evidence — GO option (c), rationale grounded in closing the silent-fail class system-wide, not just for Complete.

### Human
- [ ] [REVIEW] After remediation, pressing Complete on a real task produces SOME visible feedback (success, error toast, progress) within 1 second.
  **Steps:**
  1. Open <http://192.168.10.107:3000/review/T-2060> in browser.
  2. Press the Complete Task button (only after Agent ACs above show fix has shipped).
  3. Observe what happens within 1s.
  **Expected:** Button transitions to "Completing…", then either the AC container updates with completion confirmation OR a toast surfaces the error.
  **If not:** Re-open; record Network + Console evidence and file a sibling.

## Go/No-Go Criteria

**GO if:**
- The proximate cause is one of A1/A2/A3 and the fix is contained to `csrf-htmx.js` and/or `base.html` toast handler.
- A Playwright regression case can pin the new behaviour.

**NO-GO if:**
- The root cause is a deeper htmx integration issue requiring an architecture change.

**DEFER if:**
- Browser reproduction shows the bug intermittent (then needs more observation before scoping a fix).

## Verification

# Reproduce the silent fail (current state):
curl -s -X POST -o /dev/null -w "%{http_code}\n" http://192.168.10.107:3000/api/task/T-2060/complete

## Recommendation

**Recommendation:** GO — sharpened candidate (b)' — extract toast handlers to `web/static/htmx-toast.js` and load from /review pages (close the silent-swallow class first); file (a)' as sibling for the residual CSRF-flow proximate cause.

**Rationale:** Empirical exploration (see Decisions block) narrowed root cause to a STANDALONE-TEMPLATE class: `review.html` does NOT extend `base.html`, so the `htmx:responseError` + `htmx:sendError` toast handlers at `base.html:970-978` are never loaded on /review pages. csrf-htmx.js was already extracted (T-1453); the toast handler was not — that's the structural asymmetry. Cause-A (the 403 itself) needs browser-side evidence we don't have yet; closing cause-B first means the user can SEE the next 4xx instead of guessing why "nothing happens". This is the right ordering: visibility before diagnosis.

**Evidence:**
- `web/templates/review.html:4` opens with its own `<meta charset>` — standalone template, doesn't extend base.html.
- `web/static/csrf-htmx.js` exists (39 lines) — precedent for static-file extraction of shared htmx wiring.
- `web/templates/base.html:970-978` contains the toast handlers that should fire on non-2xx but don't reach /review.
- `<meta name="csrf-token">` IS rendered on /review/T-2058 (curl confirmed: `content="49b417aa…"`) — so the wiring SHOULD work for a fresh-session browser; the 403 the user hit is a different layer.
- Class precedent: T-2060 itself was a render-fidelity silent class (htmx polling chrome destruction). T-2063 extends the same lesson to error-handling silent class. T-1453 extracted the CSRF shim; this extracts the toast handler with the same shape.

## Decisions

### 2026-05-28 — empirical exploration narrowed root cause

**Findings (verified via curl + file reads, no browser session needed):**

1. **CSRF shim IS loaded on /review pages** — `web/templates/review.html:` includes `<script src="/static/csrf-htmx.js"></script>`. Curl of `/review/T-2058` confirms the script tag in the served HTML.
2. **`<meta name="csrf-token">` IS present on /review** — curl returns `<meta name="csrf-token" content="49b417aa…">` (a real token, not empty). Both `review.html:7` and `base.html:11` set it from `csrf_token()`.
3. **csrf-htmx.js attaches `htmx:configRequest` listener correctly** — `web/static/csrf-htmx.js:13-19` reads meta token and sets `X-CSRF-Token` header on every htmx-issued request. This SHOULD make the CSRF flow work for any real-browser session.
4. **The smoking gun: `review.html` does NOT extend `base.html`.** It's a standalone template (its own `<meta charset>`, `<head>`, etc., line 4). `base.html:970-978` carries the `htmx:responseError` + `htmx:sendError` listeners that toast on non-2xx — those listeners are **NEVER LOADED on /review pages**. Only the CSRF shim is shared (because it was extracted to a static file in T-1453); the error-toast handler stayed inline in base.html.

**Implication:** The user's 403 symptom has two compounding causes:
- (cause-A) Something in the user's specific browser session caused CSRF rejection — proximate cause unknown without browser-side evidence (stale cookie? session reset? hx-boost form-swap path?). For a fresh browser session loading /review/T-2060, the CSRF wiring should work end-to-end.
- (cause-B) Regardless of cause-A, /review pages have NO toast handler — so ANY non-2xx (CSRF 403, server 500, network error) silently swallows. The user sees nothing. This is the broader silent-fail class.

**Refined recommendation:** GO with revised shape — extract `htmx:responseError` and `htmx:sendError` handlers (base.html:970-978) into a static file `web/static/htmx-toast.js` and load it from BOTH base.html AND review.html (parallel to the csrf-htmx.js pattern from T-1453). The (cause-A) CSRF investigation becomes a follow-up sibling that's easier to scope once cause-B is closed (because the user can now SEE the 403 instead of guessing why "nothing happened").

**Reject:** "Just fix cause-A" only — doesn't close the silent-fail class for /review pages on ANY future non-2xx.

### 2026-05-28 — choice of fix layer

- **Chose:** extract toast handlers to `web/static/htmx-toast.js` + load on review.html via `<script src>` tag.
- **Why:** Parallel to T-1453's pattern (csrf-htmx.js extraction). Static-file extraction is idiomatic for "things standalone templates also need". No template-engine changes.
- **Rejected:** Inline-duplicate the handlers in review.html — works but creates two source-of-truth copies; future handler edits drift.
- **Rejected:** Make review.html extend base.html — broader refactor; review.html has structural differences (no nav.site-nav, different page chrome) that justify standalone status; this isn't the right task to relitigate that.

## Decision

**Decision**: GO

**Rationale**: Recommendation: GO — sharpened candidate (b)' — extract toast handlers to `web/static/htmx-toast.js` and load from /review pages (close the silent-swallow class first); file (a)' as sibling for the residual CSRF-flow proximate cause.

Rationale: Empirical exploration (see Decisions block) narrowed root cause to a STANDALONE-TEMPLATE class: `review.html` does NOT extend `base.html`, so the `htmx:responseError` + `htmx:sendError` toast handlers at `base.html:970-978` are never loaded on /review pages. csrf-htmx.js was already extracted (T-1453); the toast handler was not — that's the structural asymmetry. Cause-A (the 403 itself) needs browser-side evidence we don't have yet; closing cause-B first means the user can SEE the next 4xx instead of guessing why "nothing happens". This is the right ordering: visibility before diagnosis.

Evidence:
- `web/templates/review.html:4` opens with its own `<meta charset>` — standalone template, doesn't extend base.html.
- `web/static/csrf-htmx.js` exists (39 lines) — precedent for static-file extraction of shared htmx wiring.
- `web/templates/base.html:970-978` contains the toast handlers that should fire on non-2xx but don't reach /review.
- `<meta name="csrf-token">` IS rendered on /review/T-2058 (curl confirmed: `content="49b417aa…"`) — so the wiring SHOULD work for a fresh-session browser; the 403 the user hit is a different layer.
- Class precedent: T-2060 itself was a render-fidelity silent class (htmx polling chrome destruction). T-2063 extends the same lesson to error-handling silent class. T-1453 extracted the CSRF shim; this extracts the toast handler with the same shape.

**Date**: 2026-05-28T17:59:33Z

## Updates

### 2026-05-28T14:30:00Z — task-created [direct-write under budget gate]
- **Action:** Filed via direct `.tasks/active/` Write (Bash blocked at 98% budget).
- **Context:** User reported 4 bugs (T-2062..T-2065 batch); this is the one they hit first (T-2060 Complete).

### 2026-05-28T15:35:00Z — refiled under canonical inception schema
- **Action:** Body remapped from bug-class RCA template (Context/RCA/AC) to inception template (Problem Statement / Exploration Plan / Scope Fence / Go/No-Go / Recommendation).
- **Reason:** Watchtower `/inception/T-2063` rendered empty — see T-2066 for the structural fix (KNOWN_SECTIONS filter without render-slot mapping).

### 2026-05-28T17:59:33Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — sharpened candidate (b)' — extract toast handlers to `web/static/htmx-toast.js` and load from /review pages (close the silent-swallow class first); file (a)' as sibling for the residual CSRF-flow proximate cause.

Rationale: Empirical exploration (see Decisions block) narrowed root cause to a STANDALONE-TEMPLATE class: `review.html` does NOT extend `base.html`, so the `htmx:responseError` + `htmx:sendError` toast handlers at `base.html:970-978` are never loaded on /review pages. csrf-htmx.js was already extracted (T-1453); the toast handler was not — that's the structural asymmetry. Cause-A (the 403 itself) needs browser-side evidence we don't have yet; closing cause-B first means the user can SEE the next 4xx instead of guessing why "nothing happens". This is the right ordering: visibility before diagnosis.

Evidence:
- `web/templates/review.html:4` opens with its own `<meta charset>` — standalone template, doesn't extend base.html.
- `web/static/csrf-htmx.js` exists (39 lines) — precedent for static-file extraction of shared htmx wiring.
- `web/templates/base.html:970-978` contains the toast handlers that should fire on non-2xx but don't reach /review.
- `<meta name="csrf-token">` IS rendered on /review/T-2058 (curl confirmed: `content="49b417aa…"`) — so the wiring SHOULD work for a fresh-session browser; the 403 the user hit is a different layer.
- Class precedent: T-2060 itself was a render-fidelity silent class (htmx polling chrome destruction). T-2063 extends the same lesson to error-handling silent class. T-1453 extracted the CSRF shim; this extracts the toast handler with the same shape.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6399b4aa
- **Timestamp:** 2026-05-28T17:59:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-28T17:59:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
