---
id: T-3610
name: "A test still writes to filesystem root: /.git/config user t@t and /.git/hooks/commit-msg
  rewritten 2026-09-30 22:30"
description: >
  T-2787 guard (no_root_framework_markers.bats) is red; /.git/config gained [user]
  email=t@t name=T at 22:30:22 and hooks/commit-msg at 22:30:59 on 2026-09-30, during
  worker test runs. Find the test (git config user.email t@t + hook install with cwd
  or target resolving to /), fix it, and add a structural guard so a fixture cannot
  target /.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [bug, tests, T-2787]
components: []
related_tasks: []
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
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
created: 2026-09-30T22:27:01Z
last_update: '2026-09-30T22:30:28Z'
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
bvp_scores_proposed:
  - ts: '2026-09-30T22:29:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-09-30T22:30:28Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=276,acs=6)
    rubric_sha: e4a00f38e801
---

# T-3610: A test still writes to filesystem root: /.git/config user t@t and /.git/hooks/commit-msg rewritten 2026-09-30 22:30

## Context

T-2787 shipped the guard `tests/unit/no_root_framework_markers.bats`, and it is red. `/` holds an empty git repo (created 2026-09-05) plus `/.tasks`, `/.context` and `/.agentic-framework`. On 2026-09-30 a test wrote more:
- `/.git/config` gained `[user] email = t@t, name = T` at 22:30:22;
- `/.git/hooks/commit-msg` was rewritten at 22:30:59.
That was during worker test runs. 72 test files set `user.email t@t`. The root repo also makes every temp dir look like it's inside a git repo, which caused 6 environment reds in T-3604. Clearing `/` stays the operator's call (T-2787 Human AC); this task stops the leak.

## Acceptance Criteria

### Agent
- [x] The test (or tests) that wrote `/.git/config` and `/.git/hooks/commit-msg` is identified with evidence: a run that reproduces the write against a sandboxed fake root, or a code path showing a cwd/variable that resolves to `/`. Named in the RCA
- [ ] The leak is fixed at its source, and every sibling with the same pattern (for example `cd "$UNSET"` / `git -C "$UNSET"` followed by `git config` or `fw git install-hooks`) is fixed too
- [x] A structural guard stops any test fixture from targeting `/`: for example, a shared test-helper check that refuses `git init`, `git config` or hook installation when the resolved target is `/` or outside `$BATS_TEST_TMPDIR` / `$TMPDIR`, or a lint in `bin/fw test lint`. It must be proven to bite with a negative control
- [ ] The fixed tests pass in isolation; nothing new is written to `/` during those runs (mtimes on `/.git/config` and `/.git/hooks/*` are unchanged before and after)

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
# ── Mutable-corpus anchor (T-3326) ────────────────────────────────────────────
# Do NOT anchor a verification line (or a unit test it runs) to MUTABLE corpus
# state — an exact live count, or a grep of live `fw audit`/`fw doctor` output
# for a specific corpus entity (a named arc, a task count, a census number).
# The corpus moves under the check, and the line rots: it goes red (or vanishes
# its pattern) for reasons unrelated to the code under test, blocking closes.
# Pin the INVARIANT (categories sum, count > 0, property holds) or run the code
# against a COMMITTED FIXTURE — never the live count or a live-audit line.
# Origin: T-2969 line grepping live audit for one arc's status; T-2871's census
# test pinning exact live counts (56→74 files) — both blocked closes (OBS-377).
#
# ── Pipefail/SIGPIPE: grepping a command's output (L-387, T-2090, T-2743, T-2738) ──
#
# THE DEFAULT — redirect to a file, then grep the file:
#     cmd > /tmp/.out 2>&1 && grep -q "PATTERN" /tmp/.out
#     curl -sf "$(bin/fw watchtower url)/page" -o /tmp/.out && grep -q "PAT" /tmp/.out
# Correct at any output size, and `&&` keeps the PRODUCING command's exit code in
# the verdict. Reach for this first; the alternative below is the special case.
#
# Why not `cmd | grep -q PAT` (L-387): P-011 runs each line with PIPEFAIL LIVE
# (errexit is not — see below). When grep matches it exits and closes stdin while cmd is still
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
# ── A SKIPPED BATS TEST REPORTS `ok` (T-3217) ─────────────────────────────────
#
# `! grep -q "^not ok"` does NOT mean the suite ran. Bats emits a skip as
#     ok 6 <name> # skip <reason>
# which is not a `not ok`, so the gate passes and the report says ok while the
# thing the test covers was measured NOWHERE. Origin: T-3213 guarded a test with
# `[ "$(id -u)" -eq 0 ] && skip` — the suite runs as root here and in CI, so it
# skipped on every run that mattered, for as long as it existed.
#
# Add a skip clause to any bats verification line. `# skip` is the marker bats
# writes; counting it is the whole check:
#     timeout 300 bats <file> > /tmp/.out 2>&1 && ! grep -q "^not ok" /tmp/.out
#     test "$(grep -c '# skip' /tmp/.out)" -eq 0
# Two lines, because they answer different questions — "did anything fail" and
# "did everything run". If some skips are legitimate on your host (an optional
# dependency is genuinely absent), assert the COUNT you expect rather than zero,
# and say in the task why that number is right.
#
# Corpus-wide, the same check runs from `bin/fw test lint`
# (tools/bats-silent-skip-lint.py): static mode flags guards that are fixed for
# a deployment rather than probing an optional dependency, and `--tap FILE`
# reports the skips a real run actually fired.
#
# REHEARSING A LINE BY HAND DOES NOT REHEARSE THE GATE (T-2743). Your interactive
# shell has no pipefail. A line has returned 0 by hand and 141 under P-011, from
# the same directory, the same second. To rehearse for real:
#     bash -c 'set -o pipefail; <your verification line>'
#
# NOTE THE MISSING `-e` — it is not a typo (T-3203). This file used to prescribe
# `set -eo pipefail` here, which is NOT the gate: it adds errexit the gate does
# not have, so it FAILS lines the gate PASSES. Measured, 10 lines, 3 diverged:
#     line                            gate    set -eo (old)   set -o (this)
#     false; true                     PASS    FAIL  wrong     PASS  ok
#     cd /nonexistent; echo ok        PASS    FAIL  wrong     PASS  ok
#     grep -q MISS file; true         PASS    FAIL  wrong     PASS  ok
# The divergence is one-directional and that is the trap: the old rehearsal only
# ever fails lines the gate accepts, so it produces false REDS, and an author
# who "fixes" a line to satisfy it is fixing something that was never broken —
# while the line that actually is broken (`cmd1; cmd2` where cmd1 fails) passes
# both. Re-derive rather than trust this table — it is pinned, not asserted:
#     bats tests/unit/t3203_p011_gate_semantics.bats
#
# ── `cmd1; cmd2` IS JUDGED ONLY ON cmd2 (T-3203) ──────────────────────────────
#
# The gate runs each line as the CONDITION of an `if` (update-task.sh:1215), and
# POSIX suppresses errexit for a compound command in an `if` condition — through
# the subshell. So pipefail applies and `set -e` does not, and in a sequence only
# the LAST command's status reaches the verdict. `cd /nonexistent; echo ok` passes.
# 2,644 of 10,997 verification lines in this corpus contain `;` (re-derive with
# the query in docs/reports/T-3203-p011-gate-semantics.md).
#
# SAFE SHAPES — both verified biting, each against a passing control:
#   A. one command whose own status is the verdict (prefer this):
#        out=$(cmd 2>&1); echo "$out" | grep -q PAT && ! echo "$out" | grep -q BAD
#      the leading assignments are setup; the trailing `&&` chain is the verdict.
#   B. an explicit sub-shell, whose errexit the outer `if` cannot reach into:
#        bash -c 'set -eo pipefail; cmd1; cmd2'
#      use when you genuinely need every command in the sequence to count.
#
# The rule of thumb: put the assertion LAST, and make sure it is an assertion.
#
# Enforcement-baseline hint (L-398, T-1886): if you edited `.claude/settings.json`
# (added/removed/reorganised hooks), add `bin/fw enforcement baseline` to your
# Verification block. Otherwise the canonical hash diverges and `fw doctor`
# reports a FAIL ("Enforcement baseline CHANGED") that accumulates silently.
# Origin: T-1849/T-1730/T-1731 each added a legitimate hook without refreshing
# the baseline — FAIL sat for multiple sessions until T-1886 cleaned up.

timeout 300 bats tests/lint/bats-git-discovery-fence.bats > /tmp/.t3610-lint.out 2>&1 && ! grep -q "^not ok" /tmp/.t3610-lint.out
test "$(grep -c '# skip' /tmp/.t3610-lint.out)" -eq 0
grep -q 'source "$(dirname "${BASH_SOURCE\[0\]}")/git_fence.bash"' tests/test_helper.bash

## RCA

**Symptom:** `/.git/config` gained `[user] email = t@t, name = T` at 2026-09-30 22:30:22 (+0200) and `/.git/hooks/{commit-msg,pre-commit,post-commit,pre-merge-commit,pre-push}` were rewritten at 22:30:59. Also `/.git/worktrees/fresh-wt*` accumulates one entry per run of `init_head_bootstrap.bats` (fresh-wt … fresh-wt11, 2026-09-26 to 2026-09-30).

**Root cause: two writers, one mechanism.** git finds "the repo" by walking up from cwd. A fixture dir under /tmp that is not itself a repo resolves to the stray `/.git` (created 2026-09-05, T-2787), and both writes succeed against the wrong repo.

1. **22:30:22, config.** Not a framework test. TermLink worker `worker2-t1647` (project `/opt/1409-sprind`, T-1647) ran `bash .claude/hooks/tests/run-pruefstand-tests.sh 2>&1 | head -20` from 20:30:21.19Z to 20:30:23.94Z (log: `/tmp/tl-dispatch/worker2-t1647/result.jsonl`). Each case does `cd "$TMPTEST/r$n"; git init; git config user.email 't@t' 2>/dev/null; git config user.name 'T' 2>/dev/null`. Once `head` closed the pipe, the next `git init` (which prints hints to the pipe) died of SIGPIPE before creating `.git`. The silent `git config` calls survived, found no local repo, and wrote `/.git/config`. **Reproduced** against a fake root (a tmp dir with its own `.git`, TMPDIR under it): the script's config writes landed in the fake root's `.git/config` only when piped to `| head -20`, and not when run without the pipe.
2. **22:30:59, hooks.** `tests/unit/init_head_bootstrap.bats`, run on its own by the T-3601 worker (`xargs -P4 … bats "$f"` over the failing-file list, `/tmp/t3601-runs/init_head_bootstrap.bats.tap`, finished 22:31:22.9), called `fw init "$HDIR/fresh"` on a /tmp fixture. With `/.git` above it, the fixture was "a subdirectory of an existing repo": no fresh repo, and the hooks went to `/.git/hooks`. The tap shows `not ok 5 … [ -x "$HDIR/fresh/.git/hooks/commit-msg" ] failed`, and `/.git/worktrees/fresh-wt8` (gitdir `/tmp/bats-run-OHH67U/file/1/t2821/fresh-wt/.git`) was created at 22:31:18 by the same run. **Reproduced** against a fake root with the pre-fence version (`559f48591^`): all five hooks installed into the fake root's `.git/hooks`, with sizes identical to `/`'s (commit-msg 10729, pre-commit 10382, post-commit 6243, pre-merge-commit 2038; `VERSION=1.17`), plus a `fresh-wt` worktree. T-3603 fenced this file at 2026-10-01 00:34 (559f48591), after the write.

**Why structurally allowed:** nothing in the test harness bounded git discovery. `guard_project_root` (T-2788) checks `$PROJECT_ROOT` paths, not where git resolves a repo, and a discovery escape needs no unset variable at all: a fixture that simply is not (yet) a repo is enough. The T-2787 guard detects markers at `/` after the fact and has been red, so it no longer distinguishes a new write from the old pollution.

**Prevention:** `tests/git_fence.bash` sets `GIT_CEILING_DIRECTORIES` at the temp roots (`/tmp`, `$TMPDIR`, the bats run base). `tests/test_helper.bash` sources it, so all 389 helper-loading bats files are fenced. `tests/lint/bats-git-discovery-fence.bats` (run by `fw test invariants`) fails any bats file that runs `fw init` or installs hooks without a fence, with an explicit, shrinking grandfather list. Its negative controls prove that the lint flags an unfenced writer, and that the fence stops `git config` and `rev-parse --show-toplevel` escaping to a repo above the temp dir while a repo inside the temp dir is still found.

**Not fixed here (cross-boundary):** the sprind script lives in `/opt/1409-sprind` (T-559 project boundary). Its fix (`GIT_CEILING_DIRECTORIES="$TMPTEST"`, or `git -C "$repo" init … || exit`) belongs in that project (gap homing, T-1333).

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

### 2026-10-01 — guard shape: fence git discovery centrally + lint, not a refusal helper
- **Chose:** `tests/git_fence.bash` (GIT_CEILING_DIRECTORIES at the temp roots), sourced by `tests/test_helper.bash`, plus a `tests/lint/` rule requiring a fence in every bats file that runs `fw init` or installs hooks.
- **Why:** the class is git discovery escaping a fixture, and neither observed write involved an unset variable or a `/` target that a path-check helper could see. Both targets were valid /tmp paths that were simply not repos. A ceiling works at the git layer, whatever the call site (`git config`, `fw init`, `install-hooks`, `worktree add`), and needs no per-call opt-in. One line in the shared helper covers 389 files, and the lint covers the files that do not load the helper.
- **Rejected:** (a) a `refuse_root_target` helper called before each git write: opt-in per call site, and blind to the real mechanism (target is a /tmp path, the repo resolved is `/`). (b) A refusal in `install-hooks` when toplevel is `/`: it lives in `agents/git/lib/hooks.sh` (owned by concurrent T-3593 work), and it would not stop the `git config` write. Worth a separate task. (c) Setting the fence only in the `fw test` runner: ad-hoc `bats file` runs, which caused both writes, bypass it.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-30T22:27:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3610-a-test-still-writes-to-filesystem-root-g.md
- **Context:** Initial task creation

### 2026-09-30T22:29:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
