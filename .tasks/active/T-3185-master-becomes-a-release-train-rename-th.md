---
id: T-3185
name: "Master becomes a release train: rename the session branch to bleeding-edge and land it on release only"
description: >
  Rename t2539-staging to bleeding-edge, make it the sanctioned development branch, and restrict master to receiving FF landings at release. Supersedes T-100196 session-on-master; dissolves the T-100201 PROTECT_MASTER conflict.

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
created: 2026-08-26T21:34:30Z
last_update: 2026-08-26T21:34:30Z
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

# T-3185: Master becomes a release train: rename the session branch to bleeding-edge and land it on release only

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Local branch renamed: `git branch --show-current` returns `bleeding-edge`, and `t2539-staging` no longer exists locally
- [x] `origin/bleeding-edge` exists and points at the same commit as local HEAD
- [x] CLAUDE.md §Trunk-Based Session Flow rewritten: `bleeding-edge` is the sanctioned development branch; `master` receives fast-forward landings at RELEASE only, never per-handover
- [x] The T-100196 "session runs on master" mechanism is explicitly superseded in writing, with its divergence rationale carried forward (bleeding-edge cannot fall behind master while it is master's only writer)
- [x] T-100201 recorded as DISSOLVED — the PROTECT_MASTER conflict needs no resolving, because master-as-merge-only IS the release-train policy
- [x] §Worktree Policy states that an explicitly-instructed worktree lands on `bleeding-edge`, never on `master` — a worktree landing on master would inject unreleased work into the consumer install surface
- [x] Follow-ups filed for tooling that cannot change in this task, each naming the reason: T-3186 (`fw sync` branch-nag + `fw integrate` default target) and T-3187 (doctor branch-identity guard, L-497) — both blocked tonight because T-3127 holds `bin/fw` uncommitted
- [ ] This task's commit does not touch `bin/fw` (T-3127 holds it dirty; same trap as T-3182)

### Human
- [ ] [REVIEW] GitHub mirror carries `bleeding-edge`
  **Steps:**
  1. Open the OneDev project settings for `agentic-engineering-framework` → PushRepository / mirror config
  2. Confirm the mirror pushes all branches, or add `bleeding-edge` explicitly
  3. Verify: `cd /opt/999-Agentic-Engineering-Framework && git ls-remote --heads github | grep bleeding-edge`
  **Expected:** `refs/heads/bleeding-edge` is listed on the GitHub remote
  **If not:** the public mirror carries only `master`, so development is invisible outside OneDev. Adjust the PushRepository branch filter.
  *(Agent cannot reach OneDev's admin surface — operator-side config.)*

- [ ] [REVIEW] Confirm deletion of the old `origin/t2539-staging` ref
  **Steps:**
  1. Evidence first: `cd /opt/999-Agentic-Engineering-Framework && git rev-list --count origin/master..origin/t2539-staging` — expect `0`
  2. Only if that returns 0: `cd /opt/999-Agentic-Engineering-Framework && git push origin --delete t2539-staging`
  **Expected:** count is 0, so the deleted ref's content is fully contained in master
  **If not:** count > 0 means the old branch holds commits master does not — do NOT delete; land them first.

## Verification

test "$(git branch --show-current)" = "bleeding-edge"
! git show-ref --verify --quiet refs/heads/t2539-staging
git show-ref --verify --quiet refs/remotes/origin/bleeding-edge
test "$(git rev-parse HEAD)" = "$(git rev-parse origin/bleeding-edge)"
grep -q "bleeding-edge" CLAUDE.md
grep -q "T-100201" CLAUDE.md
git show --stat --format= HEAD > /tmp/.t3185-stat 2>&1 && ! grep -qE "^ +bin/fw " /tmp/.t3185-stat

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

### 2026-08-26T21:34:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3185-master-becomes-a-release-train-rename-th.md
- **Context:** Initial task creation
