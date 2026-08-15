---
id: T-3023
name: "recall miss regression test is fixture-only — nothing pins the real retriever's zero-score behaviour"
description: >
  recall miss regression test is fixture-only — nothing pins the real retriever's zero-score behaviour

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/integration/test_recall_miss_live.py]
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
created: 2026-08-15T19:51:51Z
last_update: 2026-08-15T19:57:06Z
date_finished: 2026-08-15T19:57:06Z
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

# T-3023: recall miss regression test is fixture-only — nothing pins the real retriever's zero-score behaviour

## Context

Surfaced by `fw reviewer T-3021` — finding `mock-only-integration`, and it is correct.

T-3021 fixed the miss classifier and pinned it with six regression tests. Every one of
them feeds the classifier a hand-built result list. The three verification lines are:
the unit suite (fixtures), a static `grep` for the predicate, and `recall_usage_verdict`
(reads a JSONL). **Nothing in the gate touches the real retriever.**

So the tests pin *my model* of the retriever — "gibberish produces rows at score 0" —
rather than the retriever itself. If someone adds a distance threshold to
`_semantic_search`, or changes the `max(0, 1.0 - distance)` clamp, the premise the whole
classifier rests on breaks and all 32 tests stay green.

That is the same lenient-reader class T-3021's own RCA describes, one level down: T-3019
shipped a signal that worked against the corpus it was tested on and stopped being true
when the corpus changed. A fixture cannot notice the retriever changing underneath it.

The live behaviour *was* verified by hand during T-3021 and recorded in its Evidence
table — but a manual check that nothing re-runs is folklore, not a control.

## Acceptance Criteria

### Agent
- [x] An integration test runs a real gibberish query through the live `E.search` path and asserts the recorded outcome is `miss` — no hand-built result lists
- [x] The same test asserts a real known-good query records `hit`, so it fails if the retriever stops returning anything at all (not just if it stops returning zeros)
- [x] The test is fail-closed at the gate: if the index or embed path is unavailable the verification line **fails** rather than passing on a skip
- [x] Skip reason is explicit when it does skip, so "did not run" is never silently indistinguishable from "passed"
- [x] Mutation check: adding a distance cutoff to `_semantic_search` (so gibberish returns zero rows) leaves the T-3021 fixture tests green and turns this integration test red — proving it reads the retriever, not the model
- [x] `## Verification` includes the integration test with an assertion that it actually executed

**Mutation evidence.** Added `if similarity <= 0: continue` to `_semantic_search`, so
gibberish returns zero rows instead of zero-scored rows:

| suite | result |
|-------|--------|
| `tests/unit/test_recall_telemetry.py` (T-3021 fixtures) | **32 passed** — completely blind |
| `tests/integration/test_recall_miss_live.py` | **1 failed** — `assert 0 > 0` |

The fixture suite cannot see a change in the component its premise depends on. That is
the whole finding, and it is now demonstrated rather than argued.

Note which assertion fired: the **`n_hits > 0` premise guard**, not the outcome
assertion. Under the mutation the outcome is still `miss` (zero rows classify as miss
correctly), so a test asserting only `outcome == miss` would have passed and reported
success while the justification for the rule had silently changed. Both assertions are
load-bearing, in different directions.

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

# Fail-closed: asserts the live test EXECUTED (2 passed), not merely that it
# did not fail. A skip — index down, embed host unreachable — must not read as
# a pass, since "could not check" reporting as "checked and fine" is the exact
# bug class this task exists to close.
out=$(python3 -m pytest tests/integration/test_recall_miss_live.py -q 2>&1); echo "$out" | grep -q "2 passed" && ! echo "$out" | grep -qE "failed|skipped|error"
out=$(python3 -m pytest tests/unit/test_recall_telemetry.py -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed

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

**Symptom:** T-3021 shipped six regression tests for the miss classifier, all of which
feed it hand-built result lists. Its three verification lines are a fixture suite, a
static `grep`, and a JSONL reader. Nothing re-runs the live behaviour the fix depends on.

**Root cause:** the tests pin the *rule* (`top_score == 0` → miss) but not its *premise*
(the retriever returns rows at score 0 for a non-matching query). The premise is a fact
about `_semantic_search`, and a fixture built from my belief about that function cannot
detect the function changing. Demonstrated: a one-line distance cutoff in the retriever
leaves all 32 fixture tests green.

**Why structurally allowed — three layers, and the third is the useful one:**

1. The P-010/P-011 gates count ticked ACs and run whatever commands are written. They
   have no way to distinguish "test exercises the component" from "test exercises a
   fixture shaped like the component" — that distinction is not expressible in a
   checkbox or an exit code.
2. The live behaviour *was* verified by hand during T-3021 and recorded in its Evidence
   table. Manual verification that nothing re-runs is folklore. It reads as rigour in
   the task file and provides zero ongoing protection, which is arguably worse than an
   absent check because it discourages adding a real one.
3. **The control that catches this already exists and I ran it too late.** `fw reviewer
   T-3021` emitted `mock-only-integration` — accurately, on first run. But I ran it
   *after* closing T-3021, so the finding could not gate anything and became a
   follow-up task instead of a correction. The reviewer is available before close; my
   sequence was close-then-review rather than review-then-close. Nothing forced that
   order, and nothing flagged it.

**Prevention:** `tests/integration/test_recall_miss_live.py` — no fixtures, real embed,
real vector query, real telemetry row — plus a fail-closed verification line asserting
the test *executed* (`2 passed`, rejecting `skipped`), so an unavailable index fails the
gate rather than passing quietly. Mutation-proven to discriminate: the retriever cutoff
that leaves the fixture suite 32/32 green turns this red.

Distinct from the fix in the direction that matters: the fix is one test file; the
prevention is that the premise is now read from the component on every close, so the
next person to change `_semantic_search` finds out immediately rather than shipping a
classifier whose justification quietly evaporated.

**Process change (layer 3), not yet structural:** run `fw reviewer T-XXX` *before*
`--status work-completed`, not after. Recorded here rather than added as a gate because
whether the reviewer should block close is a policy call with false-positive cost, and
that is the operator's decision, not mine to legislate mid-task.

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

### 2026-08-15T19:51:51Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3023-recall-miss-regression-test-is-fixture-o.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ebd1227d
- **Timestamp:** 2026-08-15T19:57:14Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-15T19:57:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
