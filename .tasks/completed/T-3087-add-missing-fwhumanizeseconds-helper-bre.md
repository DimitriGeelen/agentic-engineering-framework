---
id: T-3087
name: "Add missing _fw_humanize_seconds helper (breaks fw tier0 approve/status)"
description: >
  Add missing _fw_humanize_seconds helper (breaks fw tier0 approve/status)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/config.sh]
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
created: 2026-08-19T19:33:38Z
last_update: 2026-08-19T19:37:23Z
date_finished: 2026-08-19T19:37:23Z
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
---

# T-3087: Add missing _fw_humanize_seconds helper

## Context

`_fw_humanize_seconds` was called at `bin/fw:6371` (tier0 branch, all subcommands) and
`bin/fw:6628` (`fw approvals help`) but was **defined nowhere in the repo**. Both call
sites are part of the T-3080 change that quotes the resolved Tier 0 grant window instead
of a hard-coded literal.

The defect was masked: the T-3086 fork bomb detonated two lines earlier, inside
`source lib/config.sh`, so execution never reached line 6371. With T-3086 fixed,
`fw tier0 approve` failed with `_fw_humanize_seconds: command not found` (exit 127),
meaning Tier 0 approvals could not be granted via the CLI at all.

Helper added to `lib/config.sh`, which both call sites source immediately beforehand.
Non-numeric or empty input echoes back unchanged — these are message strings, so an odd
value should surface in the text rather than abort the command.

## Acceptance Criteria

### Agent
- [x] `_fw_humanize_seconds` defined in `lib/config.sh`
- [x] `bash -n lib/config.sh` passes
- [x] Formats correctly: 300 -> "5 minutes", 3600 -> "1 hour", 90 -> "1 minute 30 seconds", 1 -> "1 second"
- [x] Singular/plural handled; multi-unit composes (90061 -> "1 day 1 hour 1 minute 1 second")
- [x] Non-numeric input passes through unchanged; empty input does not error
- [x] `fw tier0 approve` reaches its own logic instead of exiting 127
- [x] `fw tier0 status` runs clean
- [x] `fw approvals help` prints "300s (5 minutes)"
- [x] approve success branch prints "expires in 5 minutes (300s)" (verified in isolated PROJECT_ROOT)

## Verification

# Syntax must be valid
bash -n lib/config.sh

# Helper must exist and be callable
bash -c 'source lib/config.sh; declare -F _fw_humanize_seconds >/dev/null'

# Formatting contract
test "$(bash -c 'source lib/config.sh; _fw_humanize_seconds 300')" = "5 minutes"
test "$(bash -c 'source lib/config.sh; _fw_humanize_seconds 3600')" = "1 hour"
test "$(bash -c 'source lib/config.sh; _fw_humanize_seconds 90')" = "1 minute 30 seconds"
test "$(bash -c 'source lib/config.sh; _fw_humanize_seconds 1')" = "1 second"
test "$(bash -c 'source lib/config.sh; _fw_humanize_seconds abc')" = "abc"

# Real call sites must not exit 127 (command not found)
bin/fw tier0 status >/dev/null 2>&1; test $? -ne 127
bin/fw approvals help > .context/working/.t3087.out 2>&1 && grep -q "300s (5 minutes)" .context/working/.t3087.out

## RCA

**Symptom:** `fw tier0 approve` exited 127 with `_fw_humanize_seconds: command not found`.
That is the operator's only CLI path for granting a Tier 0 approval, so for as long as it
held, a blocked destructive command could not be authorised from the terminal at all — the
Watchtower button was the only remaining route to a grant.

**Root cause:** the T-3080 change added two call sites (`bin/fw:6371` in the tier0 branch,
`bin/fw:6628` in `fw approvals help`) for a helper it never defined. Nothing in bash
objects to that at parse time: an undefined function is indistinguishable from an external
command until the line actually executes, so `bash -n` is green and the file looks fine.

**Why structurally allowed:** two gaps, and the second is the one worth keeping.

1. **The worker died before running anything it wrote.** T-3080 was dispatched to a
   TermLink worker that produced the edit and terminated without committing, without
   running its own `## Verification`, and without posting to the bus. Every gate the
   framework owns fires at commit or at close; none of them can fire for work that reaches
   disk and stops. Same structural leg as T-3086's third gap — **the working tree is
   production for anything `bin/fw` sources or executes**, and it is ungated by
   construction.
2. **The defect was masked by a second defect in the same edit.** The T-3086 fork bomb
   detonated inside `source lib/config.sh`, two lines *before* the call site. So the first
   symptom anyone could observe was the OOM, not the 127. Fixing T-3086 is what made T-3087
   visible. This is the general shape worth naming: **when one edit introduces two faults
   and the earlier one aborts execution, the later one is invisible until the earlier one is
   fixed** — so "the fix worked, the command runs now" is not a safe conclusion to draw from
   a single green run after removing a crash. The correct move after clearing a crashing
   defect is to re-exercise the *whole* path the crash was hiding, which is what surfaced
   this.

**Prevention** (distinct from the fix):

- The `## Verification` block added here calls the two real call sites (`fw tier0 status`,
  `fw approvals help`) rather than only unit-testing the helper, so a future edit that
  removes or renames it fails on the surface the operator actually uses.
- A shellcheck-style rail over `bin/fw` for called-but-undefined functions would catch this
  class at author time. **Not written** — this task does not add it, and until it exists the
  class stays open for any function `bin/fw` calls but does not define.
- Dispatch-side: a worker that dies without committing leaves live edits with no gate. Worth
  a rail that surfaces "dispatch ended, working tree dirty, nothing committed" rather than
  leaving the parent to notice. Also not written here.

**What actually caught it:** running the command. Not a test, not a gate, not a review — the
operator's own workflow, one layer down from a crash that had been hiding it.


<!-- REQUIRED for bug-class tasks (workflow_type=build with bug-tag, OR title matches
     fix/bug/rca/broken/crash/error/regression/fail/hotfix).
     Non-bug-class tasks may leave this section empty or remove it.

     For bug-class, fill in:
       **Symptom:** what was observed (the user-facing manifestation).
       **Root cause:** the specific structural/logical gap — not "the code was wrong".
       **Why structurally allowed:** what in the framework/code/tooling let this go undetected.
       **Prevention:** what catches the next instance (test/lint/gate/doc/learning) — distinct from the fix itself.

     The completion gate (T-1550, G-019) blocks --status work-completed when
     bug-class AND this section is empty/template-only. Use --skip-rca to bypass (logged).
-->

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

### 2026-08-19T19:33:38Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3087-add-missing-fwhumanizeseconds-helper-bre.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b72c7d28
- **Timestamp:** 2026-08-19T19:37:25Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-19T19:37:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
