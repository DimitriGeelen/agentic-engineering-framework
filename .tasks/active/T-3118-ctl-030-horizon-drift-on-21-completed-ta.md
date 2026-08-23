---
id: T-3118
name: "CTL-030 horizon drift on 21 completed tasks blocks every push"
description: >
  CTL-030 horizon drift on 21 completed tasks blocks every push

status: started-work
workflow_type: refactor
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
# arc_id:                         # T-1849: optional — slug (e.g. "arc-grooming") OR arc-NNN (e.g. "arc-005")
#                                 # When set, must resolve to .context/arcs/<id>.yaml; PreToolUse hook
#                                 # (check-arc-id) blocks save under agent control if it doesn't resolve.
#                                 # Empty/missing → unassigned (allowed). See CLAUDE.md §Task System.
# demo_target: true               # T-2286: optional — marks task as reserved for an orchestrated demo
#                                 # worker (e.g. arc-010 HM-A dispatches via mcp__fw__work_on). When set,
#                                 # `fw work-on T-XXX` refuses unless --i-am-demo-orchestrator (CLI) or
#                                 # FW_I_AM_DEMO_ORCHESTRATOR=1 (env) is passed. Prevents the parent
#                                 # session from consuming the captured→started-work transition the demo
#                                 # worker expects to drive. Origin OBS-057.
created: 2026-08-23T11:08:48Z
last_update: '2026-08-23T11:15:13Z'
date_finished:
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
cost_estimate_proposed:
  - ts: '2026-08-23T11:15:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 3
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=3 
      (workflow:refactor); effort=8 (lines=204,acs=6)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-23T11:15:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3118: CTL-030 horizon drift on 21 completed tasks blocks every push

## Context

The pre-push audit refused every push: 21 completed tasks carried a non-null
`horizon:`, failing CTL-030. The audit names
`bin/migrate-horizon-null-completed.sh` in its own mitigation line for each
failure — so the fix was supposed to be one command.

It was not. The script's value pattern would have rewritten 2362 of the 2725
completed tasks and deleted a frontmatter line from each. This task fixes the
script, then runs it.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `bin/migrate-horizon-null-completed.sh` run; every file under `.tasks/completed/` carries `horizon:` null or absent. Re-running reports `0 changes` (the script's own idempotence contract).
- [x] `fw audit` reports zero `CTL-030` failures, down from 21.
- [x] No file outside `.tasks/completed/` was modified by the migration — the script's stated safety boundary, checked against `git status` rather than trusted.
- [x] `git push` to origin is no longer refused by the pre-push audit.

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

## Verification

out=$(bats tests/unit/t3118_horizon_migration_scope.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bin/migrate-horizon-null-completed.sh --dry-run > /tmp/.t3118.out 2>&1 && grep -q '^0 changes' /tmp/.t3118.out
grep -n 'HORIZON_RE = ' bin/migrate-horizon-null-completed.sh > /tmp/.t3118.re 2>&1 && grep -q 'S.n' /tmp/.t3118.re
! grep -h '^horizon:' .tasks/completed/T-*.md | grep -qvE '^horizon:[[:space:]]*(null|~)?[[:space:]]*(#.*)?$'
bin/fw audit --section structure > /tmp/.t3118.aud 2>&1 || true; ! grep -q 'CTL-030' /tmp/.t3118.aud

## RCA

**Symptom:** CTL-030 failed on 21 completed tasks, and the pre-push audit hook
refused every push to origin until they were fixed.

**Root cause (of the drift):** `horizon:` is written by `update-task.sh` at the
`work-completed` transition, but nothing nulls it on the way into `completed/`.
T-2160 moved render-time `past` to derive from `_location == 'completed'`, which
made the stored value behaviourally irrelevant but did not stop it being stored.
The 21 are tasks closed since the T-2161 one-shot migration ran.

**Root cause (of the trap in the fix):** the migration's value pattern opened
with `horizon:\s*`, and `\s` includes the newline. For an already-correct file —

    horizon:
    tags: []

— the match consumed the line break, took `tags: []` as horizon's value, and
rewrote both lines as a single `horizon: null`, deleting the following
frontmatter line. Measured before the fix: 2362 of 2725 files reported as
needing a change, against 21 real failures. `[^\S\n]` is horizontal whitespace
only; the distinction is the whole bug.

**Why structurally allowed:** the bug is invisible in the happy path. A file with
`horizon: now` migrates correctly under either pattern, and every exercise the
original migration got used that shape. The failing case is the file that is
*already correct* — the one nobody thinks to test, because the migration is
supposed to skip it. The script's own docstring asserted the safety property
("only touches files where the value is non-null/non-empty") that the regex did
not hold, and the audit repeated that assertion to the operator as advice.

**Prevention:** `tests/unit/t3118_horizon_migration_scope.bats` — 8 tests, every
one of which uses an already-correct file as its subject, plus a source-level
test asserting the pattern never spans a newline (greps for `[^\S\n]` and
against `horizon:\s*`). Test 8 checks the live corpus condition directly, so the
suite goes red on drift even if the audit is never run.

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

<!-- T-2945: same shape as inception.md's block — the gate that reads it
     (audit_inception_recommendation, lib/task-audit.sh:117) is shared, so the
     shape is copied rather than reinvented.

     REQUIRED once this task reaches partial-complete: Agent ACs done, at least
     one `### Human` AC still unticked. `lib/review.sh:205-211` (T-2421) BLOCKS
     `fw task review` emission for build/refactor/test/decommission tasks in that
     state with no substantive block here — the operator would otherwise open
     /review/<id> to a blank Recommendation card and be asked to approve a form.

     Not required while every Human AC is ticked or the task has none: the gate
     only fires on the partial-complete transition. It is here from the start so
     you write it while you still have the evidence, not when the gate refuses.

     Format (the parser wants the `**Recommendation:**` line at the start of a
     line; a leading `-` or `*` bullet is also accepted):
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence — what shipped, what was proven, what remains)
     **Evidence:**
     - Finding 1
     - Finding 2

     DEFER is for evidence gaps, not confidence gaps (CLAUDE.md §Presenting Work
     for Human Review). If the artefact is complete and you still don't want to
     commit, that is a calibration failure — recommend GO or NO-GO.
-->

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

### 2026-08-23T11:08:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3118-ctl-030-horizon-drift-on-21-completed-ta.md
- **Context:** Initial task creation
