---
id: T-2829
name: "OBS-177: worktree remove guard consults only origin/branch so master-landed
  worktrees are unremovable except via --force"
description: >
  OBS-177: worktree remove guard consults only origin/branch so master-landed worktrees
  are unremovable except via --force

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/worktree.sh]
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
created: 2026-08-06T15:32:26Z
last_update: '2026-08-16T22:25:19Z'
date_finished: 2026-08-06T15:38:07Z
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
  - ts: '2026-08-16T22:25:19Z'
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

# T-2829: OBS-177: worktree remove guard consults only origin/branch so master-landed worktrees are unremovable except via --force

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] `_wt_unpushed_summary` asks *"is any commit on this branch absent from **every** remote
      ref?"* (`git rev-list --count <branch> --not --remotes`), not *"is `origin/<branch>`
      caught up?"* — so a branch FF-landed onto master reads as landed.
- [x] Live regression: the guard **no longer refuses** a worktree whose branch is fully on
      `origin/master`. Measured on `t100199-close`: old predicate 31, correct predicate 0;
      `_wt_unpushed_summary` now returns rc=0/ALLOW where it returned rc=1/REFUSE.
      **Scoped honestly:** `fw worktree remove t100199-close` still fails — but on git's own
      dirty check (17 modified `.context/` files), not on this guard. That is a *different*
      blocker, filed as **OBS-179**, and is T-2822's mechanism observed live.
- [x] The genuine-strand case still REFUSES: `worktree-inception-gov-payload-mediation`
      (3 commits) and `worktree-rca-worktree-push-strand` (1 commit) both refuse, with the
      per-remote diagnostic preserved and exit code 1.
- [x] The refusal message's claim matches what the code measures — it says *"not on any
      remote"* and now consults all of them via `--not --remotes`.
- [x] Regression test pins **both directions** and is mutation-checked.
      → `tests/unit/worktree_remove_guard.bats` 5/5. Mutation (deciding line reverted to
      `origin/<branch>`): **test 1 reds**, tests 2/3/4 survive (they pin safety properties the
      old code also had — correct). Test 5 also survives and is annotated in-file as
      non-discriminating rather than left to read as a guard.

## The fix nearly shipped a worse bug than the one it fixed

The first draft replaced the predicate with `git rev-list --count "refs/heads/$branch"
--not --remotes` and defaulted an empty result to `0` via `${stranded:-0}`. Testing it, I
passed the three **worktree directory names** — and two of them are not branch names
(`.claude/worktrees/rca-worktree-push-strand` is on branch
`worktree-rca-worktree-push-strand`). `rev-list` printed nothing, `${stranded:-0}` read
that silence as *"0 stranded ⇒ safe to remove"*, and all three reported **ALLOW**.

The predicate being replaced **failed safe** in exactly that case (missing remote ref ⇒
refuse). So the fix would have been a regression in the one direction that loses work —
shipping a guard that waves through branches it cannot evaluate.

It is the same defect class as the bug being fixed: **a value that is empty for two
different reasons, read as though it had only one.** Now: unresolvable branch ⇒ refuse with
a stated reason; empty `rev-list` ⇒ refuse rather than guess; both pinned by test 3.

I caught it only because the two `merged:no` rows in `fw worktree status` contradicted the
ALLOW verdict and I checked instead of accepting the convenient answer.

## Two genuine strands surfaced (not this task's to resolve)

The corrected predicate reports real unlanded work in two worktrees — 3 commits on
`worktree-inception-gov-payload-mediation`, 1 on `worktree-rca-worktree-push-strand`.
These are correctly refused. They are separate from the 43 commits T-2824 triaged; left
for the operator, since pushing or discarding another session's branch is not mine to call.

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

bash -n lib/worktree.sh

# The deciding call asks the reachability question
grep -q 'refs/heads/$branch" --not --remotes' lib/worktree.sh

# Undecidable-refuses guard is present (the near-miss regression)
grep -q 'does not resolve -- cannot verify what would be stranded' lib/worktree.sh

# Both-directions suite green, with the T-2738 guard
out=$(bats tests/unit/worktree_remove_guard.bats 2>&1); echo "$out" | grep -q '^ok 5 ' && ! echo "$out" | grep -q '^not ok'

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
#
# Toolchain hint (L-291): if you edited *.vbproj/*.csproj/*.xaml add `dotnet build`;
# *.go → `go build ./...`; Cargo.toml → `cargo check`; tsconfig.json → `tsc --noEmit`;
# pom.xml → `mvn -q compile`. P-011 runs only what you write — broken builds slip
# past otherwise (origin: 003-NTB-ATC-Plugin T-077, broken WPF DLL on master 5 days).
#
# Pipefail/SIGPIPE hint (L-387): P-011 runs each command under `set -eo pipefail`.
# `cmd | grep -q PATTERN` exits 141 (SIGPIPE) when grep matches and closes stdin
# while the upstream is still writing — verification then "fails" even though
# the pattern was present. Safe pattern: capture first, grep the capture:
#     out=$(cmd 2>&1); echo "$out" | grep -q "PATTERN"
# Or:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
# Origin: L-387, captured 4× (T-1716, T-1838, T-1862, T-1863) before this hint.
#
# Single pipe only — no intermediate tail/awk/sed stages between capture and grep
# (T-2090): `echo "$out" | tail -3 | grep -q PAT` re-introduces the SIGPIPE risk
# the capture step closed off — the middle stage is what `grep -q` slams its
# stdin on. grep scans the whole captured string anyway, so the tail-3 was
# cosmetic. Drop it: `echo "$out" | grep -q PAT`.
#
# AND ONLY WHILE THE CAPTURE IS SMALL (T-2743). The two hints above are correct
# for the captures they were written about, and both invert above the pipe
# buffer. `echo "$out" | grep -q PAT` is NOT SIGPIPE-free — it is SIGPIPE-free
# only while "$out" fits in the 65536-byte pipe buffer. Above that, with an
# early match: echo blocks on the full pipe, grep -q exits, echo takes SIGPIPE,
# pipeline exits 141 under pipefail — the exact failure L-387 exists to prevent.
# Measured: a Watchtower page is 146,366 bytes, rc=141 on 3/3 runs, deterministic
# not racy. Any line that curls a rendered page is exposed (routes run 50-200KB).
# For anything that might be large, redirect to a file:
#     cmd -o /tmp/.out && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# This is the better default even when size is not a concern: `&&` keeps the
# PRODUCING command's exit code in the verdict, where `out=$(cmd)` discards it —
# the T-2738 problem one layer down. A 404 from curl fails the line instead of
# silently producing an empty capture for grep to not-match.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no `set -eo pipefail`. The line above returned 0 when run by hand and
# 141 under P-011, from the same directory, the same second. To rehearse for real:
#     bash -c 'set -eo pipefail; <your verification line>'
#
# BUT NOT for a test runner (T-2738): the capture above discards the command's
# exit code, and `set -e` is suppressed inside the `if` condition the gate runs
# each line in — so in `cmd1; cmd2` only cmd2 is the verdict. For pytest/bats
# that exit code WAS the verdict, and the pass marker you grep instead survives
# a partial failure: a suite printing "3 failed, 9 passed" satisfies
# `grep -q "9 passed"`. Generalising to `grep -qE "[0-9]+ passed"` matches the
# same output. Either keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); echo "$out" | grep -q passed && ! echo "$out" | grep -q failed
#     out=$(bats <file> 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The close gate refuses the unguarded form. Bypass: FW_ALLOW_UNJUDGED_TEST_RUN=1.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

## RCA

**Symptom:** `fw worktree remove` refused every worktree whose work had landed, with the
message *"branch '<b>' has commits not on any remote"* — while `git log <b> --not --remotes`
returned 0. Measured on `t100199-close`: guard says 31, truth says 0.

**Root cause:** `_wt_unpushed_summary` decided on `refs/remotes/<r>/<branch>..<branch>` —
"is the same-named branch on the remote caught up?" — and reported the answer in the words
of a *different, wider* question: "not on any remote". Under the T-100196 flow, which is the
normal flow in this repo, work FF-lands onto **master**, so `origin/<branch>` is stale or
never existed while every commit sits safely on `origin/master`. The two questions come
apart for exactly the workflow the framework prescribes.

**Why structurally allowed:** the guard's tests (T-2825) constructed branches pushed to
`origin/<branch>` — the shape the predicate handles. No test constructed the FF-land-onto-
master shape, which is the *dominant* shape in production here. The suite therefore agreed
with the implementation about a world the framework does not operate in. Sibling to T-2735
(nothing checked the SET the count is computed over) and T-2782 (the suite never pinned its
target).

The failure was also **self-concealing in the costly direction**: exit codes were correct
(1 on refuse), the message was fluent, and the remedy it offered — `--force` — worked. An
operator following the guidance gets to a working outcome every time while being trained
into the exact bypass habit the guard exists to prevent. A guard that is wrong *and*
inconvenient gets reported; one that is wrong and offers a working escape hatch does not.

**Prevention:**
1. Predicate now matches the claim (`--not --remotes`), so the message is true.
2. `tests/unit/worktree_remove_guard.bats` constructs the **FF-land-onto-master** shape
   explicitly and asserts its precondition (`origin/<branch>` absent AND
   `origin/master..<branch>` = 0) before asserting the verdict — so a green cannot come from
   the test having built the wrong world.
3. Undecidable ⇒ refuse, pinned by test 3 — closing the near-miss where the fix itself would
   have waved through unevaluable branches.
4. Test 5's non-discriminating nature is annotated in-file so its green is never read as
   behavioural evidence.

**Escalation level:** C (tooling). The B-level lesson is separate and sharper: **when
replacing a predicate, enumerate what the old one refused and check the new one still
refuses it.** The first draft was strictly more permissive in an unexamined case, and only
a contradiction between two on-screen facts (`merged:no` vs ALLOW) surfaced it.

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

### 2026-08-06T15:32:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2829-obs-177-worktree-remove-guard-consults-o.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3768ddec
- **Timestamp:** 2026-08-06T15:38:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-06T15:38:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
