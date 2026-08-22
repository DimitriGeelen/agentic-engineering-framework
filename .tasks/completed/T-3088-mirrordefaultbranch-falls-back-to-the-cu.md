---
id: T-3088
name: "mirror_default_branch falls back to the current branch, so the github mirror
  has compared two different branches since 2026-08-14"
description: >
  mirror_default_branch falls back to the current branch, so the github mirror has
  compared two different branches since 2026-08-14

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
created: 2026-08-19T19:38:28Z
last_update: 2026-08-22T14:09:31Z
date_finished: 2026-08-22T14:09:31Z
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
  - ts: '2026-08-19T19:45:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=268,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-19T19:45:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3088: mirror_default_branch falls back to the current branch, so the github mirror has compared two different branches since 2026-08-14

## Context

`fw mirror sync` has reported `github: DIVERGED` on every run since
**2026-08-14T15:45:02Z** — roughly 480 consecutive refusals over five days — while GitHub
and OneDev have in fact been byte-identical on `master` the entire time
(`10663c1d43b78fa19942248e399989a63b5c7f4e` on both).

The two values it compares come from different branches:

- `origin_head` (`lib/mirror.sh:126`, `:156`) = `git ls-remote origin HEAD` -> origin's
  **default branch**, i.e. `master` -> `10663c1d`.
- `branch` (`lib/mirror.sh:141`, `:171`) = `mirror_default_branch()`, which reads
  `refs/remotes/origin/HEAD` — **not set in this checkout**
  (`fatal: ref refs/remotes/origin/HEAD is not a symbolic ref`) — and then falls back to
  *the local current branch*, `t2539-staging`.

`mirror_sync_one` then fetches `refs/heads/t2539-staging` from github (`9cf2eb6f`) and asks
whether it is an ancestor of origin's **master**. It is not, and never will be: they are
different branches. The `merge-base --is-ancestor` test fails, the function takes the
`diverged` path, logs the event and refuses. Deterministic, not intermittent.

The fallback itself is the defect. `mirror_default_branch()`'s contract is "resolve the
default branch **on origin**"; substituting the local current branch answers a different
question and silently makes the caller compare unrelated refs. When `refs/remotes/origin/HEAD`
is absent the honest answers are to query the remote (`git ls-remote --symref origin HEAD`)
or to fail loudly — not to guess with whatever branch the operator happens to be standing on.

**Why nobody noticed for five days:** it fails in the safe direction. `diverged` refuses to
push and asks for a human, which is exactly what a *real* divergence should do, so the log
line is indistinguishable from correct behaviour. T-1829 added push-stderr capture precisely
so a recurring mirror stall would be diagnosable from the log alone — but that captures
`push-failed`, and this path never reaches a push. Sibling to T-1828's 7-hour silent stall,
one branch earlier in the same function.

**Separate, and not this task's problem:** `master` itself last moved on 2026-08-14
(`10663c1d`). The working branch is 338 commits ahead of it and 0 behind. That is why
github.com *looks* stale, and it is an operator decision about landing to trunk (T-100201),
not a mirror defect. Fixing this task will not move `master`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **A1 — `mirror_default_branch` answers the question it is named for.** With
      `refs/remotes/origin/HEAD` absent, it resolves origin's real default branch (e.g. via
      `git ls-remote --symref origin HEAD`) rather than substituting the local current
      branch. If it genuinely cannot resolve one, it fails loudly instead of guessing.
- [x] **A2 — the two compared values come from the same branch.** `origin_head` and the ref
      fetched from the mirror are read for one and the same branch name; asserted by a test
      that drives `mirror_sync_one` with the local checkout on a non-default branch — the
      exact condition that has been live since 2026-08-14.
- [x] **A3 — `fw mirror status` reports in-sync for the current real state.** Both remotes
      are at `10663c1d` on master today, so the correct verdict is in-sync, not DIVERGED.
      Run before and after; the before-state is the bug reproducing.
- [x] **A4 — positive control (L-616).** A genuinely diverged mirror still reports
      `diverged` and still refuses to push. Without this, a change that merely stops
      reporting divergence is indistinguishable from one that fixes the comparison.
- [x] **A5 — the silent-refusal class is made visible.** A mirror stuck in `diverged` for
      more than N consecutive runs surfaces somewhere the operator reads (`fw doctor`), so
      the next instance of "fails in the safe direction, forever" is not found five days
      later by someone asking why GitHub looks old.

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

# The helper must not answer with the local current branch when origin/HEAD is absent.
# Reproduces the live condition: this checkout sits on a non-default branch and has no
# refs/remotes/origin/HEAD. L-387: redirect then grep, never pipe into grep -q.
bash -c 'source lib/mirror.sh; mirror_default_branch' > .context/working/.t3088-branch.out 2>&1
grep -qx "master" .context/working/.t3088-branch.out

# The mirror's verdict must match observable reality (both remotes on master).
bin/fw mirror status > .context/working/.t3088-status.out 2>&1
grep -q "in sync" .context/working/.t3088-status.out && ! grep -q "DIVERGED" .context/working/.t3088-status.out

# Regression tests for the comparison itself (A1/A2/A4) plus the stuck-diverged
# visibility check (A5). Extends the existing mirror_sync suite rather than a
# new file — same fixtures, same sourcing convention.
bats tests/unit/test_mirror_sync.bats tests/unit/test_mirror_stderr_capture.bats > .context/working/.t3088-bats.out 2>&1
grep -qE '^1\.\.[0-9]+$' .context/working/.t3088-bats.out && ! grep -q "^not ok" .context/working/.t3088-bats.out

bash -n bin/fw
bash -n lib/mirror.sh


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

**Symptom:** `fw mirror sync` reported `github: DIVERGED` on every 15-minute cron run from
2026-08-14T15:45:02Z onward, while GitHub and OneDev were in fact byte-identical on `master`
the entire time.

**Root cause:** `mirror_default_branch()` (`lib/mirror.sh:27`) tried `refs/remotes/origin/HEAD`
(a local tracking-ref cache that is not populated by `git remote add` + `git push`, only by
`git remote set-head` or certain fetch configurations), and when that was absent it fell back
to **the local checkout's current branch** rather than asking origin what its default branch
actually is. `mirror_sync_one` then compared `origin_head` (origin's default branch SHA) against
`refs/heads/<local-current-branch>` fetched from the mirror — two unrelated branches — via
`merge-base --is-ancestor`, which correctly reported them as non-ancestors ("diverged") because
they were never the same lineage to begin with.

**Why structurally allowed:** the failure mode is fail-safe by design (diverged mirrors are
never auto-pushed, by intent — human decision required), so the log output was indistinguishable
from a genuine divergence. Nothing compared the *log's own history* to notice the refusal was
permanent rather than transient. T-1829 added push-stderr capture for exactly this class of
silent stall, but only on the `push-failed` path — this bug never reaches a push, so that
safety net didn't cover it.

**Prevention:**
1. `mirror_default_branch()` now resolves origin's default branch authoritatively via
   `git ls-remote --symref origin HEAD` when the local tracking-ref cache is absent, and fails
   loudly (non-zero exit, no output) instead of guessing from local checkout state.
2. `mirror_sync` / `mirror_status` abort cleanly if the branch can't be resolved, rather than
   proceeding with an empty branch name.
3. New `mirror_stuck_diverged_check()` (lib/mirror.sh) + `fw doctor` wiring (bin/fw, T-3088)
   WARNs when a remote's last 4 consecutive sync-log entries are all `diverged` — turning "fails
   safe, forever, unnoticed" into a surfaced signal the next time this class recurs for any
   reason (genuine divergence included).
4. Regression tests in `tests/unit/test_mirror_sync.bats` pin the exact live condition (local
   checkout on a non-default branch, no `refs/remotes/origin/HEAD`) and were verified to fail
   against the pre-fix code before the fix landed.

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

### 2026-08-19T19:38:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3088-mirrordefaultbranch-falls-back-to-the-cu.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bb18ed0b
- **Timestamp:** 2026-08-22T14:09:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-22T14:09:31Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
