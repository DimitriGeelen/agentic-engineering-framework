---
id: T-3003
name: "answer 832's corpus population question with a measurement, not a recalled
  count"
description: >
  answer 832's corpus population question with a measurement, not a recalled count

status: work-completed
workflow_type: build
owner: agent
horizon:
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
created: 2026-08-14T21:00:55Z
last_update: '2026-08-16T22:25:26Z'
date_finished: 2026-08-14T21:03:53Z
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
  - ts: '2026-08-16T22:25:26Z'
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

# T-3003: answer 832's corpus population question with a measurement, not a recalled count

## Context

In T-2993 I told 832 that `bin/fw corpus explain` "lists 8 maps" and that
`grep -io worktree` across them returns 0. 832 measured their side: 24
`*.workflow.yaml` sources, 24 rendered `.bpmn`, 25 in the gallery — and reported
that `bin/fw corpus explain` **ENOENTs at their pin** (routes to
`.agentic-framework/tools/corpus_explain.py`, missing). So my 8 and their 24 are not
the same population, and neither of us can tell which one the operator's GO meant.

Their framing is the right one and I accepted it: *"a corpus is exactly the kind of
subject with two plausible referents, and wrong-subject is the class we've been
trading all week."* I promised to return **a command, its output, and where the files
live — a population, not a number.**

**The specific trap, already recorded as L-596** (T-2957): I have previously published
a count that conflated the population with prose *quoting* it — 25 "co…" — which is the
same failure one layer down. A grep that matches documentation about maps, or fixtures,
or vendored copies under `.agentic-framework/` and `.claude/worktrees/`, will produce a
confident wrong number in exactly the way that started this exchange.

**Scope fence:** measure and report. Not authoring the worktree map (T-2993's GO, and
832 has declined to author under a "proceed as you see fit" directive — correctly, by
their own Pickup Message Handling rule). Not reconciling the two corpora into one.

## Acceptance Criteria

### Agent
- [x] `bin/fw corpus explain` is actually run here and its real behaviour recorded — exists / ENOENTs / lists something — rather than my recalled claim repeated
- [x] The population is stated as a **command plus its output plus file locations**, not as a bare count
- [x] Vendored (`.agentic-framework/`) and worktree (`.claude/worktrees/`) copies are excluded from any count, and the exclusion is shown rather than asserted — these are the duplicates that inflate every naive grep in this repo
- [x] The `worktree`-absence claim from T-2993 is re-run against the measured population and confirmed or withdrawn
- [x] If my original "8 maps" figure was wrong, it is stated as wrong with the correct figure, not quietly superseded
- [x] 832 receives the measurement in the form they asked for

## Findings

**The command exists here.** `bin/fw corpus explain` → rc=2 with a usage message
(`map-id or --search TERM required`), not ENOENT. So 832's pin genuinely differs from
this one; their report was accurate for their tree.

**Population — command, output, location.**

    $ bin/fw corpus explain --search e          # lists 8
    $ ls -d .context/designer/projects/*/       # lists 15
    root: tools/corpus_explain.py:40 → root / ".context/designer/projects"

    aef-audit-cron  aef-dispatch-loop  aef-existing-project-onboarding
    aef-greenfield-onboarding  aef-inception-flow  aef-session-lifecycle
    aef-task-lifecycle  aef-tier0-escalation
    draft-arc-lifecycle  draft-exception-handling  draft-inception-readiness
    draft-knowledge-leveling  draft-t2584-scratch  draft-task-creation
    draft-trigger-handling

**My "8 maps" was the PROMOTED count presented as the corpus.** 8 promoted (`aef-*`)
+ 7 drafts (`draft-*`) = 15. `corpus explain --search` enumerates only the promoted
set, so the number was true of what the command prints and false of what the corpus
holds — the L-596 shape again, one layer out.

**Exclusion shown, not asserted.** The same glob against vendored and worktree copies
returns 8 and 13 more project dirs (`.agentic-framework/…` and
`.claude/worktrees/*/…`). Any count taken without excluding them is inflated by ~2.8×.

**The `worktree`-absence claim from T-2993 is WITHDRAWN as stated, and re-stated
narrower:**

    grep -rlio worktree .context/designer/projects/          → 6 files
      .context/designer/projects/aef-*/                      → 0
      .context/designer/projects/draft-*/                    → 6

The 6 are versions, not maps: `draft-task-creation` v2/v3/v4/v5 and
`draft-inception-readiness` v1/v2 — **two distinct draft projects**. So "the promoted
corpus has no worktree model" is true and was the defensible claim; "the corpus has
zero worktree mentions" is what I actually told 832, and it is false.

**This changes T-2993's GO, and it is the reason the measurement was worth doing.**
The operator's GO was *"model the worktree lifecycle in the designer corpus first."* I
had reported a blank slate. There is not one: two drafts already touch worktrees, and
`draft-task-creation` has four iterations of it. The right first move is to read those
drafts and decide **promote-vs-author**, not to author a new map against a gap that
was measured wrong. Recorded here rather than acted on — authoring is not this task's
scope, and 832 has declined to author under a broad directive, correctly.

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

# Structural facts about this repo's corpus, not live counts of anyone's hub.
# The promoted set is 8 and the full population is 15 -- both are properties of
# files in this tree, so these stay true unless the corpus itself changes, which
# is exactly when they SHOULD go red.
test "$(ls -d .context/designer/projects/*/ 2>/dev/null | wc -l)" -ge 15
test "$(ls -d .context/designer/projects/aef-*/ 2>/dev/null | wc -l)" -eq 8
# The narrowed claim: promoted maps model no worktree; drafts do.
test "$(grep -rlio worktree .context/designer/projects/aef-*/ 2>/dev/null | wc -l)" -eq 0
test "$(grep -rlio worktree .context/designer/projects/draft-*/ 2>/dev/null | wc -l)" -gt 0

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

### 2026-08-14T21:00:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3003-answer-832s-corpus-population-question-w.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d75a6cc1
- **Timestamp:** 2026-08-14T21:03:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-14T21:03:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
