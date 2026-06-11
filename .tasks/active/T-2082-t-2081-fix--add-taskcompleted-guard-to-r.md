---
id: T-2082
name: "T-2081 fix — add task_completed guard to review_acs_fragment polling endpoint
  (L-441 sibling of T-1575)"
description: >
  T-2081 fix — add task_completed guard to review_acs_fragment polling endpoint (L-441
  sibling of T-1575)

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [web/blueprints/review.py, web/templates/_review_acs.html]
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
created: 2026-05-28T21:21:11Z
last_update: '2026-06-11T22:23:31Z'
date_finished: 2026-05-28T21:28:36Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── BVP scoring fields (T-1918, arc-006). See docs/reports/T-1915-bvp-inception.md for semantics. ──
# bvp_scores:                     # confirmed per-driver scores 0-5, set by `fw bvp confirm` (T-1924).
#                                 # Sovereignty boundary — only set after human or agent confirmation.
#                                 # Shape: {D1: <int 0-5>, D2: <int 0-5>, D3: <int 0-5>, D4: <int 0-5>, [<free-driver-id>: <int>]...}
# bvp_scores_proposed:            # estimator-proposed scores (T-1922 worker). Persists when ≥2 delta
#                                 # from bvp_scores: on any driver (M3 v2-delta). Shape: list of timestamped entries.
# cost_estimate:                  # F8 composite: 0.6×blast_radius + 0.3×tier + 0.1×effort.
#                                 # Q2 fallback: T-shirt S/M/L/XL mapped to 2/4/6/8 when blast_radius is not yet computable.
bvp_scores_proposed:
  - ts: '2026-05-28T22:52:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T22:23:31Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=2 
      (body:default-change); D4=2 (body:env-class-handled); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2082: T-2081 fix — add task_completed guard to review_acs_fragment polling endpoint (L-441 sibling of T-1575)

## Context

Ships the fix for T-2081 (inception). RCA in `docs/reports/T-2081-review-complete-button-render-race.md`. L-441 sibling of T-1575 — non-inception branch of the polling-overwrites-recorded-state race on `#ac-container`.

## Acceptance Criteria

### Agent
- [x] `web/blueprints/review.py:review_acs_fragment` — `task_completed = status in ('work-completed', 'completed')` computed and passed to template (review.py:285-294).
- [x] `web/templates/_review_acs.html` — `{% elif task_completed %}` branch added between `decision_recorded` and `all_checked` blocks; renders "✓ Task completed" panel with id `task-completed-marker` (mirrors T-1575 shape).
- [x] `tests/playwright/test_review_complete_render_race.py` — two pinning tests: (a) `Complete Task` absent on completed-task poll endpoint, (b) `task-completed-marker` panel renders. Both green (2/2).
- [x] Existing tests pass — `test_bvp_form_htmx.py` (5), `test_bvp_sliders.py` (8), `test_bvp_scatter.py` (7). Full run: 22/22 pass (2 new + 20 regression).

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.

     ── Prefix routing (T-1811, T-1878): default to [REVIEWER] if Expected is grep-able ──
     If your Expected clause is grep-able / file-exists / structural (a deterministic
     shell check), prefer [REVIEWER] — that AC should be an Agent AC with the reviewer
     command in `## Verification` instead of a Human AC here. Only keep [REVIEW] if
     verification genuinely needs human taste (tone, feel, layout rhythm).
     See CLAUDE.md §AC Classification Guidance for the conversion rule.

     [REVIEW] example (genuine human judgment):
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error

     [REVIEWER] example (static-scan-verifiable — convert to Agent AC + Verification):
       - [ ] [REVIEWER] Block message names both bypass mechanisms
         **Steps:**
         1. Run `bin/fw reviewer T-XXX`
         **Expected:** Verdict: PASS; no findings on `block-message-completeness`
         **If not:** Inspect hook block-message string and add missing mechanism
       Conversion: this AC should be moved to ### Agent and
       `bin/fw reviewer T-XXX 2>&1 | grep -q "Overall:.*PASS"` added to ## Verification.
-->
- [ ] [REVIEW] Complete a task on `/review/T-XXX` in the browser, then watch for 10 seconds — the Complete button does NOT reappear; the "✓ Task completed" panel stays put.
  **Steps:**
  1. Pick an active build task with all Human ACs ticked (or use an existing partial-complete and tick the ACs)
  2. Open `/review/T-XXX` in browser
  3. Click **Complete Task** and start a 10-second watch
  4. Confirm the success panel renders and stays — button never reappears
  **Expected:** Success panel persists; no flicker of the Complete button at the 1-5 second mark
  **If not:** Note the URL of the task you tested + what time the button reappeared

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

# T-2082 — guard prevents Complete button re-render on completed tasks.
# (L-387 safe: grep on a file, not on a pipe — only `cmd | grep -q` hits SIGPIPE.)
curl -sS "$(bin/fw watchtower url)/review/T-2079/acs" > /tmp/.t2082-completed 2>&1
# After fix: completed task's /acs poll endpoint MUST NOT include the Complete Task button.
! grep -qF "Complete Task" /tmp/.t2082-completed
# Playwright regression net is green.
FW_TEST_PORT=3000 PROJECT_ROOT=/opt/999-Agentic-Engineering-Framework python3 -m pytest tests/playwright/test_review_complete_render_race.py -q > /tmp/.pw-2082.log 2>&1
grep -q "passed" /tmp/.pw-2082.log

## RCA

**Symptom:** Complete button on `/review/T-XXX` briefly reappears ~1-2s after a successful click, even though the task DOES correctly transition to `work-completed`.

**Root cause:** `#ac-container` carries `hx-trigger="every 5s"` on `web/templates/review.html:592`. The polling endpoint `review_acs_fragment` re-renders `_review_acs.html` from disk. T-1575 added a `decision_recorded` guard so inceptions' recorded decisions wouldn't be wiped by the next poll — but the non-inception sibling case (build tasks whose status crossed to `work-completed`) was missed. The template branch at L75-106 falls through to the Complete-button block whenever `all_checked && total_count > 0 && workflow_type != 'inception'`, regardless of completion status.

**Why structurally allowed:** Sibling-occurrence (L-441) class. T-1575's commit closed exactly this race for inceptions; the patch scoped only to the `decision_recorded` flag. No sibling-sweep was done at the time — the non-inception leg with the logically identical race was never closed. The Playwright net for review-page rendering didn't include a "completed task's polling endpoint returns no Complete button" assertion until this task.

**Prevention:** New Playwright test `tests/playwright/test_review_complete_render_race.py` asserts the exact contract that was missed — `GET /review/<id>/acs` on a `work-completed` build task must not contain `Complete Task`. Any future regression that re-introduces the template falling through to the Complete branch on a completed task fails this test. Empirical proof against T-2079 (already completed) seeded the test.

Full RCA (with line citations + timeline + fix narrative): `docs/reports/T-2081-review-complete-button-render-race.md`.

## Evolution

<!-- REQUIRED for arc-tagged build tasks (tags include arc:*). Captures how
     understanding evolved during build — what was learned that wasn't known at
     filing, what in the original plan no longer fits, what triggered pivots
     or new sub-tasks. Mandatory at slice boundaries (when applicable) and
     before --status work-completed.

     Origin: T-1717 grill Q4 — "the understanding of what we need and want
     evolves with the process of materialisation." Structural counter to §ACD:
     spec-vs-build divergence is logged as soon as it happens, not lost as
     folklore.

     Format (one entry per slice boundary or significant insight):
       ### YYYY-MM-DD — [topic]
       - **What changed:** [what we learned that we didn't know at filing]
       - **Plan impact:** [what in the plan no longer fits]
       - **Triggered:** [new sub-task / pivot / scope cut, with task ID if filed]

     The completion gate (T-1718) blocks --status work-completed when this
     section exists but is empty/template-only. Use --skip-evolution to bypass
     (logged Tier-2). Non-arc tasks may leave this empty.
-->

## Recommendation

**Recommendation:** GO (Human eyes-on the post-complete UI, then close)

**Rationale:**

Ships T-2081's bounded fix. The polling endpoint now short-circuits to the `task-completed-marker` panel for work-completed tasks, mirroring the T-1575 `decision_recorded` guard at the sibling level — closes the L-441 non-inception leg that was missed at T-1575 time.

Empirically verified: pre-fix curl on T-2079's poll endpoint returned `Complete Task` button HTML (grep count = 2); post-fix curl returns 0 hits on `Complete Task` and 1 hit on `task-completed-marker`. Regression net (Playwright) pins both halves of the contract.

**Evidence:**

- `web/blueprints/review.py:285-294` — new `task_completed` flag, passed to template.
- `web/templates/_review_acs.html:75-86` — new `{% elif task_completed %}` branch with `task-completed-marker` id (stable contract for tests).
- `tests/playwright/test_review_complete_render_race.py` — 2 tests pin the contract.
- Pre-/post-fix curl on `/review/T-2079/acs`:
  - Before: `grep -c "Complete Task" = 2`
  - After: `grep -c "Complete Task" = 0`, `grep -c "task-completed-marker" = 1`
- Full Playwright run: 22/22 pass (2 new + 20 regression across BVP + review surfaces).
- RCA + fix narrative: `docs/reports/T-2081-review-complete-button-render-race.md`.

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

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-05-28T21:21:11Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2082-t-2081-fix--add-taskcompleted-guard-to-r.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-05f34451
- **Timestamp:** 2026-05-28T21:28:54Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `web/blueprints/review.py:review_acs_fragment` — `task_completed = status in ('work-completed', 'completed')` computed and passed to template (review.py:285-294).
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/blueprints/review.py in: `web/blueprints/review.py:review_acs_fragment` — `task_completed = status in ('work-completed', 'completed')` computed and passed to template (review.`
- **AC#2 (Agent)** — `web/templates/_review_acs.html` — `{% elif task_completed %}` branch added between `decision_recorded` and `all_checked` blocks; renders "✓ Task completed" panel with id `task-completed-marker` (mirr
  - **AC-verify-mismatch** (narrow, heuristic) — `path=web/templates/_review_acs.html in: `web/templates/_review_acs.html` — `{% elif task_completed %}` branch added between `decision_recorded` and `all_checked` blocks; renders "✓ Task comp`

### 2026-05-28T21:28:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
