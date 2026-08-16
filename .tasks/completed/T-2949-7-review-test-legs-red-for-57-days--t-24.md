---
id: T-2949
name: "7 review test legs red for 57 days — T-2421 extended the rec-gate past its
  own fixtures"
description: >
  T-2421 (2026-06-16) extended the empty-Recommendation BLOCK from inceptions to partial-complete
  build-class tasks, but did not update the test fixtures that must satisfy it. tests/unit/lib_review.bats
  (5 legs) and tests/unit/review_link_blocking_gate.bats (2 legs) build fixtures with
  1/3 Human ACs checked and no ## Recommendation, so emit_review now returns 1 and
  the legs fail. The fixture helper still carries the comment 'Build tasks do not
  gate on Recommendation, so the heading is conditional' — true under T-2206, made
  false by T-2421. Proven: same fixture plus a Recommendation block returns rc=0 and
  prints 1/3. Third artefact of one gate extension (code updated; template not, T-2945/832-T-455;
  fixtures not, this). 57 days red and nobody looked — G-019 territory, register a
  gap.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/review.sh, tests/unit/lib_review.bats, 
      tests/unit/review_link_blocking_gate.bats, 
      tests/unit/t2948_review_human_ac_comment_aware.bats]
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
created: 2026-08-12T14:45:28Z
last_update: '2026-08-16T22:25:24Z'
date_finished: 2026-08-12T15:16:54Z
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
  - ts: '2026-08-12T14:48:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 2
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=2
      (body:default-change); D4=0 (no-signal); F-RECALL=2 
      (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-08-12T15:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2949: 7 review test legs red for 57 days — T-2421 extended the rec-gate past its own fixtures

## Context

Found incidentally: T-2948 ran the neighbouring review suites to prove it had not caused a
regression, and 7 legs were already red. They had been red since T-2421 landed on
2026-06-16 — **57 days** — and nothing surfaced it.


## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] All 7 legs green: `lib_review.bats` 13/13 and `review_link_blocking_gate.bats` 5/5
- [x] The fixtures are fixed by giving partial-complete build tasks a `## Recommendation`
      (what T-2421 actually requires), NOT by setting `FW_ALLOW_EMPTY_RECOMMENDATION=1` —
      bypassing the gate in its own test would make the suite blind to the thing it guards
- [x] The stale fixture comment ("Build tasks do not gate on Recommendation") is corrected
      in place, since it is the sentence that made the breakage read as intentional
- [x] At least one leg asserts the gate still FIRES on a partial-complete build fixture with
      no Recommendation — the suite must cover T-2421's behaviour, not just tolerate it
- [x] A gap is registered in `concerns.yaml` for 57 days of unnoticed red (G-019: >7 days
      blind is systemic), naming what makes the next red suite visible — the fix here is
      mitigation, not prevention

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

# All 7 previously-red legs green, plus the new coverage leg.
out=$(timeout 300 bats tests/unit/lib_review.bats 2>&1); echo "$out" | grep -q '^ok 14 ' && ! echo "$out" | grep -q '^not ok'
out=$(timeout 300 bats tests/unit/review_link_blocking_gate.bats 2>&1); echo "$out" | grep -q '^ok 5 ' && ! echo "$out" | grep -q '^not ok'
# Sibling suites unaffected.
out=$(timeout 300 bats tests/unit/emit_review_ac_counter.bats 2>&1); echo "$out" | grep -q '^ok 6 ' && ! echo "$out" | grep -q '^not ok'
out=$(timeout 300 bats tests/unit/t2948_review_human_ac_comment_aware.bats 2>&1); echo "$out" | grep -q '^ok 6 ' && ! echo "$out" | grep -q '^not ok'
# Fixed by satisfying the gate, not by bypassing it in its own suite.
# (non-comment lines only — the files DISCUSS the bypass in a comment explaining why it was not used)
bash -c '! grep -E "^[[:space:]]*[^#[:space:]].*FW_ALLOW_EMPTY_RECOMMENDATION" tests/unit/lib_review.bats tests/unit/review_link_blocking_gate.bats'
# The gap is registered and the file still parses.
python3 -c "import yaml,sys; d=yaml.safe_load(open('.context/concerns.yaml')); sys.exit(0 if any(e.get('id')=='OBS-237' for e in d) else 1)"

## Evidence

### Before / after

    tests/unit/lib_review.bats                 8 ok / 5 not ok   ->  14 ok / 0 not ok
    tests/unit/review_link_blocking_gate.bats  3 ok / 2 not ok   ->   5 ok / 0 not ok

Plus the suites that were already green and had to stay so: `t2948` 6/6, `t2945` 6/6,
`emit_review_ac_counter` 6/6, `review_batch` 7/7. **44 legs, 0 red.**

The +1 in lib_review is new coverage, not a renamed leg — see below.

### Root cause, proven not assumed

Both suites build partial-complete build-class fixtures (1 of 3 Human ACs checked) with no
`## Recommendation`. T-2421 extended the empty-Recommendation BLOCK to exactly that state, so
`emit_review` began returning 1 where the legs asserted 0 or 2. Demonstrated on an isolated
fixture pair before touching either suite:

    fixture as-is              rc=1  BLOCKED
    fixture + Recommendation   rc=0  prints 1/3

### Why 57 days of red read as normal

The fixture helper carried:

    # Build tasks do not gate on Recommendation, so the heading is conditional.

True when T-2206 wrote it. Made false by T-2421. Anyone who looked at the red legs found a
written explanation that the conditional was deliberate — which is worse than no comment,
because it converts an anomaly into documented intent. Corrected in place rather than
deleted, with the date the sentence stopped being true.

### Fixed by satisfying the gate, not bypassing it

`FW_ALLOW_EMPTY_RECOMMENDATION=1` would have turned all 7 green in one line. Rejected:
bypassing a gate inside its own suite makes the suite blind to the thing it guards, which is
the same failure one layer up from the one being fixed.

Added instead: `review: T-2421 rec-gate BLOCKS a partial-complete build fixture with no
Recommendation` — strips the block back out and asserts the gate still fires, with a
non-vacuity check (`grep -c '^## Recommendation$'` = 0) so the leg cannot pass against a
fixture that still has one. Without it the suite would merely tolerate T-2421; a regression
disabling the gate would leave every leg green.

### The residual is the real finding

Nothing surfaces a persistently-red bats suite. `fw audit` and `fw doctor` do not run the
unit suites; no cron does; P-011 runs only the commands a task author writes — so a suite
nobody names in a Verification block is invisible **by construction**. This task is
mitigation. Registered as **OBS-237** (systemic, open) with prevention stated as not done.

## RCA

**Symptom:** 7 bats legs red continuously for 57 days, unreported by every automated surface.

**Root cause:** T-2421 extended a gate and updated the code that implements it, but not the
artefacts that must satisfy it. Third such artefact from one change — code (done), task
template (missed; T-2945, reported by 832 as T-455), test fixtures (missed; this).

**Why structurally allowed:** two independent holes. (1) No surface runs the unit suites on a
schedule, so red is only ever seen by someone who happens to run them. (2) A stale comment
asserted the broken behaviour was intentional, so the one human signal that could have
flagged it argued the other way.

**Blind for:** 2026-06-16 → 2026-08-12, 57 days. Well past G-019's 7-day systemic threshold.

**Prevention:** the leg asserting the gate still FIRES stops the suite from going green on a
regression — but that is coverage, not visibility. Visibility is unfixed and registered as
OBS-237. The honest statement is that the next gate extension can repeat this exactly.

**Credit:** surfaced by T-2948's regression check. Same session as 832's T-455 report, which
is the sibling artefact of the same 2026-06-16 change.

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

### 2026-08-12T14:45:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2949-7-review-test-legs-red-for-57-days--t-24.md
- **Context:** Initial task creation

### 2026-08-12T14:48:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2bafa906
- **Timestamp:** 2026-08-12T15:17:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-12T15:16:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
