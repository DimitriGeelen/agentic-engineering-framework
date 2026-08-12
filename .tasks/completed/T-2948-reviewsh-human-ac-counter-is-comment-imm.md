---
id: T-2948
name: "review.sh Human-AC counter is comment-immune only by accident of indentation"
description: >
  832 rail 570 §3: lib/review.sh:151-183 matches '- [ ]' only at column 0, and default.md's
  commented example ACs are indented 7 spaces — so the rec-gate skips them for a reason
  unrelated to comments. De-indenting those examples (pure formatting, no reviewer
  stops it) would make every fresh build task count 2 phantom Human ACs, read as partial-complete
  0/2, and trip T-2421's rec-gate on work nobody started. Fix: make the counter comment-aware
  in the same pass (as G-067 and now G-020/T-2944 do) so its correctness stops resting
  on whitespace it does not know it depends on. Fourth site of the comment-boundary
  class 832 registered as their G-036.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/review.sh, tests/unit/t2948_review_human_ac_comment_aware.bats]
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
created: 2026-08-12T14:31:59Z
last_update: 2026-08-12T14:48:09Z
date_finished: 2026-08-12T14:48:09Z
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
  - ts: '2026-08-12T14:34:54Z'
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
cost_estimate_proposed:
  - ts: '2026-08-12T14:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2948: review.sh Human-AC counter is comment-immune only by accident of indentation

## Context

832 rail 570 §3. `lib/review.sh`'s Human-AC counter is comment-immune **by accident**: its
globs are `"- [ ]"*` (whitespace-intolerant) and `default.md`'s commented example ACs happen
to sit indented seven spaces. Nothing in the file records that the indentation is
load-bearing, so de-indenting those examples — pure formatting — would make the counter see
two phantom Human ACs on every task created from the template, read each fresh build task as
partial-complete 0/2, and trip T-2421's rec-gate on work nobody started.

Fourth site of the comment-boundary class (their G-036), and the only one getting the right
answer for the wrong reason. Siblings already fixed: G-067 (`:700`) and G-020 (`:754`,
T-2944) in `check-active-task.sh`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The counter skips HTML-comment spans explicitly, so its correctness no longer depends
      on indentation it does not know it relies on
- [x] The landmine is proven closed: a task whose commented example ACs are **de-indented to
      column 0** is still counted 0/0 and does not trip the rec-gate — measured against the
      real `fw task review`, not the predicate
- [x] Falsified: the same de-indent fixture is shown to trip the gate under the pre-fix
      counter, so the test can distinguish fixed from broken
- [x] No behaviour change on the live corpus: Human-AC counts across all active tasks are
      identical before and after, and the diff is reported (a silent change here would
      re-class tasks as partial-complete or clear them, both of which move the rec-gate)
- [x] Real ACs are still counted, including a commented span that ENDS mid-file (positive
      control — a fix that skips everything would satisfy the first three criteria)

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

# The fix is present and comment-aware.
bash -c 'out=$(grep -c "in_comment" lib/review.sh); [ "$out" -ge 4 ]'
# Regression suite: 6 legs against the real fw task review.
out=$(timeout 300 bats tests/unit/t2948_review_human_ac_comment_aware.bats 2>&1); echo "$out" | grep -q '^ok 6 ' && ! echo "$out" | grep -q '^not ok'
# Sibling suite from this session stays green (shared surface).
out=$(timeout 300 bats tests/unit/t2945_default_template_recommendation.bats 2>&1); echo "$out" | grep -q '^ok 6 ' && ! echo "$out" | grep -q '^not ok'
# The pre-existing red legs are filed, not absorbed into this task.
ls .tasks/active/T-2949-*.md >/dev/null 2>&1

## Evidence

### The fix

`lib/review.sh:151` — the Human-AC counter now tracks HTML-comment spans and `continue`s
through them, before the heading cases (so a commented `## `/`### ` heading can no longer
open or close a block either). Direction is stated in the comment: the span is being
DISCARDED as prose, so stripping is correct — unlike T-2921/P-011, where the same regex over
text about to be `eval`'d is a defect.

### No behaviour change on the live corpus (AC 4)

Counter run over all 335 active tasks, before and after:

    NOGATE 87 · PASS 243 · REFUSE 5      (before)
    NOGATE 87 · PASS 243 · REFUSE 5      (after)
    diff: IDENTICAL — 0 tasks change class or count

That is the intended result: this defuses a latent landmine, it does not move any current
state. A diff here would have meant tasks silently re-classing into or out of the rec-gate.

### The landmine, measured (AC 2/3)

`tests/unit/t2948_review_human_ac_comment_aware.bats`, 6 legs, driving the real
`bin/fw task review` in a sandbox `PROJECT_ROOT`, fixtures built from the shipped template:

    1  commented examples DE-INDENTED to column 0  -> emits      (the landmine, closed)
    2  same fixture under the PRE-FIX counter      -> counts >0  (falsification: fixture is live)
    3  template as shipped                         -> emits      (the accident still holds)
    4  a real unticked Human AC at column 0        -> REFUSED    (positive control: gate still fires)
    5  AC after a closed <!-- --> span             -> counted    (over-reach guard)
    6  fix present and names its direction

Falsified end-to-end: with the comment-tracking block deleted, leg 1 goes red and the other
five stay green; restored, 6/6. Leg 2 exists because leg 1 alone would pass for a fixture
that never had column-0 checkboxes in it.

Leg 5 was red on first run for a fixture bug of my own — I appended a SECOND
`## Acceptance Criteria` block at EOF, which the counter never reaches because it breaks at
the first `## ` after the first AC block. Fixed by injecting into the real Human section; the
reason is recorded in the test so the next reader does not repeat it.

### Regression check, and a finding it turned up

Nine existing review-related suites run. Seven legs are red — `lib_review.bats` (5) and
`review_link_blocking_gate.bats` (2) — and they are **pre-existing**: identical ok/fail
counts with this change stashed. Zero regression from T-2948.

Not walked past. Root cause proven: those fixtures build a partial-complete build task with
no `## Recommendation`, so T-2421's rec-gate refuses them. Same fixture plus a Recommendation
block returns rc=0 and prints `1/3`. The fixture helper still carries the comment *"Build
tasks do not gate on Recommendation, so the heading is conditional"* — true when T-2206 wrote
it, made false by T-2421 on 2026-06-16. **57 days red.** Filed as T-2949: third artefact of
one gate extension (code updated; template not → T-2945 / 832's T-455; fixtures not → this).

## RCA

**Symptom:** none observed — this is a latent defect, reported by a peer reading our code.

**Root cause:** the Human-AC counter's immunity to commented example ACs came from its globs
being anchored at column 0, not from any notion of comments. `default.md`'s examples are
indented seven spaces, so they were skipped for a reason unrelated to why they *should* be
skipped. Correctness rested on formatting that nothing recorded as load-bearing.

**Why structurally allowed:** the counter and the template are in different files with no
link, and the invariant ("these lines must not be counted") was satisfied by coincidence.
There is no test that de-indents them, because nobody knew indentation mattered.

**Blind for:** since the counter was written. Found by 832 as the *negative control* of a
census — they were explaining why their own count was correct, and the explanation was the
finding.

**Prevention:** the fix removes the dependency rather than documenting it, and leg 1 pins the
de-indent case that would have fired. Leg 5 pins the opposite over-reach. Distinct from the
fix: leg 2 proves the fixture can still go red, so a future refactor cannot make legs 1/3
pass by making the counter blind to everything.

**Credit:** 832, rail 570 §3 — offered as the reason their measurement was trustworthy, not
as a defect report.

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

### 2026-08-12T14:31:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2948-reviewsh-human-ac-counter-is-comment-imm.md
- **Context:** Initial task creation

### 2026-08-12T14:34:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-840ab593
- **Timestamp:** 2026-08-12T14:48:31Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 8
     - evidence: `ls .tasks/active/T-2949-*.md >/dev/null 2>&1`

### 2026-08-12T14:48:09Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
