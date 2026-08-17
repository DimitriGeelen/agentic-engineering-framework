---
id: T-3068
name: "The cost axis prices 'we never measured this' as 'cheapest', for 97% of the
  tasks it ranks"
description: >
  The cost axis prices 'we never measured this' as 'cheapest', for 97% of the tasks
  it ranks

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/termlink/bvp-estimator/estimator.py, lib/bvp.sh, tests/unit/test_bvp_estimator.py, tests/unit/test_t3068_unknown_cost.py]
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
created: 2026-08-17T12:30:27Z
last_update: 2026-08-17T12:40:52Z
date_finished: 2026-08-17T12:40:52Z
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
  - ts: '2026-08-17T12:36:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=270,acs=8)
    rubric_sha: e4a00f38e801
---

# T-3068: The cost axis prices 'we never measured this' as 'cheapest', for 97% of the tasks it ranks

## Context

The operator's standing instruction is to *"focus on HV/LC & HV/HC tasks and run
BVP estimator regularly"*. This task is about the instrument that instruction names,
and whether it can currently be steered by.

**The measurement.** `score_blast_radius` derives cost from the count of
`components:` entries — its own docstring says *"count `components:` entries →
0/1/3/5/7/9 scale"*. Measured across `.tasks/active/`:

| status | tasks | with `components:` |
|---|---:|---:|
| work-completed | 227 | 179 (79%) |
| captured | 96 | **1** (1%) |
| started-work | 46 | **3** (7%) |

`components:` is populated **at the `work-completed` transition** — `update-task.sh`
resolves it from git history and prints `Components: N resolved from git history`.
And `fw bvp` **excludes work-completed by default** (T-2223, deliberately: *"the
rank answers 'what should I work on next'"*).

So the ranked population is 142 tasks, of which **4 have components — 2.8%**.

Both design decisions are individually correct. Together they guarantee that the
dominant input to the cost axis is unavailable for essentially every task the axis
is used to rank. Cost is `0.6×blast_radius + 0.3×tier + 0.1×effort`: the missing
term carries **weight 0.6**, more than the other two combined.

**Why this is worse than a gap.** `blast_radius` returns `0` when it finds nothing,
and `0` is the *cheapest* value on that scale. So "the framework never recorded
what this touches" and "this touches nothing" are the same number, and the number
is the most attractive one available. Measured: 292 of 344 estimates carry
`blast_radius: 0` (85%); of the 144 tasks holding both components and an estimate,
**118 still score 0** — including T-2529, whose 3 components include `web/app.py`, a
73-edge node in the fabric.

The consequence is not noise, it is **inverted signal**: an HV/LC filter selects
preferentially for tasks whose blast radius was never measured. It does not present
as missing data — it presents as *attractiveness*. The framing is 832's and it is
the part of their report doing the most work for us; the population-exclusion
mechanism above is ours and is what makes the effect near-total rather than partial.

**Visible today.** `fw bvp --quadrant hv-lc --include-proposed` returns six rows
whose COST column reads `1.4`, `1.4`, `1.4`, `1.4`, `1.4`, `1.4`; `hv-hc` returns
rows at `3.6` tied at BVP 108. The quadrant split is not partitioning on cost — it
is mostly partitioning on `workflow_type`, because the inception exception (T-2189)
is one of the few paths that puts a non-zero number on the axis.

**Scope fence.** This task makes the instrument honest: unknown must stop reading as
cheapest, and the operator must be able to see how much of the ranking rests on
absent data. It does **not** make the axis real — deriving blast radius for open
tasks (from the fabric, from a task's own commits, or by populating `components:`
before close) is the follow-up, and is a bigger change with its own design
questions. Doing the honest half first is deliberate: right now the tool cannot
tell us how badly it needs the second half, and after this it can.

## Acceptance Criteria

### Agent
- [x] `blast_radius` distinguishes *unmeasured* from *zero*. A task with no
      resolvable component information yields an explicit unknown, not `0`.
- [x] The cost composite propagates unknown rather than substituting a number.
      A cost built on an unknown blast radius is itself unknown — it must not be
      silently completed from the two lighter terms.
- [x] Quadrant medians are computed over **known** costs only. An unknown-cost task
      must not shift the median that decides everyone else's quadrant, which is the
      mechanism by which 97% of the corpus currently defines "low cost".
      *(Pre-existing behaviour in `cmd_rank`, not a change — now commented, and the
      NOTE line reports the denominator so it is observable rather than assumed.)*
- [x] `fw bvp` and `fw bvp --quadrant` state how many tasks were excluded or
      unranked for want of a cost, in the output itself. Per CLAUDE.md §no silent
      caps: a bounded ranking that does not say what it dropped reads as complete
      coverage.
- [x] Existing frontmatter stays readable. 344 estimates carrying `blast_radius: 0`
      already exist and must not be retroactively reinterpreted as unknown — a
      recorded 0 was a real (if wrong) estimate, and rewriting history to mean
      something else would destroy the evidence this task rests on.
- [x] A regression test pins the inversion directly: a task with no components must
      not sort as cheaper than one with a known small blast radius. Mutation result
      recorded in Updates (L-616).
- [x] The rationale renderer names the reason instead of `(no-signal)`. Not
      cosmetic once blast_radius can be unknown: the parenthetical is the only place
      the operator learns *why* a cost is missing, so `(no-signal)` would have made
      the honest answer unactionable.

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

python3 -m pytest tests/unit/test_t3068_unknown_cost.py -q > /tmp/.t3068 2>&1 && grep -q "7 passed" /tmp/.t3068
# The literal that started this: no-components must not route to a number.
! grep -q 'return 0, \["→0 (no-components)"\]' agents/termlink/bvp-estimator/estimator.py
# The ranking must disclose its own denominator (§no silent caps).
timeout 200 bin/fw bvp --include-proposed > /tmp/.t3068rank 2>&1 && grep -q "have no known cost" /tmp/.t3068rank
grep -q "Quadrant thresholds are computed over" /tmp/.t3068rank

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line under `set -eo
# pipefail`. When grep matches it exits and closes stdin while cmd is still
# writing, cmd takes SIGPIPE, the pipeline exits 141 — verification "fails" with
# the pattern present. Captured 4× (T-1716, T-1838, T-1862, T-1863).
#
# THE EXCEPTION — capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Valid ONLY while "$out" fits the 65536-byte pipe buffer, and it is on you to
# know that it does. Above that the form inverts and becomes the very failure
# L-387 describes: echo blocks on the full pipe, grep -q exits, echo takes
# SIGPIPE, rc=141 (T-2743 — measured on a 146,366-byte Watchtower page, 3/3 runs,
# deterministic not racy; rendered routes run 50-200KB, so anything that curls a
# page is over the line). It also discards cmd's exit code, so a 404 yields an
# empty capture that grep merely fails to match rather than a failed line.
# If you do use it: single pipe only, no intermediate tail/awk/sed stage between
# capture and grep (T-2090) — the middle stage is what `grep -q` slams its stdin
# on, and grep scans the whole captured string anyway, so the `tail -3` was
# cosmetic. `echo "$out" | grep -q PAT`, nothing between.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. A line has returned 0 by hand and 141 under
# P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

**Symptom:** `fw bvp --quadrant hv-lc` returned six rows whose COST column all read
`1.4`, and `hv-hc` returned rows tied at BVP `108`. The quadrant split looked like a
cost partition and was mostly a `workflow_type` partition.

**Root cause:** `score_blast_radius` returned `0` when it found no `components:`,
and `0` is the cheapest value on the term carrying weight `0.6` — more than the
other two cost terms combined. "Never measured" and "touches nothing" were the same
number, and that number was the most attractive one available.

**Why structurally allowed:** three independently-correct decisions composing into a
guarantee.

1. `components:` is resolved at the `work-completed` transition, from git history.
   Correct: that is when the answer is knowable.
2. `fw bvp` excludes `work-completed` by default (T-2223). Correct: the rank answers
   "what should I work on next".
3. `score_blast_radius` counts `components:`. Correct in isolation.

Together: the axis's dominant input is available for exactly the population the
ranking excludes, and absent for exactly the population it ranks. Measured 4 of 142.
Nobody had to make a mistake for this to happen, which is why it survived — each
piece is defensible on its own terms and the interaction is not visible from any
one of them.

The fourth reason it survived is the direction of the error. A cost that read too
*high* would have been noticed the first time a cheap task was buried. Reading too
*low* means the mistake surfaces as a recommendation — the tool confidently
promoting the tasks it knows least about — and a recommendation is not something you
audit, it is something you follow. T-2189 saw this exact shape one population
earlier and repaired inceptions only; its own docstring describes the mechanism, and
the same sentence was true of the whole non-inception corpus. Nothing re-asked.

**Prevention:** `tests/unit/test_t3068_unknown_cost.py`, 7 tests. The load-bearing
one asserts the *ordering property* rather than the sentinel value — an unmeasured
task must not sort ahead of a measured cheap one — so a later change that
reintroduces cheapness through a default, a coalesce, or a clamp still fails without
having to literally write `0`. Mutation-checked: reverting the return to `0` killed
4 tests including the ordering property; reverting the rationale renderer killed
exactly the rationale test. Verification also greps for the original literal, and
asserts the ranking prints its own denominator.

What this does **not** prevent, stated plainly because the fix is easy to overread:
the axis is now honest, not correct. 82% of the ranked corpus reports no cost at all,
and the 26 tasks that do report one are almost entirely inceptions scored through the
T-2189 `target_blast_radius` path — so "low cost" is currently a judgement relative
to a population of inceptions. The ranking is no longer misleading; it is also not
yet useful. Making it useful means deriving blast radius for open tasks, which is
the follow-up named in the Scope Fence and is deliberately not attempted here. The
honest half had to land first: before this change the tool could not report how much
of its own output rested on absent data, and it now does — the 82% figure did not
exist as an observable until the fix produced it.

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

### 2026-08-17T12:30:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3068-the-cost-axis-prices-we-never-measured-t.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5b918c75
- **Timestamp:** 2026-08-17T12:41:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **destructive-action** (high) — Destructive operation in verification or AC
     - matched: `destroy`

### 2026-08-17T12:40:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
