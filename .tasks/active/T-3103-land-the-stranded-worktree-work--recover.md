---
id: T-3103
name: "Land the stranded worktree work — recover genuinely-unlanded artifacts before teardown"
description: >
  OBS-174 follow-up. Content audit of the 43 unlanded commits on worktree-inception-gov-payload-mediation (6) and worktree-rca-worktree-push-strand (37): nearly all content is already on master. Genuinely unlanded = 3 task files, all three colliding on IDs now owned by unrelated tasks (T-2505, T-2506, T-2428). The 24 source files on the strands are ~2 months stale and would regress master. Recover the unique artifacts verbatim with provenance so the worktrees can be torn down losing nothing.

status: started-work
workflow_type: build
owner: claude-code
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
created: 2026-08-20T09:55:36Z
last_update: 2026-08-20T09:55:36Z
date_finished: null
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

# T-3103: Land the stranded worktree work — recover genuinely-unlanded artifacts before teardown

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every deliverable file on both strands is classified as already-landed / genuinely-unlanded / stale-source, with byte-level (md5) evidence for the already-landed claims
- [x] The three genuinely-unlanded task files are recovered verbatim onto master under `docs/recovered/strand-2026-07/`, preserving original filenames and content
- [x] A manifest `docs/recovered/strand-2026-07/README.md` records, per artifact: origin branch, origin commit, why it was unlanded, and what supersedes it
- [x] The manifest states explicitly which files were NOT landed and why — specifically the 24 source files that are ~2 months stale and would revert master
- [x] `docs/reports/T-3103-strand-recovery.md` carries the full content audit including the ID-collision table (strand ID vs the task that owns that ID on master)
- [x] No task file is written into `.tasks/` under a colliding ID, and `fw audit` still reports no duplicate task IDs
- [x] After recovery, `git diff origin/master...<branch>` for both strands contains no deliverable that is absent from master in content (verified per file, not asserted)

## Verification

# T-3103 — strand recovery. Comments only above this line.
test -f docs/recovered/strand-2026-07/README.md
test -f docs/reports/T-3103-strand-recovery.md
# the three recovered files are byte-identical to their strand originals
test "$(git show worktree-inception-gov-payload-mediation:.tasks/active/T-2505-worktree-usage-policy--refine-per-task-d.md | md5sum | cut -d" " -f1)" = "$(md5sum docs/recovered/strand-2026-07/T-2505-worktree-usage-policy--refine-per-task-default.task.md | cut -d" " -f1)"
test "$(git show worktree-inception-gov-payload-mediation:.tasks/active/T-2506-reconcile-main-checkout-stranded-uncommi.md | md5sum | cut -d" " -f1)" = "$(md5sum docs/recovered/strand-2026-07/T-2506-reconcile-main-checkout-stranded-uncommitted.task.md | cut -d" " -f1)"
test "$(git show worktree-rca-worktree-push-strand:.tasks/active/T-2428-worktree-teardown-strands-unpushed-commi.md | md5sum | cut -d" " -f1)" = "$(md5sum docs/recovered/strand-2026-07/T-2428-worktree-teardown-strands-unpushed-commits.task.md | cut -d" " -f1)"
# the T-2505 research artifact really is already on master, under the T-2822 prior-art name
test "$(git show worktree-inception-gov-payload-mediation:docs/reports/T-2505-worktree-usage-policy.md | md5sum | cut -d" " -f1)" = "$(md5sum docs/reports/T-2822-prior-art-stranded-worktree-usage-policy.md | cut -d" " -f1)"
# no colliding task IDs were filed into .tasks/
test -z "$(ls .tasks/active/T-2505-worktree-usage-policy* 2>/dev/null)"
test -z "$(ls .tasks/active/T-2506-reconcile-main-checkout* 2>/dev/null)"

## RCA

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

### 2026-08-20T09:55:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3103-land-the-stranded-worktree-work--recover.md
- **Context:** Initial task creation
