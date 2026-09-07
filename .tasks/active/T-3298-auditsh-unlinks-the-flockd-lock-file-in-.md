---
id: T-3298
name: "AUDIT.SH UNLINKS THE FLOCK'D LOCK FILE IN ITS EXIT TRAP, BREAKING THE MUTUAL
  EXCLUSION IT THINKS IT HAS. agents/audit/audit.sh:352 does exec 200>\"$AUDIT_LOCK_FILE\"\
  \ then flock -n 200 (line 353); line 377 sets trap 'kill $AUDIT_TIMEOUT_PID; rm
  -f $AUDIT_LOCK_FILE' EXIT. Unlinking a flock'd path does not release the lock and
  does not stop a later process from creating a NEW inode at the same path and flocking
  that immediately — so two audits can hold 'the' lock at once. The framework already
  documents this exact invariant in the file written to fix the sibling problem: lib/keylock.py's
  module docstring says 'flock binds to an open file description, i.e. to an inode
  — not to a path', which is why keylock never unlinks. audit.sh predates it and was
  not migrated. Second defect in the same block: line 374 runs the watchdog as ( ...;
  sleep $AUDIT_TIMEOUT && kill -TERM $$ ) & and the trap kills only $AUDIT_TIMEOUT_PID,
  the SUBSHELL — killing a subshell does not kill its sleep child, which reparents
  to init and lives AUDIT_TIMEOUT (default 600s). Directly observed as audit.sh(251163)---sleep(251165).
  T-1464/T-1772 mitigated the fd-inheritance half of this (walk /proc/self/fd, close
  >2) but not the orphan itself. Suggested fix: migrate audit.sh to lib/keylock.sh
  exclusive() and delete the rm -f entirely; kill the whole process group for the
  watchdog. Needs its own task (one bug = one task) — this is the root under OBS-304/305/306/307,
  all of which describe symptoms of it."
description: >
  Promoted from observation OBS-308

status: started-work
workflow_type: build
owner: human
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
created: 2026-09-06T18:14:56Z
last_update: '2026-09-07T00:45:16Z'
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
  - ts: '2026-09-07T00:45:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=355,acs=6)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-07T00:45:16Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3298: AUDIT.SH UNLINKS THE FLOCK'D LOCK FILE IN ITS EXIT TRAP, BREAKING THE MUTUAL EXCLUSION IT THINKS IT HAS. agents/audit/audit.sh:352 does exec 200>\"$AUDIT_LOCK_FILE\" then flock -n 200 (line 353); line 377 sets trap 'kill $AUDIT_TIMEOUT_PID; rm -f $AUDIT_LOCK_FILE' EXIT. Unlinking a flock'd path does not release the lock and does not stop a later process from creating a NEW inode at the same path and flocking that immediately — so two audits can hold 'the' lock at once. The framework already documents this exact invariant in the file written to fix the sibling problem: lib/keylock.py's module docstring says 'flock binds to an open file description, i.e. to an inode — not to a path', which is why keylock never unlinks. audit.sh predates it and was not migrated. Second defect in the same block: line 374 runs the watchdog as ( ...; sleep $AUDIT_TIMEOUT && kill -TERM $$ ) & and the trap kills only $AUDIT_TIMEOUT_PID, the SUBSHELL — killing a subshell does not kill its sleep child, which reparents to init and lives AUDIT_TIMEOUT (default 600s). Directly observed as audit.sh(251163)---sleep(251165). T-1464/T-1772 mitigated the fd-inheritance half of this (walk /proc/self/fd, close >2) but not the orphan itself. Suggested fix: migrate audit.sh to lib/keylock.sh exclusive() and delete the rm -f entirely; kill the whole process group for the watchdog. Needs its own task (one bug = one task) — this is the root under OBS-304/305/306/307, all of which describe symptoms of it.

## Context

Fixes the root defect under OBS-304/305/306/307: `agents/audit/audit.sh`'s
flock arm unlinked the lock path in its EXIT trap (and its shared pre-acquire
stale sweep could unlink a HELD lock), breaking mutual exclusion — flock binds
to an inode, not a path (lib/keylock.py invariant). Second defect in the same
block: the timeout watchdog's `sleep` child orphaned to init for up to
AUDIT_TIMEOUT after every normal exit (observed live: audit.sh(251163) →
sleep(251165); this session found live `sleep 600`/`sleep 3000` orphans with
PPID 1 on the host before the fix).

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] **A1 Lock integrity:** audit.sh's mutual exclusion no longer unlinks the
      flock'd lock path (flock binds to inode, not path — lib/keylock.py
      invariant). Either migrated to the framework keylock or the `rm -f` is
      removed from the EXIT trap; the choice and why recorded in `## Decisions`.
      The T-2930 contract is preserved: contention still exits 75.
- [x] **A2 Watchdog orphan:** the timeout watchdog's `sleep` no longer outlives
      the audit — killing the watchdog kills its whole subtree (process-group
      kill or explicit child kill), so no `sleep` child reparents to init for
      up to AUDIT_TIMEOUT seconds after a normal exit.
- [x] **A3 Pinned:** new bats suite `tests/unit/t3298_audit_lock_integrity.bats`
      covers: (a) double-hold impossible — simulate the old bug's shape
      (unlink-while-held, third process acquires) and assert mutual exclusion
      holds; (b) contention exits 75 (control leg); (c) no orphaned watchdog
      sleep after normal exit. Hermetic: scratch lock path, never the live lock.
- [ ] **A4 No-widening:** `bash -n agents/audit/audit.sh` clean and the
      existing `tests/unit/audit.bats` suite keeps passing (modulo the known
      exit-75-contention flake class it already documents).

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

timeout 300 bats tests/unit/t3298_audit_lock_integrity.bats > /tmp/.t3298-bats.out 2>&1 && ! grep -q "^not ok" /tmp/.t3298-bats.out
test "$(grep -c '# skip' /tmp/.t3298-bats.out)" -eq 0
bash -n agents/audit/audit.sh

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

**Symptom:** Concurrent audits could both hold "the" audit lock (double-hold:
a run proceeding while another was mid-flight — the root under OBS-304/305/
306/307), and after every normally-exiting audit an orphaned
`sleep $AUDIT_TIMEOUT` (600s scoped / 3000s full) sat reparented to init.
Both were directly observed live (audit.sh(251163) → sleep(251165); this
session found `sleep 600` and `sleep 3000` PPID-1 orphans on the host).

**Root cause:** Two defects in the same lock/watchdog block of
`agents/audit/audit.sh`. (1) The flock arm's EXIT trap ran
`rm -f "$AUDIT_LOCK_FILE"`, and the shared pre-acquire stale sweep could
`rm -f` a lock another audit was actively holding (a section-scoped run's
660s threshold vs a full run's 3000s budget). flock binds to an open file
description — an inode, not a path — so unlinking a held lock's path lets the
next process create a NEW inode at the same path and flock it immediately:
mutual exclusion silently gone. (2) The timeout watchdog was
`( sleep N && kill -TERM $$ ) &` with a trap killing only the subshell PID;
killing a subshell does not kill its `sleep` child, which reparents to init.

**Why structurally allowed:** The inode-not-path invariant was already
documented in-repo (lib/keylock.py's docstring, written for the sibling T-3042
fix) but audit.sh predates it and was never migrated — knowledge landed in a
library, not in the older call sites. No test held the lock across an audit's
full exit path (T-2930's tests pin the contention exit code, not lock-file
survival), and the double-hold failure mode is a false green: the second audit
RUNS and exits 0, indistinguishable from a healthy run. The watchdog half
looked fixed twice (T-1464/T-1772 closed the fd-inheritance leak in the same
subshell) — the orphan itself was masked by those fixes making it harmless
enough (fds closed) that nothing looked again.

**Prevention:** `tests/unit/t3298_audit_lock_integrity.bats` (10 tests) pins:
lock file + inode survival across the full acquire/release cycle, the exact
old-bug shape (stale-mtime lock held by a live process → contender must exit
75, not acquire), the T-2930 contention contract in both arms, the relocated
fallback-arm sweep in both directions (sweeps stale, refuses fresh), a source
pin that the flock arm's EXIT trap contains no `rm`, and a ps-scoped
no-orphan-sleep check after a normal exit.

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

### 2026-09-06 — Lock fix shape: no-unlink in place, not keylock.sh migration
- **Chose:** Keep audit.sh's own `exec 200>` + `flock -n` block and remove
  every unlink route from the flock arm (the EXIT trap's `rm -f`, and the
  shared pre-acquire mtime stale sweep, which moved into the no-flock fallback
  arm where unlink IS the release mechanism). The lock file becomes a
  permanent rendezvous point, exactly as lib/keylock.py prescribes.
- **Why:** The defect is the unlink, not the primitive. The flock arm needs no
  staleness heuristic at all — the kernel drops the lock when its holder dies.
  Contention semantics (`flock -n` → exit 75, T-2930) stay byte-identical.
- **Rejected:** Migration to `lib/keylock.sh` — it would have REINTRODUCED the
  same bug class: `keylock_acquire` runs `_keylock_clean_stale`, which
  `rm -f`s any lock file older than KEYLOCK_TIMEOUT (default 300s) even while
  held — a full audit (3000s budget) would have its lock unlinked out from
  under it by any contender after 5 minutes. keylock is also blocking-by-
  default (audit needs try-lock → 75), and its lock path is not overridable
  for hermetic tests. Migrating safely would mean fixing keylock.sh first —
  a separate task (one bug = one task).

### 2026-09-06 — Watchdog fix shape: TERM trap in the subshell, not process-group kill
- **Chose:** The watchdog subshell traps TERM, kills its own `sleep` child
  (spawned as a background job so its PID is known), and `wait`s on it —
  `wait` being the one builtin a trap interrupts promptly.
- **Why:** A process-group kill (`kill -- -$AUDIT_TIMEOUT_PID`) is not safe
  here: without job control a background subshell shares the script's process
  group, so the group kill would TERM the audit itself. `setsid` would give
  the watchdog its own group but adds a dependency and changes `$$`
  semantics inside the watchdog for no gain over the explicit child kill.
- **Rejected:** `setsid` + group kill (above); leaving the orphan and
  documenting it (it holds no fds since T-1772, but a 3000s stray sleep per
  audit run is exactly the OBS-304..307 noise this task exists to end).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-06T18:14:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3298-auditsh-unlinks-the-flockd-lock-file-in-.md
- **Context:** Initial task creation

### 2026-09-06T20:02:03Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
