---
id: T-3546
name: "P-011 reports nothing when it runs zero verification commands, so a silent
  skip is indistinguishable from a clean close"
description: >
  P-011 reports nothing when it runs zero verification commands, so a silent skip
  is indistinguishable from a clean close

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/task-create/update-task.sh, tests/unit/t3546_p011_reports_the_zero.bats]
related_tasks: []
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
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
created: 2026-09-28T22:57:22Z
last_update: 2026-09-28T23:14:41Z
date_finished: 2026-09-28T23:14:41Z
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
  - ts: '2026-09-28T23:00:13Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=319,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-28T23:00:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3546: P-011 reports nothing when it runs zero verification commands, so a silent skip is indistinguishable from a clean close

## Context

OBS-565. `run_verification_commands` returns at `update-task.sh:1176` with
`[ -z "$verify_cmds" ] && return 0` — **silently**. No line is printed, so a close that
verified nothing is textually identical to a close that had nothing to verify.

Hit live on T-3545, 2026-09-28. A splice landed its `## Verification` heading mid-sentence
inside the Human-AC template comment, whose own text contains the literal phrase
`added to ## Verification`. No heading existed at line start, the extractor returned empty,
the gate returned 0, and the close printed:

```
Acceptance criteria: 6/6 checked ✓
Disposition gate: all Open Questions disposed ✓
Status:  started-work → work-completed
Moved to completed/
```

T-3544, closed eleven minutes earlier, printed `Verification: 18/18 passed ✓`. The whole
difference between a verified close and an unverified one was **one absent line**, and
nothing prompts anyone to notice an absence.

**This is not a missing guard, and must not be fixed as one.** `update-task.sh:1152`
already refuses to re-check for the heading, and its stated reason is right:

> A guard that reimplements the code it guards cannot detect that code being fixed or
> re-broken (the G-072 class peer 577-CashWeb raised). The exit code is the entire contract.

The extractor's rc=2 leg (T-3232) already refuses when the block cannot be *read*. Empty is
different: a task legitimately may have no `## Verification` section — CLAUDE.md documents
that as backward-compatible — so refusing on empty would break every such task. The defect
is not that the gate permits zero. It is that it permits zero **without saying so**.

So the fix is to REPORT, not to guard. One line naming what happened, on the same surface
the pass count uses, costing nothing when the skip is legitimate and impossible to miss when
it is not.

**Why this is worth its own task rather than a one-line drive-by.** The aggravating factor
is that `work-completed → started-work` is not a valid transition, so a task closed on a
silent skip can never have the gate run on it — T-3545's nine commands had to be executed by
hand and recorded in its Updates. An unverified close is permanent.

## Acceptance Criteria

### Agent
- [x] `run_verification_commands` prints one line before returning on an empty block, naming
      that zero commands ran and why, instead of returning silently
- [x] The message distinguishes the two causes it can tell apart without re-deriving the
      heading: a task file with no `## Verification` text anywhere, versus a block that is
      present but yielded nothing
- [x] The heading-presence test used for that message is a REPORTING hint only — it must not
      gate, refuse, or change the exit code, so the T-3232 rc-contract and the G-072 reasoning
      at `update-task.sh:1152` stay exactly as they are
- [x] A bats suite pins: a task with real commands still prints the pass count and is
      unaffected; a task with no section prints the skip line and still closes; a task whose
      heading is malformed (the T-3545 shape, spliced into the Human template comment) prints
      the skip line and still closes
- [x] A negative control in the same suite proves the skip line can be absent — i.e. it does
      not fire on the normal verified path
- [x] `bin/fw vendor self --check` clean before close (OBS-250 — `agents/` is vendored)

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

# The suite: two controls (normal path unaffected, skip line does not misfire),
# all three zero-causes reported and mutually distinguishable, and two tests
# pinning that this REPORTS rather than gates.
timeout 900 bats tests/unit/t3546_p011_reports_the_zero.bats > /tmp/.t3546.out 2>&1 && ! grep -q "^not ok" /tmp/.t3546.out
test "$(grep -c '# skip' /tmp/.t3546.out)" -eq 0

# The sibling suites over the same function — this change sits inside
# run_verification_commands, so their greenness is the regression evidence.
timeout 600 bats tests/unit/t3232_verification_extractor_failure.bats > /tmp/.t3546-3232.out 2>&1 && ! grep -q "^not ok" /tmp/.t3546-3232.out
timeout 600 bats tests/unit/t2991_verification_preflight.bats > /tmp/.t3546-2991.out 2>&1 && ! grep -q "^not ok" /tmp/.t3546-2991.out
timeout 600 bats tests/unit/t3203_p011_gate_semantics.bats > /tmp/.t3546-3203.out 2>&1 && ! grep -q "^not ok" /tmp/.t3546-3203.out
timeout 600 bats tests/unit/t3219_verification_count_reconciliation.bats > /tmp/.t3546-3219.out 2>&1 && ! grep -q "^not ok" /tmp/.t3546-3219.out
timeout 600 bats tests/unit/t3220_verification_gate_exits.bats > /tmp/.t3546-3220.out 2>&1 && ! grep -q "^not ok" /tmp/.t3546-3220.out

# The rc-2 contract and the G-072 reasoning are untouched: the extractor status
# is still the only thing that refuses, and the new probe never exits.
# Asserted behaviourally in t3546 test 10 rather than by pattern-matching source
# text here: the earlier draft of this line was a `! grep -q` for a shape that
# could never appear, which passes on every possible tree and measures nothing.
grep -q 'extract_rc' agents/task-create/update-task.sh

# This task's own close must now PRINT its verification count rather than skip —
# the bug being fixed is one this very file could have reproduced.
grep -q '^## Verification' .tasks/active/T-3546-p-011-reports-nothing-when-it-runs-zero-.md

# Vendored path touched (agents/) — sync BEFORE close, per OBS-250.
bin/fw vendor self --check

## RCA

**Symptom:** T-3545 closed printing `Acceptance criteria: 6/6 checked ✓` and `Moved to
completed/` with no verification gate section at all. T-3544, eleven minutes earlier,
printed `Verification: 18/18 passed ✓`. The two closes were indistinguishable except by
the absence of a line, and the task that skipped the gate looked like the healthier one.

**Root cause:** `run_verification_commands` ended its empty-block case at
`[ -z "$verify_cmds" ] && return 0`. Zero commands is a supported outcome, but it was an
*unreported* one, so every cause of zero — no section, comments-only section, unreachable
heading — collapsed into the same output: none.

**Why structurally allowed:** the gate's designers had already thought hard about this
region and reached a correct conclusion that happened to leave the hole. `update-task.sh`
deliberately refuses to re-derive the heading, because a guard that reimplements the code
it guards cannot detect that code being fixed or re-broken. T-3232 hardened the *unreadable*
case to rc 2. Both decisions are right, and both are about REFUSING. Nobody asked what the
command should SAY when it correctly does nothing — and a silent success is invisible to
every reviewer, gate and audit we run, because there is no line to read.

The triggering splice is its own small irony: the Human-AC template comment contains the
sentence *"the reviewer command in `## Verification`"*, so a naive `index("## Verification")`
finds the template's prose before the real heading. The template that teaches good
verification is what swallowed the heading.

**Prevention:** the gate now prints a `=== Verification Gate (P-011) ===` block on every
close, including the zero, and names which of the three causes applies — with the
unreachable-heading case getting its own message and a `grep -n` to localise it, because
telling a reader "no section" when the file visibly contains the phrase sends them hunting
for something they can already see. Two tests pin that this stays REPORTING: a task with no
section and a task with T-3545's shape must both still close, since refusing either would
break every legitimately section-less task in the corpus — a worse defect than the silence.
A further test asserts the probe never exits and that the extractor's rc remains the only
thing that refuses, so the G-072 reasoning cannot be eroded by a later "strengthening".

**Not prevented:** a task closed on a silent skip before this shipped cannot be repaired
by it. `work-completed → started-work` is not a valid transition, so T-3545 can never have
the gate run on it; its nine commands were executed by hand and recorded in its Updates.
Whether the corpus holds other tasks closed this way is unmeasured, and measuring it is a
separate unit of work.

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

### 2026-09-28T22:57:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3546-p-011-reports-nothing-when-it-runs-zero-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f6509a22
- **Timestamp:** 2026-09-28T23:16:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-28T23:14:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
