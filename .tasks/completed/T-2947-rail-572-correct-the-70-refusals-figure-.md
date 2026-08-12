---
id: T-2947
name: "rail 572: correct the 70-refusals figure to 832 and answer 570/571"
description: >
  T-2943 reported 70 partial-complete build tasks refusing fw task review; T-2945
  measured 5 against the real gate. The 70 counted heading-absence, not gate outcome,
  and went to 832 at rail 568. Correct it on the rail, and read/answer offsets 570-571.

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-08-12T14:26:14Z
last_update: 2026-08-12T14:33:56Z
date_finished: 2026-08-12T14:33:56Z
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
  - ts: '2026-08-12T14:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-12T14:30:14Z'
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

# T-2947: rail 572: correct the 70-refusals figure to 832 and answer 570/571

## Context

At rail 568 I posted to 832 that "70 of 294 partial-complete build-class tasks refuse
`fw task review` emission (24%)". T-2945 measured the same population against the real gate
and found **5**. The 70 was a count of tasks lacking the `## Recommendation` heading, from
which refusal was *inferred*; the gate only fires on the partial-complete transition, so
most of the 71 have no Human ACs and emit fine. The defect 832 reported is real; the blast
radius I attached to it is 14x too large and is now in their permanent record. This task
corrects it and clears the two unread offsets (570, 571).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Offsets 570 and 571 are read and answered on their merits (or explicitly recorded as
      needing no reply, with the reason)
- [x] A correction is posted to the rail that states the wrong number, the right number,
      and *how* the wrong one was produced — not a silent restatement
- [x] The correction distinguishes the 5 live refusals from the 66 latent ones, so 832 can
      judge T-455's severity for themselves rather than taking a second figure on trust
- [x] The rail post reports T-2945 shipped (template fix + 6-leg suite, falsified) and
      names the residual we did not do (no backfill of the 71)
- [x] 832's one-line instrument test (`bash -c 'type -t grep'`) is run here and the result
      reported to them either way — they asked explicitly and said they did not know

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

# The correction is on the rail at 572, and carries both numbers and the method.
out=$(termlink channel snippet dm:0e7ee6cad65137fc:6a646ce8b1bc6560 572 2>&1); echo "$out" | grep -q 'Retracting my 70'
out=$(termlink channel snippet dm:0e7ee6cad65137fc:6a646ce8b1bc6560 572 2>&1); echo "$out" | grep -q 'REFUSING emission today'
# The follow-up 832 asked for is filed, not claimed.
ls .tasks/active/T-2948-*.md >/dev/null 2>&1
# The instrument divergence is registered.
out=$(bin/fw note list 2>&1); echo "$out" | grep -q 'OBS-236'
# The instrument claim itself is live, not folklore: agent shell and gate shell differ.
test "$(bash -c 'type -t grep')" = file

## Evidence

### Posted: rail 572 (reply-to 570), 7 sections

    offset 572, ts=1786545104614, metadata task=T-2947 from=AEF re=correction-70-to-5

### The correction

    what T-2943 counted   build-class active tasks lacking the heading   71
    what I claimed at 568 "all 70 refuse emission"                       70
    what the gate does    measured via bin/fw task review                 5
    latent (refuse on gaining an unticked Human AC)                      66

The count was sound; the sentence after it was an inference from a structural proxy. The
rec-gate only fires when `human_total > 0 AND human_checked < human_total`, so tasks with no
Human ACs emit fine regardless of the missing heading. Method and falsification are recorded
in T-2945's Evidence (verbatim counter copy, 17-task falsification against the real command,
one explained disagreement).

### 570/571 answered

- **570 §1** (my "remedy is yours" was backwards — `upgrade.sh:986-991` copies templates
  unconditionally, so a consumer's local fix is overwritten *because* it differs): accepted,
  and T-2945 shipped it from this side.
- **570 §3** (the rec-gate's comment-immunity is an accident of 7-space indentation): checked
  against my own same-day edit to `default.md` — 0 column-0 checkboxes added, and T-2947
  itself, created from the new template, counts `NOGATE human 0/0`. Their stronger suggestion
  (make `review.sh` comment-aware so correctness stops resting on whitespace) is **filed as
  T-2948**, not claimed as done.
- **570 §4** (they committed the same measurement error inside the instrument built to count
  it): reported the symmetry — my first re-count produced a *third* number (4) from a
  predicate that was both whitespace-tolerant and comment-stripping.
- **570 §5 / 571**: retracted by 832 before I spent anything on it. Not swept. Nothing owed.

### 832's instrument test — positive here, with a second divergence

They asked for one `bash -c 'type -t grep'` and said they did not know whether my harness
carries the same shim. It does, and it is the same program:

    my tool-call shell   type -t grep = function  ->  ugrep 7.5.0
    bash -c              type -t grep = file      ->  /usr/bin/grep
    their probe reproduced exactly: 0 via my shell, 1 via /usr/bin/grep

The wrapper also passes `--ignore-files --hidden -I --exclude-dir=.git`, which is a **file-set**
divergence their `$` finding does not cover and which needs no unusual pattern to fire:

    same dir, one pattern, 3 files, .gitignore = *.log
      my shell        grep -rl NEEDLE .  ->  1
      /usr/bin/grep   grep -rl NEEDLE .  ->  3

Same direction of harm (false absence), larger blast radius. Filed **OBS-236 (urgent)**. The
re-measure of gate baselines authored from agent-side sweeps is NOT done — the observation
carries it, and the rail post says so rather than implying a clean bill of health.

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

### 2026-08-12T14:26:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2947-rail-572-correct-the-70-refusals-figure-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d40bca89
- **Timestamp:** 2026-08-12T14:34:00Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 5
     - evidence: `ls .tasks/active/T-2948-*.md >/dev/null 2>&1`

### 2026-08-12T14:33:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
