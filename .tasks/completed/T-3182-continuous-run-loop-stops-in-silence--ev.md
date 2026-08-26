---
id: T-3182
name: "continuous-run loop stops in silence — every claude-fw exit path must record why"
description: >
  continuous-run loop stops in silence — every claude-fw exit path must record why

status: work-completed
arc_id: continuous-run
workflow_type: build
owner: agent
horizon: null
tags: []
components: [bin/claude-fw, tests/unit/t3182_loop_exit_recorder.bats]
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
created: 2026-08-26T20:35:23Z
last_update: 2026-08-26T20:39:22Z
date_finished: 2026-08-26T20:39:22Z
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

# T-3182: continuous-run loop stops in silence — every claude-fw exit path must record why

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `bin/claude-fw` defines `_record_loop_event`, appending one JSON line per loop event to `.context/working/continuous-run.jsonl`
- [x] Every `exit` inside the wrapper's main loop is preceded by a `_record_loop_event` call — no silent exit path remains
- [x] Each exit path records a **distinct** reason (`auto-restart-disabled`, `no-git-repo`, `max-restarts`, `stale-signal`, `no-signal`), so the record says *which* path was taken
- [x] Loop **iterations** are recorded too (`event: iterate`), so "went round N times then stopped" is distinguishable from "never started"
- [x] The recorder is non-fatal: outside a git repo, or with any internal failure, it returns 0 and does not alter the wrapper's exit code
- [x] `tests/unit/t3182_loop_exit_recorder.bats` reads the REAL wrapper (lifts its function, statically scans its loop) rather than a transcribed copy
- [x] A control leg asserts reasons are distinct — without it, "record every exit" and "record something on every exit" are the same diff
- [x] Mutation-tested: silencing one path reddens the every-path test; collapsing all reasons to one constant reddens ONLY the control leg; dropping a JSON field reddens the shape test
- [x] `bin/fw` is NOT touched — it is held uncommitted by concurrent task T-3127, so this change is scoped to `bin/claude-fw` and its test

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

- **Learned during build:** the task was filed to answer *why did the wrapper leave its
  loop tonight* (T-3181 IW-6). Reading the loop showed that question is not answerable
  from disk at all — all six exit paths were silent, so the evidence needed to answer it
  had never been written. The deliverable changed from *find the cause* to *make the
  cause recordable*, which is the honest scope: I have NOT determined why the wrapper
  stopped at 21:25, and the instrumentation is what lets the next occurrence answer it
  instead of costing another round of PID forensics.
- **Plan impact:** surfacing the log through `fw doctor` was in the original shape and
  came out. `bin/fw` is held uncommitted by T-3127, and editing it would have shipped
  another task's unfinished work under this commit. Deferred rather than taken.
- **Triggered:** T-3183 (Human AC markdown double-escape, reported by 001-CashWeb with a
  discriminator), T-3184 (BVP ranking is degenerate, blocking the complete-arc work
  selection the operator specified in T-3181 D-1.1).
- **Caught by rehearsal:** the `bin/fw` verification line originally asserted a clean
  working tree and would have blocked the close, because T-3127 holds that file dirty on
  purpose. Running the lines under the gate's own `set -eo pipefail` before hitting the
  gate is what surfaced it.

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

out=$(bats tests/unit/t3182_loop_exit_recorder.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
bash -n bin/claude-fw
grep -q '_record_loop_event()' bin/claude-fw
test "$(grep -c '_record_loop_event' bin/claude-fw)" -ge 7
# NOT `git diff HEAD -- bin/fw`: T-3127 holds bin/fw dirty in the WORKING TREE on
# purpose. The claim is that THIS COMMIT does not touch it, which is a property of
# the diff I authored, not of the tree I authored it in.
git show --stat --format= HEAD > /tmp/.t3182-stat 2>&1 && ! grep -qE "^ +bin/fw " /tmp/.t3182-stat

## Decisions

### Record the reason at every exit, including the ordinary one

The loop had six ways out and all six were silent. The temptation is to record only
the *abnormal* endings — max-restarts, stale signal — and let a clean exit pass
without comment. That reproduces the defect: "claude exited normally and nobody asked
for a restart" and "the supervisor broke" both then leave nothing behind, and the
operator's question ("why isn't the loop running?") is unanswerable from disk in
exactly the case that matters.

Iterations are recorded for the same reason. A log that only records endings cannot
distinguish *went round three times then hit the valve* from *never started*, which
is the specific ambiguity that cost this session process forensics on PIDs and file
mtimes tonight.

### The control leg is what makes the test mean anything

Asserting "every exit path is recorded" is satisfied by a recorder wired with one
constant string, which tells the operator nothing about which path was taken. The
distinct-reasons test is the discriminator. Mutation M2 confirms the split: collapsing
all five reasons to one constant leaves the every-path test GREEN and reddens only the
control leg.

### Scoped away from `bin/fw` deliberately

`bin/fw`, `lib/config.sh`, `agents/audit/audit.sh`, `web/blueprints/config.py` and
`lib/audit_timing.py` are held uncommitted by concurrent task T-3127. Surfacing this
log through `fw doctor` would have meant editing `bin/fw` and shipping another task's
unfinished work under this commit. The surface is deferred to a follow-up rather than
taken here.

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

### 2026-08-26T20:35:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3182-continuous-run-loop-stops-in-silence--ev.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-23093058
- **Timestamp:** 2026-08-26T20:39:24Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `bin/claude-fw` defines `_record_loop_event`, appending one JSON line per loop event to `.context/working/continuous-run.jsonl`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/working/continuous-run.jsonl in: `bin/claude-fw` defines `_record_loop_event`, appending one JSON line per loop event to `.context/working/continuous-run.jsonl``
- **AC#6 (Agent)** — `tests/unit/t3182_loop_exit_recorder.bats` reads the REAL wrapper (lifts its function, statically scans its loop) rather than a transcribed copy
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/t3182_loop_exit_recorder.bats in: `tests/unit/t3182_loop_exit_recorder.bats` reads the REAL wrapper (lifts its function, statically scans its loop) rather than a transcribed copy`

### 2026-08-26T20:39:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
