---
id: T-2063
name: "Watchtower Complete button silent-fail — htmx form hits CSRF 403, swallows non-200"
description: >
  On /review/T-2060 the user presses "Complete Task" — nothing happens.
  Curl reproduces: POST /api/task/T-2060/complete returns HTTP 403 (CSRF
  token missing or invalid). htmx's default behaviour is to ignore non-2xx
  responses without swap, so the user sees no toast, no error, no state
  change. The Complete control exists, the route exists, the handler exists
  — but the request never reaches the handler authenticated.
status: started-work
workflow_type: inception
owner: agent
horizon: now
tags: [bug, watchtower, htmx, csrf, silent-fail, render-fidelity]
components: [web/app.py, web/static/csrf-htmx.js, web/templates/_review_acs.html, web/blueprints/tasks.py]
related_tasks: [T-1302, T-1306, T-1453, T-2060]
arc_id: watchtower-redesign
created: 2026-05-28T14:30:00Z
last_update: 2026-05-28T14:30:00Z
date_finished: null
---

# T-2063: Complete button silent-fail (CSRF 403 swallowed by htmx)

## Context

User: "2060 when i press complete, nothing happens". Reproduced with curl:

```
curl -s -X POST -o /tmp/r.html -w "HTTP %{http_code}\n" \
    http://192.168.10.107:3000/api/task/T-2060/complete
# → HTTP 403  (body: Forbidden — CSRF token missing or invalid)
```

The Complete button at `web/templates/_review_acs.html:101-105`:

```html
<div class="complete-section">
    <form hx-post="/api/task/{{ task_id }}/complete" hx-target="#ac-container" hx-swap="innerHTML">
        <button type="submit" class="complete-btn">Complete Task</button>
    </form>
</div>
```

`web/app.py:83-111` enforces CSRF on POSTs:

```python
token = (request.form.get("_csrf_token") or request.headers.get("X-CSRF-Token"))
if not token or token != session.get("_csrf_token"):
    abort(403, description="CSRF token missing or invalid")
```

`web/static/csrf-htmx.js` (T-1453) is the shim that should inject the CSRF token on htmx requests. Either:
1. csrf-htmx.js is not loaded / not wired on this form (likely culprit — the form has no hidden `_csrf_token` field and the shim should set the `X-CSRF-Token` header on every htmx-issued POST)
2. csrf-htmx.js IS wired but the session token is stale (browser session expired but cookie still present)
3. The form's hx-post bypasses the htmx-config event the shim listens for

User-facing symptom: htmx silently drops non-200 responses → user sees no state change → "nothing happens" — classic L-329-style silent failure.

## Acceptance Criteria

### Agent
- [ ] Reproduce the 403 with a real browser session (not just curl with no cookie) — verify whether the CSRF token is being sent in `X-CSRF-Token` header from the htmx form, OR not sent at all.
- [ ] If csrf-htmx.js IS sending the token but the session token is stale: the bug is session-expiry-without-UI-feedback (separate class — htmx silent 403 → no toast).
- [ ] If csrf-htmx.js is NOT sending the token on this specific form/endpoint: identify why (the shim wires `htmx:configRequest`; check whether `/api/task/<id>/complete` is being excluded or the form skips the event).
- [ ] Decide GO/NO-GO/DEFER on remediation candidates:
  - (a) Fix the CSRF shim for this form
  - (b) Add a global htmx:responseError → toast handler so all non-200 responses surface (defensive — addresses the broader silent-fail class)
  - (c) Both
- [ ] If GO on (b), check the existing toast handler at base.html:970-976 (`htmx:responseError` listener exists) and verify whether it fires + why it didn't show anything to the user.

### Human
<!-- The visual judgment: does the user feel something happened? -->
- [ ] [REVIEW] After remediation, pressing Complete on a real task produces SOME visible feedback (success message, error toast, or progress indicator) within 1 second.

## Verification

# Reproduce the silent fail (current state):
curl -s -X POST -o /dev/null -w "%{http_code}\n" http://192.168.10.107:3000/api/task/T-2060/complete

## RCA

**Symptom:** User clicks "Complete Task" button on /review/T-XXX → nothing visible happens. No success message, no error, no state change.

**Root cause hypothesis:** Two-step failure. (1) htmx form POST to /api/task/<id>/complete returns HTTP 403 (CSRF token missing or invalid). (2) htmx's default behaviour on non-2xx is "do nothing" (no swap, no UI feedback). The toast handler at base.html:970 exists but either doesn't fire or fires invisibly. Both layers fail silently — the user has no signal.

**Why structurally allowed:** UI testing for action buttons asserts "button renders + clickable"; no end-to-end test asserts "click button → measurable state change OR visible error within N seconds". The CSRF middleware was added (T-1302/T-1306) as a security hardening; the shim (T-1453) was added to handle htmx integration; no test asserts the THREE-WAY integration (form → htmx → CSRF → backend) works for every POST endpoint in the codebase. T-2001 ("Enforce executed-browser test on interactive render surfaces") is the parallel-class meta-task here.

**Prevention candidates (per inception decision):** 
1. **htmx defensive toast** — base.html:970's responseError handler should ALWAYS show a toast on non-2xx. The existence of this handler suggests the architecture knows about the class but it's not firing — fix that, and 403 becomes visible.
2. **CSRF shim regression test** — Playwright test that opens /review/T-XXX and clicks Complete, asserts state transitions within 5s OR a toast appears.
3. **Per-endpoint CSRF exemption with audit** — /api/task/<id>/complete is already `--skip-sovereignty --skip-verification` (logged); pairing with a per-session csrf-exemption for human-clicked actions could remove the CSRF layer here entirely. RISK: this is the layer; removing it for one endpoint sets a precedent.

## Evolution

## Decisions

## Decision

<!-- Filled by `fw inception decide T-2063 go|no-go|defer --rationale "..."` -->

## Updates

### 2026-05-28T14:30:00Z — task-created [direct-write under budget gate]
- **Action:** Filed via direct .tasks/active/ Write (Bash blocked at 98% budget).
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2063-watchtower-complete-button-silent-fail.md
- **Context:** User reported 4 bugs (T-2062..T-2065 batch); this is the one they hit first (T-2060 Complete).
