---
id: T-2279
name: "CSRF-403 handler renders explicit recovery hint instead of bare 'Forbidden'
  — operator-experience polish"
description: >
  Inception: CSRF-403 handler renders explicit recovery hint instead of bare 'Forbidden'
  — operator-experience polish

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-06-09T08:38:00Z
last_update: 2026-06-09T08:38:59Z
date_finished:
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
bvp_scores_proposed:
  - ts: '2026-06-09T08:38:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2279: CSRF-403 handler renders explicit recovery hint instead of bare 'Forbidden' — operator-experience polish

## Problem Statement

T-2277 Leg B follow-on. Parent RCA established the cross-Watchtower
session-cookie collision class. Leg A (T-2278) eliminates the failure;
Leg B is the **operator-experience polish** for the residual cases
(e.g. cookie expired, server restart mid-form, browser cleared
cookies). Today the 403 handler (`web/app.py:359-370`) renders a
generic "Forbidden" page with no recovery hint — operator sees a
dead-end. Leg B detects the CSRF-specific 403 description and renders
explicit recovery instructions instead.

See `docs/reports/T-2277-watchtower-csrf-pollution.md` §"Diagnostic
enrichment (Leg B)" for the full design.

## Assumptions

- **A1:** Flask's `abort(403, description="CSRF token missing or invalid")`
  surfaces the description string to the error handler (verified —
  `web/app.py:111` + Flask docs).
- **A2:** Rendering a Jinja template inside the 403 handler is safe
  (cannot recurse into another 403 because templates don't authenticate).
- **A3:** Operators reading a recovery hint will follow it before
  filing a bug report (UX assumption, low-risk).

## Open Questions

- **IW-1: One CSRF-specific template vs CSRF-branch inside generic `_error.html`?**
  confidence: 2
  disposition: answered
  rationale: New `_error_csrf.html` template is cleaner — separates
  recovery copy from generic error layout. Jinja `include` keeps it
  composable. Generic `_error.html` stays untouched for non-CSRF 403s.

- **IW-2: Should the recovery hint name the OTHER Watchtower instances on this host?**
  confidence: 1
  disposition: deferred
  rationale: Would require live `ss`/process scan from the request
  handler — extra latency for marginal info. Defer to T-2280 (Leg C
  / `fw doctor` cross-instance scan) which surfaces the same data
  out-of-band. Recovery hint stays generic ("close other Watchtower
  tabs on this host") in Leg B.

## Exploration Plan

RCA already done in parent T-2277. Implementation plan:

1. Detect CSRF description in 403 handler (1 line `if` branch).
2. New `web/templates/_error_csrf.html` with port, project_name,
   recovery steps.
3. Test (`tests/unit/test_csrf_403_recovery.py`): POST without
   `_csrf_token` → response body contains "Reload this page" and
   the project_name + port from `app.config["SESSION_COOKIE_NAME"]`.

## Technical Constraints

- Must not affect non-CSRF 403s (e.g. fabric.py:406 returns plain
  "Forbidden" — keep that path).
- Recovery template must work without a valid session (it's rendered
  ON 403, the user has no session by definition).
- Don't reveal internal info (secret_key paths, file system state).

## Scope Fence

**IN scope:**
- 403 handler CSRF-description detection + branch.
- New `_error_csrf.html` template.
- One unit test.

**OUT of scope:**
- Auto-reload (JS) — let the operator press Ctrl+Shift+R themselves.
- Live cross-instance scan in the handler (deferred to T-2280).
- Touching `fabric.py:406` or other ad-hoc 403 sites.

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

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

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

**Recommendation:** GO

**Rationale:**

Current 403 handler (web/app.py:359-370) renders generic 'Forbidden' with no recovery hint, leaving operators at a dead-end. Detect description starting with 'CSRF token missing or invalid' and render explicit recovery template ('Reload page Ctrl+Shift+R to mint fresh token; close other Watchtower tabs'). ~10-line handler branch + ~30-line _error_csrf.html template. Blast radius: zero (purely cosmetic/diagnostic, no auth-path change). Origin: T-2277 Leg B.

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

### 2026-06-09T08:38:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
