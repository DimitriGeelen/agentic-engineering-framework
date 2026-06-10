
# T-2133: /review checkbox click silently no-ops — htmx:targetError on inherited hx-target=#content from T-2114 wrapper-reset

## Problem Statement

User reports on `/review/T-2131`: *"i tick the box nothing happens !!! regression sht ??"*

Clicking a Human AC checkbox on the /review surface visually toggles the box (native browser behaviour) but the change is never persisted server-side — and after the 5-second htmx poll, the checkbox reverts to unchecked. From the user's perspective the click is a silent no-op.

The toggle-ac endpoint is correct and works (verified by curl test below). The bug is **client-side**: htmx aborts the POST request with a `targetError` before the network call.

## Assumptions (validated this session)

1. **The /api/task/<id>/toggle-ac endpoint works in isolation** — VALIDATED. Direct curl with CSRF token + session cookie returns HTTP 200 and toggles the file correctly. Reverting also works.
2. **The toggle-ac handler correctly parses `- [ ] [REVIEW] ...` lines** — VALIDATED. The body-relative line_idx (18 for T-2131 AC #5) matches the regex `^(- \[)([ xX])(\] .+)$`.
3. **htmx 2.0.4 is loaded and JS is intact on the page** — VALIDATED. `window.htmx.version === "2.0.4"`, csrf meta present, form attributes intact (hx-post, hx-vals, hx-swap=none, hx-on::after-request).
4. **The form's POST is silently aborted by htmx, not by CSRF or network** — VALIDATED. After clicking the checkbox programmatically, ZERO htmx events fire (`htmx:configRequest`, `htmx:beforeRequest`, `htmx:beforeSend` all absent) and a `htmx:targetError` shows in the console. No network call to /toggle-ac is made.
5. **Server-side state was NOT mutated by my Playwright click** — VALIDATED. T-2131 Human AC remained `[ ]` after the click (per `grep "^- \[" .tasks/completed/T-2131-*.md`). Sovereignty boundary preserved by the bug itself.

## Exploration Plan (executed)

- ✅ **Spike A**: curl the toggle-ac endpoint with proper CSRF + cookies → confirms server side works
- ✅ **Spike B**: Playwright open /review/T-2131, capture console errors → finds `htmx:targetError`
- ✅ **Spike C**: Inspect form attributes via browser_evaluate → confirms form has no explicit `hx-target`, inherits from T-2114 outer wrapper `<div hx-target="#content" hx-swap="innerHTML" hx-push-url="true">`
- ✅ **Spike D**: Verify `#content` does not exist in standalone review.html → no element with id="content" anywhere in the template

## Technical Constraints

- **htmx 2.x target inheritance**: child elements inherit `hx-target` from ancestor unless overridden. If the resolved target doesn't exist in the DOM, htmx fires `htmx:targetError` and aborts the request *before* `configRequest` / `beforeRequest`.
- **Standalone templates**: `review.html` does not extend `base.html` (intentional, T-667 mobile-first). It has no `#content` shell element.
- **The T-2114 wrapper-reset pattern was designed for base-extending pages** where `#content` is the shell. On standalone /review, the same wrapper is a footgun.

## Scope Fence

**IN scope:**
- Fix the AC checkbox click on /review/<task_id> for both build tasks (Human AC partial-complete) and inception tasks (decide form)
- Cover by pinning a Playwright test that runs the click flow end-to-end (intercepts POST so no real task state mutates)
- Audit other forms inside the T-2114 wrapper for the same inheritance footgun

**OUT of scope:**
- Refactoring `/review` to extend base.html (large blast radius, separate consideration)
- Removing the T-2114 wrapper entirely (it solves a real bounce-back problem on hx-boosted anchors — see T-2114 RCA)

## Acceptance Criteria

### Agent
- [x] Problem statement validated (spike A-D evidence above)
- [x] Assumptions tested (5/5 validated this session)
- [x] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-2133` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Root cause identified with bounded fix path ✅ (htmx:targetError on inherited hx-target → add hx-target="this" on ac-check form)
- Fix is scoped, testable, and reversible ✅ (one-line attribute addition in `_review_acs.html`; Playwright test in `tests/playwright/test_review_interaction.py` pins the contract)

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope ✗ (it doesn't)
- Fix cost exceeds benefit given current evidence ✗ (one-line fix; high user-visible value)

## Recommendation

**Recommendation:** GO

**Rationale:**

Root cause is conclusive from live Playwright observation. The fix is a one-line attribute addition with a clear test pin. The bug is high-impact (any user trying to check a Human AC on /review hits it) and the fix path is surgical with zero blast radius outside /review.

**Three legs of structural closure proposed (mirrors T-2125 pattern):**

- **Leg A — Surgical fix (build slice, T-NEW-A):** Add `hx-target="this"` to the `<form class="ac-check">` in `web/templates/_review_acs.html:35`. Since `hx-swap="none"`, the target is irrelevant for the response handling, but htmx still requires it to resolve. `this` always resolves to the form element itself. The two sibling forms in the same wrapper (inception decide, build complete) already declare their own targets, so they're unaffected.

- **Leg B — Test pin (build slice, T-NEW-B):** Run `tests/playwright/test_review_interaction.py::test_ac_checkbox_click_posts_to_toggle_endpoint` against the live server to confirm: it route-intercepts the POST. If it passes after the fix and fails before, it pins the regression. Add it to the `fw test playwright` default invocation if not already there.

- **Leg C — Wrapper audit (build slice, T-NEW-C):** Grep `web/templates/` for other forms inside `<div hx-target="#content">` wrappers that don't override hx-target. The T-2114 wrapper-reset pattern is documented at `_review_acs.html:3-20` but the safety-rail (every form inside MUST set hx-target explicitly) wasn't enforced. The audit prevents the same footgun on /approvals, /cockpit, future surfaces.

**Evidence:**

- **htmx:targetError observed** at `http://192.168.10.107:3000/static/htmx.min.js:0` after clicking the checkbox via Playwright browser_evaluate
- **Zero htmx events fired** after click (events array empty) — confirms request was aborted pre-XHR
- **curl test** with CSRF + cookies + line=18 → HTTP 200, file mutated correctly
- **Form attributes captured**: hx-post=/api/task/T-2131/toggle-ac, hx-vals={"line": "18"}, hx-swap=none, hx-on::after-request=htmx.ajax(...), **no hx-target** (inherits from outer wrapper)
- **T-2114 wrapper at `_review_acs.html:21`**: `<div hx-target="#content" hx-swap="innerHTML" hx-push-url="true">` — sets `#content` as the default target for every descendant
- **No `#content` element** in standalone review.html (template doesn't extend base.html per T-667 mobile-first design)
- **Sibling forms unaffected**: inception decide form (`_review_acs.html:121`) declares `hx-target="#ac-container"`; complete form (`_review_acs.html:133`) also declares `hx-target="#ac-container"`. Only the ac-check form is missing the override.

**Origin date of regression:** T-2114 landed at commit `4989c8cf` (`fix /review AC fragment bounce-back via wrapper-reset`). Before T-2114, the ac-check form had no inherited hx-target — no #content lookup, no targetError, click worked. T-2114 fixed a different bug (anchor bounce-back) but introduced this one. Classic L-295/L-316 class: structural rail solves one inheritance problem and creates another.

## Dialogue Log

### 2026-05-31 — User report
- **User:** *"http://192.168.10.107:3000/review/T-2131 :::: i tick the box nothing happens !!! regression sht ?? please incept RCA and fix"*
- **Agent investigation:** curl endpoint (works), Playwright open + click + console capture (htmx:targetError), form attribute audit (no hx-target → inherits #content → doesn't exist → abort)
- **Recommended GO** on three-leg fix (surgical attribute, test pin, wrapper audit)

## Decisions

### 2026-05-31 — Surgical fix vs wrapper removal
- **Chose:** Surgical fix (add hx-target="this" on ac-check form)
- **Why:** T-2114 wrapper solves a real bounce-back on markdown-rendered URLs inside AC body (see T-2114 RCA). Removing the wrapper would re-introduce that bug. The wrapper's "every form must set hx-target explicitly" contract is already honoured by the other two forms; the ac-check form is the only sibling missing it.
- **Rejected:** (a) Remove T-2114 wrapper (re-opens the bounce-back); (b) Change wrapper target to something that exists like `body` (semantically wrong — body isn't a swap target); (c) Use `hx-disinherit="hx-target"` on the wrapper (would also disable target inheritance for legitimate descendants like AC body links).

## Decision

<!-- Filled at completion via: fw inception decide T-2133 go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion. -->

### 2026-05-31T07:13:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
