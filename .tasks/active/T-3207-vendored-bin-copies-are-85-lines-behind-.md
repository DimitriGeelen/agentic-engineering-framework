---
id: T-3207
name: "vendored bin copies are 85 lines behind the same commit that wrote them"
description: >
  vendored bin copies are 85 lines behind the same commit that wrote them

status: started-work
workflow_type: build
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
created: 2026-08-28T14:16:59Z
last_update: 2026-08-28T14:16:59Z
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

# T-3207: vendored bin copies are 85 lines behind the same commit that wrote them

## Context

**Filed on a measurement error. Retracted before any code was written.**

While landing T-3206 I checked whether the vendored `.agentic-framework/bin/`
copies needed syncing, by diffing them against `/tmp/fw.bak` and `/tmp/cfw.bak`.
Both differed, so I concluded the drift **predated** my change, decided not to
sync (reasoning that syncing would carry someone else's unfinished work into my
commit), and wrote that into T-3206's `## Decisions`. The push gate then refused,
and I filed this task claiming an 85-line pre-existing divergence.

All of it was wrong, from one flaw: **the backups were taken *after* I edited the
files.** `cp bin/fw /tmp/fw.bak` ran at the start of the mutation-testing block,
which was after the doctor block was already in. So the "before" state I measured
against was the "after" state. The 85 lines and the 14 lines are, exactly, my own
two additions.

Checked properly, against git rather than against my own artefact:

```
git show b4304ab0a:bin/fw        | diff - <(git show b4304ab0a:.agentic-framework/bin/fw)         # no output
git show b4304ab0a:bin/claude-fw | diff - <(git show b4304ab0a:.agentic-framework/bin/claude-fw)  # no output
```

Byte-identical at the commit before mine. There was never any pre-existing drift.
The only drift is the one T-3206 introduced, and syncing it is simply finishing
that change — not absorbing anyone else's.

**The reusable part.** This is the session's running theme landing on my own
measurement rather than on a test: *a control that is not a control.* A snapshot
taken after the change cannot serve as the "before". It looks exactly like a
baseline, it is named like one, and it silently answers a different question —
the same shape as a mutation that fails to mutate (T-3204 M3, T-3206 M2), and as
832's guard that reimplements its subject. The tell generalises: **if your
baseline was produced by the same session that made the change, prove it came
first, or get it from version control instead.**

**Why the gate deserves credit.** The self-vendor push gate (T-2240) refused the
push and named the exact class — *"consumers that vendor from origin would
inherit the divergence silently."* Landing mode's rule is that a bypass must
argue the gate was wrong; attempting that argument is what sent me back to
measure properly, and the gate was right and I was wrong. It caught a bad
decision, not just a stale file.

## Acceptance Criteria

> **This task was filed on a false premise and is retracted in place.** The title
> is wrong and is left standing rather than tidied away, so the record shows what
> was believed. There is no pre-existing vendor drift. See §Context.

### Agent
- [x] Retraction recorded: the "85 lines behind the same commit" premise is FALSE, disproven against git rather than against a local backup
- [x] `.agentic-framework/bin/fw` and `.agentic-framework/bin/claude-fw` are byte-identical to their repo sources
- [x] The self-vendor push gate (T-2240) passes without a bypass
- [x] T-3206's `## Decisions` entry "vendored copies deliberately NOT synced" is corrected in the completed record, since it was decided on the same bad measurement

### Human
<!-- No Human ACs. This task is a retraction plus a byte-for-byte comparison;
     both are deterministic shell checks, so per T-1878 they belong in
     ## Verification rather than behind a [REVIEW]. -->

## Verification

diff -q bin/fw .agentic-framework/bin/fw
diff -q bin/claude-fw .agentic-framework/bin/claude-fw
git show b4304ab0a:bin/fw | diff -q - <(git show b4304ab0a:.agentic-framework/bin/fw)
git show b4304ab0a:bin/claude-fw | diff -q - <(git show b4304ab0a:.agentic-framework/bin/claude-fw)
grep -q 'RETRACTED, see T-3207' .tasks/completed/T-3206-continuous-run-loop-cannot-report-that-i.md
grep -q 'pre-existing vendor drift' .tasks/completed/T-3206-continuous-run-loop-cannot-report-that-i.md

## RCA

**Symptom.** The self-vendor push gate refused T-3206's push. I had already
decided, in writing, that the vendored copies should not be synced.

**Root cause.** The decision rested on a comparison against `/tmp/fw.bak` and
`/tmp/cfw.bak`, which I created with `cp` at the start of the mutation-testing
block — *after* the source edits were already in. So the "before" I compared
against contained the change. Both files differed from the vendored copies by
exactly the size of my own additions (85 lines, 14 lines), and I read that as
evidence of drift I had not caused.

**Why it survived to a written decision.** The measurement produced a plausible
number and a plausible story (T-3182 had genuinely deferred work for a
neighbouring reason days earlier), so it confirmed an expectation instead of
testing one. Nothing about the output looked wrong; a stale-baseline diff is
indistinguishable from a real one by inspection.

**Prevention.** Not a new rail — the existing gate already caught it, which is
the correct outcome and the reason the error cost one push instead of shipping.
The transferable rule is an author-time one, recorded in §Context: **a baseline
produced by the same session that made the change must be proven to precede it,
or taken from version control instead.** The verification lines below deliberately
derive the disproof from `git show`, not from any local artefact, so they remain
re-runnable by anyone and cannot inherit this class of error.

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

### 2026-08-28T14:16:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3207-vendored-bin-copies-are-85-lines-behind-.md
- **Context:** Initial task creation
