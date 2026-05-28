---
id: T-2081
name: "RCA: complete button reappears for 1-2s after successful task complete on /review/T-XXX"
description: >
  Inception: RCA: complete button reappears for 1-2s after successful task complete
  on /review/T-XXX

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-05-28T20:48:44Z
last_update: 2026-05-28T20:49:07Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-05-28T20:49:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
      F1: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2081: RCA: complete button reappears for 1-2s after successful task complete on /review/T-XXX

## Problem Statement

On `/review/T-XXX`, after the human clicks **Complete Task** and the task DOES correctly transition to `work-completed`, the Complete button briefly **reappears for 1-2 seconds** before the page settles into the completed state. The completion mechanic works; the UI re-render race is the bug.

User-reported, S-2026-0528 session. Observed on T-2079 close immediately after this session's earlier work. The fact that the underlying state IS correct rules out the trivial explanation ("htmx swap targeted wrong element"). The transient re-appearance points at a **render-ordering race** — something paints the pre-completion state after the htmx swap landed.

One inception, one question (CLAUDE.md): **why does the Complete button transiently re-render after the swap has already replaced the AC container with the completed-state fragment?**

## Assumptions

- **A1** — The Complete button is rendered by `web/templates/_review_acs.html` (the `complete-section` block at L101-105). It hits `hx-post="/api/task/{{ task_id }}/complete"` with `hx-target="#ac-container" hx-swap="innerHTML"`.
- **A2** — The htmx swap targets `#ac-container` and the response is the *new* AC fragment (rendered server-side from the now-completed task), so the button should not appear in the response payload.
- **A3** — Werkzeug/Flask sessions stay sticky during the swap (no auth race).
- **A4** — There is no client-side polling that could re-fetch the page mid-swap, but there may be **base.html-level htmx behaviour** (e.g., body-level `hx-target`, view-transitions, or a SSE feed that re-renders the section).

## Exploration Plan

Time-boxed: ≤45 min for the spike, ≤15 min to write the recommendation.

1. **Reproduce + capture frames** — Open `/review/T-XXX` on a fresh active task, click Complete, screen-record (or Playwright video-trace) the 2-second window. Confirm the button visibly reappears.
2. **Network trace** — DevTools Network panel during the click. List every request the server sees from the click instant + 2 seconds. Likely candidates: the `POST /api/task/.../complete` itself (expected), any `GET` that follows (NOT expected), an SSE re-connect, an htmx oob swap.
3. **Server response inspection** — Inspect the literal body the `POST .../complete` returns. Does it include the Complete button HTML? (If yes, the bug is server-side: completion-state branch not taken.) Does it include only the completed-state fragment? (Then the bug is client-side: something else paints over the swap.)
4. **DOM diff timeline** — Use a `MutationObserver` on `#ac-container` to log every innerHTML mutation in the 3 seconds around the click. Identify any second mutation after the htmx swap.
5. **Hypotheses (in priority order):**
   - **H1**: `/review/T-XXX` extends `base.html` which sets a body-level `hx-target="#content"`. The Complete form's `hx-target="#ac-container"` overrides it, but a *follow-on* swap or boost may re-target `#content`, re-rendering the entire page (including the pre-completion server snapshot if the GET response is cached or stale).
   - **H2**: The completion handler returns the *whole* `_review_acs.html` partial, but Flask's session/template render briefly serves the cached pre-completion task state because the on-disk move (active → completed) hasn't landed before the re-render.
   - **H3**: Background htmx polling (SSE / cron-poll) on `#ac-container` fires within the window and re-renders from a stale source.
   - **H4**: View Transitions or htmx settling delay creates a visible double-render.
6. **Identify the structural cause** — Disprove H1-H4 systematically until one explains the observation. Write the RCA in the research artifact.

## Technical Constraints

- Flask dev server (Werkzeug, single-threaded by default) — race conditions are timing-driven, not concurrency.
- htmx 2.0.4 (vendored).
- Chrome browser primary; Playwright also instruments the same DOM.
- The task transition (`active/` → `completed/`) happens via `update-task.sh` invoked by the POST handler — disk-side and template-render are sequential within the request lifecycle.

## Scope Fence

**IN scope:**
- Identifying the render race that causes the button to transiently reappear on `/review/T-XXX` after a successful Complete.
- Naming the structural cause (server response shape vs client htmx flow vs other UI overlay).

**OUT of scope (separate inceptions if needed):**
- Any redesign of the `/review/T-XXX` page (T-1990 / arc-007 already covers redesign).
- Fixing other htmx render races on different surfaces.
- Adding loading spinners as a cosmetic mask without fixing the cause.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- One of H1-H4 (or a fifth hypothesis surfaced during exploration) is identified as the structural cause with a bounded, testable fix path
- The fix is scoped to one file (or one ordered pair: server response + client glue), reversible by git revert
- A regression-net is feasible: Playwright test that asserts `#ac-container` has exactly **one** innerHTML mutation in the 3-second window around a successful Complete click

**NO-GO if:**
- The race is browser-internal (compositor / view-transition timing) and cannot be deterministically prevented from the server or htmx attributes
- Fix requires a redesign of `/review/T-XXX` rendering — defer to arc-007 (T-1990) review-page sweep
- Repro is not reliable across at least 5/10 attempts in the spike (might be a one-off, not a class)

**DEFER if:**
- Exploration runs to time-box without naming the cause — surface findings, park the inception, revisit if the symptom recurs in ≥3 sessions

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** DEFER

**Rationale:**

User reports the Complete button on /review/T-XXX briefly reappears for ~1-2 seconds after a successful click, even though the task DOES correctly transition to work-completed. The completion mechanic is right; the UI re-render race is the bug. DEFER on a fix path until RCA names the structural cause (htmx swap ordering vs htmx polling vs explicit reload race) — premature symptom-patching here risks masking the real failure mode. One-question inception (per CLAUDE.md: 'one inception = one question').

**Evidence (filing time — to be expanded during exploration):**

- `web/templates/_review_acs.html:102` — `<form hx-post="/api/task/{{ task_id }}/complete" hx-target="#ac-container" hx-swap="innerHTML">` is the Complete form. The intended swap target is `#ac-container`.
- Symptom is reproducible (observed this session immediately after T-2079 close). NOT a one-off.
- The task DOES transition correctly to `work-completed` — the underlying mechanic works; only the UI rendering races.
- htmx is loaded at base.html; csrf-htmx.js injects the token automatically.
- Related rendering surface tasks: T-1990 (cockpit + approvals redesign), T-2063 (Complete button silent-fail / CSRF). T-2063 closed a *different* failure on the same button — useful prior art for the render path.

**Open question for the human (set before GO):**
- Should I run the spike now and revise Recommendation → GO with findings? Or park until the symptom recurs in another session?

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-28T20:49:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
