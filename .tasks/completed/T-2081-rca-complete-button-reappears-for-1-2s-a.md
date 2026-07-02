---
id: T-2081
name: "RCA: complete button reappears for 1-2s after successful task complete on /review/T-XXX"
description: >
  Inception: RCA: complete button reappears for 1-2s after successful task complete
  on /review/T-XXX

status: work-completed
workflow_type: inception
owner: human
horizon: null
components: [web/blueprints/review.py, web/templates/_review_acs.html]
related_tasks: []
created: 2026-05-28T20:48:44Z
last_update: '2026-06-11T22:24:07Z'
date_finished: 2026-05-28T21:32:22Z
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
  - ts: '2026-06-11T22:24:07Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-28T21:00:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
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
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Recommendation:** GO (spike done — root cause named, fix bounded to ~10 lines across one route + one template branch)

## Spike Findings (2026-05-28)

**H3 confirmed.** The `#ac-container` carries an `hx-trigger="every 5s"` poll at `web/templates/review.html:592-594`:

```html
<div id="ac-container"
     hx-get="/review/{{ task_id }}/acs"
     hx-trigger="every 5s">
```

The polling endpoint `web/blueprints/review.py:review_acs_fragment` (L252-298) re-renders `_review_acs.html` from the on-disk task. T-1575 added a `decision_recorded` guard (L278-284) so inceptions that have already had `fw inception decide` recorded don't have their "Decision recorded" panel wiped by the next poll. **There is no equivalent guard for non-inception completes.**

After the Complete button is pressed on a build task:

1. POST `/api/task/<id>/complete` → returns `<p>Task completed.</p>` + OOB swap (`web/blueprints/tasks.py:1029-1032`).
2. Response is swapped into `#ac-container` → button gone.
3. The poll timer was at some random position in its 5-second cycle when the click happened; within 1-5 seconds (mean ~2.5s — **matches user's "1-2 seconds" report**) it fires GET `/review/<id>/acs`.
4. The GET re-reads the task (now in `completed/`), parses Human ACs, computes `all_checked=True`, `total_count > 0`. The template branch at L75-106 of `_review_acs.html` falls through to `{% elif all_checked and total_count > 0 %}` → renders the Complete button **again** because:
   - `workflow_type` is not `inception` → falls past the inception-decide branch
   - There's no `task_completed` guard branch matching the inception's `decision_recorded` branch
5. Polled fragment overwrites `#ac-container` → **Complete button reappears**.

**Empirical proof (this session):**
- T-2079 is in `completed/` with `status: work-completed`.
- `curl /review/T-2079/acs` → response **still contains** `<div class="complete-section">` with the Complete Task button (`grep -c "Complete Task" = 2`).
- No "Decision recorded" rendering (it's a build task, not an inception, so the existing guard doesn't apply).

**Origin:** T-1575 closed exactly this race for inceptions ("the 5-second htmx poll on #ac-container wipes the success message and re-renders the GO/NO-GO/DEFER form, making it look like the decision didn't take" — direct quote from `_review_acs.html:65-66`). The non-inception sibling case was never closed. L-441 class (sibling-occurrence sweep).

## Fix Path (bounded, single PR)

**~10 lines total**, split across one route + one template:

1. `web/blueprints/review.py:review_acs_fragment` — compute `task_completed = fm.get("status") == "work-completed"`, pass to template.
2. `web/templates/_review_acs.html` — add a guard branch mirroring `decision_recorded`:
   ```jinja
   {% if decision_recorded %}
     ...existing inception-decide-recorded block...
   {% elif task_completed %}
     {# T-2081: non-inception sibling of T-1575 decision_recorded guard — without this,
        the 5-second poll wipes the POST swap and re-renders the Complete button. #}
     <div class="complete-section" id="task-completed-marker">
         <p style="...">✓ Task completed. <a href="/review/{{ task_id }}">Reload page</a> for fresh view.</p>
     </div>
   {% elif all_checked and total_count > 0 %}
     ...existing inception/build branch...
   {% endif %}
   ```
3. Regression net: Playwright test asserts `GET /review/<task_id>/acs` on a `work-completed` build task does NOT contain `<button class="complete-btn">`. Mirrors `test_bvp_form_htmx.py` shape.

## Open Sub-Question (resolvable inside the fix)

When a task is partial-complete (work-completed + owner=human + some Human ACs unchecked), should the Complete button STILL render so the human can finalise? Currently it does, but the `all_checked` precondition means the button only ever appears when all Human ACs are ticked. Partial-complete with unchecked Human ACs falls through silently — no Complete button. So the fix's guard `task_completed` is safe: it can short-circuit unconditionally once status crosses `work-completed`.

**Rationale:**

Spike done. Root cause = H3 confirmed: `#ac-container` carries a `hx-trigger="every 5s"` poll (`web/templates/review.html:592`); the polling GET `/review/<id>/acs` re-renders `_review_acs.html` from disk and the template branches to the Complete-button block whenever `all_checked && total_count > 0 && workflow_type != 'inception'`, regardless of whether the task is already `work-completed`. T-1575 closed this race for inceptions via a `decision_recorded` guard, but the non-inception sibling case (the build-task Complete button) was never closed — L-441 class. Direct empirical confirmation this session: T-2079 is in `completed/`; `curl /review/T-2079/acs` STILL returns `<button class="complete-btn">Complete Task</button>` (count=2 hits on "Complete Task").

Fix is bounded: ~10 LOC across `web/blueprints/review.py:review_acs_fragment` (compute `task_completed` flag) + `web/templates/_review_acs.html` (add guard branch mirroring `decision_recorded`). Regression-net is feasible: Playwright test asserts the poll endpoint on a completed task returns no Complete button.

**Evidence (post-spike):**

- `web/templates/review.html:592-594` — `<div id="ac-container" hx-get="/review/{{ task_id }}/acs" hx-trigger="every 5s">`. The 5-second poll is the timer that races the POST swap.
- `web/blueprints/review.py:252-298` — `review_acs_fragment` polling endpoint; has `decision_recorded` guard at L278-284 (T-1575) but no `task_completed` equivalent.
- `web/blueprints/tasks.py:1013-1033` — `complete_task` POST handler returns `<p>Task completed.</p>` + OOB swap — does NOT cancel the polling on the surviving `#ac-container` element.
- `web/templates/_review_acs.html:75-106` — template branch that re-renders the Complete button whenever `all_checked && total_count > 0 && workflow_type != 'inception'`, with no `task_completed` short-circuit.
- **Empirical reproduction:** T-2079 is in `completed/` with `status: work-completed`. `curl http://192.168.10.107:3000/review/T-2079/acs` → response contains `<div class="complete-section">` and `<button class="complete-btn">Complete Task</button>` (grep counts 2 hits on "Complete Task"). The polling GET endpoint returns the Complete button HTML for a fully-completed task.
- **L-441 sibling:** T-1575 closed this race for inceptions (`decision_recorded` guard). The non-inception sibling case was missed in that fix. Same pattern, same template, same fix shape.
- Related rendering surface tasks: T-1990 (cockpit + approvals redesign), T-2063 (Complete button silent-fail / CSRF, different failure on same button — prior art for the render path).

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

**Decision**: GO

**Rationale**: Recommendation: GO (spike done — root cause named, fix bounded to ~10 lines across one route + one template branch)

**Date**: 2026-05-28T21:32:22Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-28T20:49:07Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-28T21:32:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO (spike done — root cause named, fix bounded to ~10 lines across one route + one template branch)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-207261dc
- **Timestamp:** 2026-06-02T15:01:03Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-28T21:32:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
