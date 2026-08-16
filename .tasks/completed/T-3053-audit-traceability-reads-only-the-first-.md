---
id: T-3053
name: "audit traceability reads only the first T-ref in a commit subject — multi-ref
  commits flagged orphan"
description: >
  From T-3047 triage M-24 (ring20-management, 2026-06-11). agents/audit/audit.sh:2476
  is task_ref=$(... grep -oE "T-[0-9]+" | head -1) followed by a single-ref existence
  test at :2478. The revert-chain (T-2058) and root-commit (T-2851) escapes are orthogonal
  — neither looks at a second ref. A commit like "T-A/T-B-side:" is reported orphaned
  whenever the first ref does not resolve.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [upstream-pickup, T-3047-triage]
components: [C-004, tests/unit/t3053_multiref_traceability.bats]
related_tasks: [T-3047]
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
created: 2026-08-16T22:31:41Z
last_update: 2026-08-16T23:33:07Z
date_finished: 2026-08-16T23:33:07Z
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
  - ts: '2026-08-16T22:45:05Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-16T22:45:08Z'
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

# T-3053: audit traceability reads only the first T-ref in a commit subject — multi-ref commits flagged orphan

## Context

Filed from T-3047 triage M-24 (ring20-management, 2026-06-11 — unread for two months).

`agents/audit/audit.sh:2476` extracts the task reference from a commit subject with
`grep -oE "T-[0-9]+" | head -1`, then tests only that one id for existence at `:2478`.
A commit referencing more than one task — `T-A/T-B-side:`, `T-A + T-B:` — is therefore
reported orphaned whenever the *first* id fails to resolve, even though a later one
resolves fine.

Two escapes were added to this check since the report and neither touches the failure
mode: revert-chain suppression (T-2058, `:2481-2488`) and root-commit exemption
(T-2851, `:2496-2498`). Both operate on the single already-chosen ref. The triage also
found the same `head -1` shape surviving at a second site in the file.

Direction of the error matters for prioritisation: this is a **false FAIL**, not a
false green. It generates audit noise rather than hiding defects, which is why it has
been survivable for two months — but audit noise is what trains operators to stop
reading audit output, so it is not free.

## Acceptance Criteria

### Agent
- [x] **A1** The traceability check resolves a commit as traceable when **any**
  `T-NNNN` in its subject names an existing task, not only the first.
  → `agents/audit/audit.sh:2488` collects every ref; `:2504` short-circuits on the
  first that resolves. Pinned by test 1.
- [x] **A2** A commit whose refs *all* fail to resolve is still reported orphaned —
  the fix must not turn the check into a no-op. This is the direction most likely to
  be broken silently by an over-broad fix.
  → Tests 4 and 6. Test 5 pins the opposite over-reach (a resolving first ref must
  not start reporting its dead sibling — that would be the same noise class inverted).
- [x] **A3** The second `head -1` site found in the same file is either fixed the same
  way or shown by citation to be a different question that legitimately wants one ref.
  → Fixed, but with the **opposite** semantics, and that turned out to be the
  interesting part. `:2807` (practice `Origin:` lines) asks whether every citation is
  valid, not whether any is — so `head -1` there was a false **green** (a stale second
  origin passed silently under a PASS line) where at `:2488` it was a false **fail**.
  One `head -1` shape, two directions. Tests 10-12.
- [x] **A4** A regression test covers all three shapes against a synthetic repo:
  first-ref-resolves, later-ref-resolves-first-does-not, and none-resolve. The middle
  case must be observed red against the current `head -1` form.
  → `tests/unit/t3053_multiref_traceability.bats`, 12 tests. Tests 2 and 11 restore
  the `head -1` form and assert the suite goes red at each site. Test 3 is the
  harness guard described in the RCA.
- [x] **A5** The existing T-2058 revert-chain and T-2851 root-commit escapes still fire
  — they operate on a single chosen ref, so a multi-ref rewrite can break them without
  any test noticing.
  → Tests 7 and 9. Test 8 pins the widening this rewrite made available for the first
  time: T-2058 now suppresses only when *every* unresolved ref has a revert chain, so
  one reverted task cannot hide a genuinely orphaned sibling. For a single-ref commit
  the new test is bit-identical to the old one.

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

# 1. The regression suite, including both mutations. ~4 min (each test runs a
#    real audit section against a synthetic repo).
out=$(bats tests/unit/t3053_multiref_traceability.bats 2>&1); echo "$out" | grep -q '^ok 12 ' && ! echo "$out" | grep -q '^not ok'

# 2. Both call sites carry the multi-ref form. Mutation-checked: reverting either
#    one to `head -1` drops the count to 1 and this line goes red.
[ "$(grep -cF '!seen[$0]++' agents/audit/audit.sh)" -eq 2 ]

# 3. No regression on the real corpus — 8300+ commits, 12 of the last 200 carry
#    multi-ref subjects. ~80s.
bash agents/audit/audit.sh --section traceability > /tmp/.t3053-trace.out 2>&1 || true; grep -q "All commit task refs resolve to actual tasks" /tmp/.t3053-trace.out

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

**Symptom:** a commit whose subject named more than one task — `T-A/T-B-side: …`,
`T-A: …; T-B recommendation` — was reported `references non-existent task T-A`
whenever the *leading* ref failed to resolve, even though a later ref named a real
task. Reported by a consumer project on 2026-06-11 (T-3047 triage M-24) and unread
for two months.

**Root cause:** `agents/audit/audit.sh:2476` chose one ref with
`grep -oE "T-[0-9]+" | head -1` and tested only that one for existence. Twelve of the
last two hundred commits in this repo carry multi-ref subjects, so the shape is
ordinary, not exotic.

**Why structurally allowed:** three things, and the third is the one worth keeping.

1. *The two halves of the same measurement disagreed and nothing compared them.*
   `:2432` computes the traceability percentage with `grep -cE "T-[0-9]+"` — a
   commit counts as referencing a task if **any** ref is present. `:2476` then
   narrowed that to the first ref when deciding whether the reference resolves. The
   same commit could be counted traceable by one line and orphaned by the next, four
   lines apart, and no test held the two to a shared definition.

2. *The error direction made it survivable, which is exactly why it lasted.* This is
   a false FAIL: it produces audit noise rather than hiding defects. Noise is
   tolerable one line at a time, so nobody paid the cost of fixing it — but audit
   noise is how operators learn to stop reading audit output, which converts a false
   FAIL into a false green at the human layer. Two months of not-reading is the
   actual damage.

3. *The same `head -1` shape at the sibling site was a false GREEN, and the report
   did not mention it.* `:2749` validated practice `Origin:` lines the same way. But
   an `Origin: T-A, T-B` line asserts that **both** tasks exist, so reading only the
   first let a stale second citation pass — underneath a `PASS All practice origins
   resolve to actual tasks`. Identical code, opposite question, opposite failure
   direction, opposite fix. Finding the reported instance would not have found this
   one; only grepping the shape did.

**Prevention:**
- `tests/unit/t3053_multiref_traceability.bats` — 12 tests over a synthetic repo,
  covering both sites in both directions, with the `head -1` form restored as a
  mutation at each site (tests 2 and 11). Each escape has its own test, plus test 8
  for the widening the rewrite newly made possible.
- The commit-site fix is written to agree with `:2432` by construction (any-ref), so
  the two measures can no longer diverge.

**A false green found in this task's own test harness — recorded because it is the
more transferable finding.** The first draft installed the mutant audit.sh as a bare
file in a temp dir. `audit.sh` derives `FRAMEWORK_ROOT` from `dirname $0`, so that
mutant silently failed to source `lib/paths.sh`, ran with an empty `TASKS_DIR`, and
reported **every** ref as unresolvable. The mutation test passed — for a reason that
had nothing to do with the mutation. A broken mutant is indistinguishable from a
detected mutation, because both are red. Caught only because the sibling mutation at
the practices site expected *silence* and got a warning instead; had both mutations
expected a warning, the harness would have shipped green and worthless.

The fix is `_mutant()` building a shadow `FRAMEWORK_ROOT` of symlinks with the
mutated `audit.sh` as its only real file, plus **test 3** — a harness-sanity test
asserting the mutant still resolves a first-ref-good commit. That test is the guard
on the guard: it fails if the mutant is broken rather than mutated. Generalisation
for the next mutation test: *a mutant must be shown to still work, not only to still
fail.* Filed as an observation for the reviewer-rule backlog.

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

### 2026-08-16T22:31:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3053-audit-traceability-reads-only-the-first-.md
- **Context:** Initial task creation

### 2026-08-16T22:55:31Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-64a9e84d
- **Timestamp:** 2026-08-16T23:34:29Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-16T23:33:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
