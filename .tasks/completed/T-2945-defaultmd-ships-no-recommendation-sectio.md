---
id: T-2945
name: "default.md ships no Recommendation section — 70 partial-complete build tasks
  refuse fw task review emission"
description: >
  lib/review.sh:205-211 (T-2421) BLOCKS emission for partial-complete build-class
  tasks with an empty ## Recommendation, but .tasks/templates/default.md contains
  zero such sections while inception.md has one. 70 of 294 partial-complete build-class
  active tasks lack it entirely and would refuse fw task review — the command CLAUDE.md
  mandates for human handoff. Remedy is to copy the section that already works from
  the sibling template. Reported by 832 as their T-455; confirmed live here by T-2943.

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
created: 2026-08-12T12:36:25Z
last_update: 2026-08-12T13:46:01Z
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
  - ts: '2026-08-12T12:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-12T12:45:12Z'
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
---

# T-2945: default.md ships no Recommendation section — 70 partial-complete build tasks refuse fw task review emission

## Context

832 reported (their T-455) that `default.md` ships zero `## Recommendation` sections while
`inception.md` ships one, and that `lib/review.sh:205-211` (T-2421) BLOCKS `fw task review`
emission for partial-complete build-class tasks whose block is empty. T-2943 confirmed the
template asymmetry here. This task closes it.

The gate fails identically whether the section is **absent** or **present-but-commented** —
so this is not a gate-behaviour fix. It is an author-prompting fix: the anchor heading and
its guidance now exist at the moment the task is written, instead of appearing only when the
gate refuses the handoff days later.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `default.md` carries a `## Recommendation` section modelled on the one that already
      works in `inception.md` — copied, not reinvented, since the sibling template's shape
      is what `audit_inception_recommendation` already parses
- [x] A task created from the template and taken to partial-complete emits from
      `fw task review` **once the block is filled in** — measured against the real gate,
      not the parser (bats leg 2 drives `bin/fw task review` in a sandbox PROJECT_ROOT)
- [x] The template's new section does not itself satisfy the gate: a task that never fills
      it in must still block, or the fix trades a refusal for a false green (bats leg 1)
- [x] The existing partial-complete build-class tasks are counted **against the real gate**
      after the change and the number reported — including the correction that the "70"
      in this task's own title is wrong (it counted heading-absence, not gate outcome).
      The template fix does not retroactively repair any of them, and saying so is part
      of the deliverable
- [x] Regression test pins both directions (template-only → blocked, filled → emits) and
      is falsified by reverting the fix

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

# The fix is present in the framework template and in the vendored consumer copy.
test "$(grep -c '^## Recommendation$' .tasks/templates/default.md)" -eq 1
test "$(grep -c '^## Recommendation$' .agentic-framework/.tasks/templates/default.md)" -eq 1
# The shipped block must NOT itself satisfy the gate (false-green guard).
bash -c 'source lib/task-audit.sh; ! audit_inception_recommendation .tasks/templates/default.md'
bash -c 'source lib/task-audit.sh; ! audit_inception_recommendation .agentic-framework/.tasks/templates/default.md'
# Regression suite: 6 legs against the real `fw task review`.
out=$(timeout 300 bats tests/unit/t2945_default_template_recommendation.bats 2>&1); echo "$out" | grep -q '^ok 6 ' && ! echo "$out" | grep -q '^not ok'

## Evidence

### The fix

`.tasks/templates/default.md` gains `## Recommendation` between `## Evolution` and
`## Decisions` — the same slot inception.md uses. The block is an HTML comment carrying the
`**Recommendation:** / **Rationale:** / **Evidence:**` shape the shared parser accepts,
plus the partial-complete trigger condition and the DEFER-is-not-a-hedge rule.

    default.md    ## Recommendation sections   0  ->  1
    inception.md  ## Recommendation sections   1      (unchanged)

Self-vendored, so consumers get it: `.agentic-framework/.tasks/templates/default.md` carries
the section and still fails the gate when unfilled (checked explicitly — the T-2942 lesson
about framework-vs-consumer asymmetry applied without being asked for).

### The 70 was wrong — corrected here

T-2943 reported "294 partial-complete build-class tasks, 70 with no `## Recommendation`,
every one of those 70 refuses emission", and I posted that figure to 832 at rail 568. The
first two numbers are a structural count; the third is an **inference from it**, and it does
not hold. The gate only fires when `human_total > 0 AND human_checked < human_total`. Most
tasks lacking the heading have no Human ACs at all, so no gate class is assigned and they
emit fine.

Measured against the real gate (`bin/fw task review`, all 335 active tasks):

    build-class active tasks                        304
    lacking the ## Recommendation heading            71   <- what T-2943 counted
    actually REFUSING emission today                  5   <- what the gate does
      T-1719, T-2172, T-2269, T-2353  (pc-build)
      T-449                           (pc-refactor)

Method: `review.sh`'s Human-AC counter copied verbatim (it does NOT strip HTML comments and
matches `- [ ]` only at column 0 — my first reimplementation did both wrong and produced yet
a third number), then falsified against the real `bin/fw task review` on 17 tasks: the 5
predicted refusals plus 12 sampled. 16/17 agreed. The one disagreement (T-2767, predicted
NOGATE, really BLOCKED) is the **placeholder** gate firing first on `[First criterion]` —
a different gate, not a flaw in the copy.

So 832's defect is real and the template fix is right, but the blast radius I reported was
14x too large. Correction owed on the rail.

### Residual — stated, not fixed

The 71 tasks lacking the heading are not repaired by a template change; templates are read
at creation. 5 refuse today; the other 66 refuse the moment they gain an unticked Human AC.
No backfill is attempted here — that is a separate decision about mutating 71 task files.

### Test

`tests/unit/t2945_default_template_recommendation.bats` — 6 legs, all driving the real
`bin/fw task review` against a sandbox `PROJECT_ROOT`, with every fixture built **from the
shipped template** so the tests stay coupled to it:

    1  unfilled template block  -> REFUSED      (false-green guard)
    2  filled block             -> EMITS        (the fix)
    3  all Human ACs ticked     -> EMITS        (positive control: gate is scoped)
    4  exactly one heading in default.md
    5  both templates' unfilled blocks rejected by the same parser (shape parity)
    6  FW_ALLOW_EMPTY_RECOMMENDATION=1 still emits (T-1890 bypass parity)

Falsified: with the section stripped from the template, legs 2 and 4 go red and the rest
stay green; restored, 6/6.

## RCA

**Symptom:** partial-complete build-class tasks refuse `fw task review` — the command
CLAUDE.md mandates for human handoff — because their `## Recommendation` block is empty.
The build template never shipped the section.

**Root cause:** T-2421 extended a gate written for inceptions to build-class tasks, and
updated `lib/review.sh` but not `.tasks/templates/default.md`. The gate and the template
that has to satisfy it live in different files with no link between them; inception.md
satisfied it only because the gate was originally written for inceptions.

**Why structurally allowed:** nothing asserts that every template reaching a gate carries
the section that gate demands. The parity is between `lib/review.sh` and *two* templates,
and only one of them was ever exercised against it. Same shape as this session's other
findings: the artefact that certifies is not the artefact that runs.

**Blind for:** T-2421 landed 2026-06; found by a peer (832 T-455), not by us.

**Prevention:** bats leg 5 asserts both templates are judged by the same parser and agree —
so a third template, or a template that drifts out of the accepted shape, goes red. Legs 1
and 3 pin the gate's scope so a future widening of it cannot silently start refusing
fully-ticked tasks.

**Credit:** reported by 832 as T-453/T-455 in the same rail message; confirmed by T-2943.

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

## Decisions

### 2026-08-12 — do not backfill the 71 tasks lacking the heading
- **Chose:** ship the template fix only; report the 5 live refusals and the 66 latent ones.
- **Why:** templates are read at creation, so the fix is forward-looking by construction.
  Backfilling means mutating 71 active task files to insert a section whose content only
  their author can write — an empty inserted block satisfies nothing and would convert a
  loud refusal into 71 blank Recommendation cards, which is the exact failure T-2417 filed.
- **Rejected:** auto-inserting the heading at `fw task update` time — same objection, and it
  would make the gate unfalsifiable from the task-file side.

### 2026-08-12 — correct the 70 rather than restate it
- **Chose:** measure against the real gate, report 5, and correct the figure to 832.
- **Why:** I posted "70 of 294 (24%)" to a peer at rail 568 on the strength of a structural
  count. It was an inference presented as a measurement — the same substitution this session
  has now found three times in other people's code. Restating it in this task's Evidence
  would have propagated it into the permanent record.
- **Rejected:** quietly reporting the right number without flagging the correction.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-12T12:36:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2945-defaultmd-ships-no-recommendation-sectio.md
- **Context:** Initial task creation

### 2026-08-12T13:46:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
