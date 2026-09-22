---
id: T-3421
name: "pre-push audit lock wait (90s) is shorter than the structure audit it waits
  for (~292s): every contended push fails and re-runs the audit"
description: >
  pre-push audit lock wait (90s) is shorter than the structure audit it waits for
  (~292s): every contended push fails and re-runs the audit

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/git/lib/hooks.sh, lib/prepush-lock-wait.sh, tests/unit/t3421_prepush_lock_wait.bats]
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
created: 2026-09-22T08:14:13Z
last_update: 2026-09-22T08:30:51Z
date_finished: 2026-09-22T08:27:28Z
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
  - ts: '2026-09-22T08:15:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T08:15:20Z'
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
---

# T-3421: pre-push audit lock wait (90s) is shorter than the structure audit it waits for (~292s): every contended push fails and re-runs the audit

## Context

T-3297 added a bounded wait to the pre-push audit gate so that lock contention
becomes "a short pause instead of a failed push". Its default is 90 seconds
(`FW_PREPUSH_LOCK_WAIT`, `agents/git/lib/hooks.sh:1137`). The audit it waits
for is `--section structure`, which the framework's own timing ledger
(`.context/audits/full-audit-timing.yaml`, T-3127) measures at **292 seconds**.
So the wait is shorter than the thing it waits for by a factor of three, and
the same premise decay T-3297 corrected ("finishes within a minute or two")
has happened again one level down.

**Measured today, 2026-09-22.** Five concurrent writers (this session, the
SEQ-T3411 driver's workers, the 30-minute cron audit). The r2-procasfit worker
hit "another audit holds the lock" 10 times; r3-procasfit 8 times; this
session's own push loops 9, 7, and 9 times across three pushes. Each hit is a
90 s wait, a failed push, and — on retry — a fresh 292 s structure audit that
itself holds the lock against everyone else. The queue is self-amplifying:
every retry lengthens the lock for the next pusher.

**Fix shape.** Make the wait long enough to outlast one structure audit, and
derive it from the measurement rather than asserting it: default =
1.25 × the last measured `structure` seconds from the timing ledger, clamped
to [90, 600]; 360 s when no ledger exists. An explicit `FW_PREPUSH_LOCK_WAIT`
still wins. The block message quotes the derived number. Nothing about the
no-false-pass rule changes: window exhausted → the same BLOCK.

**Not in scope.** Reusing a recent verdict instead of re-running (a cache keyed
on tree hash) — a larger change with its own correctness questions; named in
Evolution as the next step if queueing alone is not enough.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `lib/prepush-lock-wait.sh:fw_prepush_lock_wait_default <project_root>` prints the derived wait: ceil(1.25 × `structure` seconds) from `.context/audits/full-audit-timing.yaml`, clamped to [90, 600]; 360 when the ledger is absent, non-numeric, or has no `structure` entry. Live on this repo: **365** (from 292)
- [x] `agents/git/lib/hooks.sh` sources the lib and uses the derived default when `FW_PREPUSH_LOCK_WAIT` is unset; an explicit value still overrides; the block message quotes the window and its source (`derived from .context/audits/full-audit-timing.yaml (T-3421)` / `fallback default` / `FW_PREPUSH_LOCK_WAIT`); the "wait longer" suggestion moved 300 → 600. Live hook reinstalled (`fw git install-hooks --force`), `.git/hooks/pre-push` carries the derivation (3 references)
- [x] `tests/unit/t3421_prepush_lock_wait.bats` — 7 tests: 292→365, absent→360, 10→90 (floor), 1000→600 (cap), non-numeric→360, no-structure-entry→360 (does not borrow another section's number), and a source pin that the hook wires the derivation and keeps the env override. **7/7 ok, 0 skips**
- [x] `tests/unit/t3297_prepush_lock_wait.bats` still green — **11/11** — with two deliberate pin updates: (b) suggestion literal 300→600, (i) "default is 90" → "default is derived; 90 is the floor"
- [x] RCA filled (bug-class: title matches "fails"), including the round-3 worker's counter-evidence on what a longer window does *not* fix; `lib/prepush-lock-wait.sh` + the bats file registered in the fabric; vendored copies synced via `FW_VENDOR_ONLY` (VERSION 1.6.762), `bin/fw vendor self --check` clean

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

timeout 300 bats tests/unit/t3421_prepush_lock_wait.bats > /tmp/.t3421-bats 2>&1 && ! grep -q "^not ok" /tmp/.t3421-bats
test "$(grep -c '# skip' /tmp/.t3421-bats)" -eq 0
timeout 600 bats tests/unit/t3297_prepush_lock_wait.bats > /tmp/.t3421-t3297 2>&1 && ! grep -q "^not ok" /tmp/.t3421-t3297
test "$(grep -c '# skip' /tmp/.t3421-t3297)" -eq 0
bash -n agents/git/lib/hooks.sh && bash -n lib/prepush-lock-wait.sh
# The derived default on this repo is an integer in [90,600] (invariant, not the live number — T-3326).
bash -c 'source lib/prepush-lock-wait.sh; fw_prepush_lock_wait_default "$PWD"' > /tmp/.t3421-wait 2>&1 && grep -qE '^[0-9]+$' /tmp/.t3421-wait && test "$(cat /tmp/.t3421-wait)" -ge 90 && test "$(cat /tmp/.t3421-wait)" -le 600
# The LIVE hook (not just the source) carries the derivation — install-hooks was re-run.
grep -q "prepush-lock-wait.sh" .git/hooks/pre-push
test -f .fabric/components/lib-prepush-lock-wait.yaml
bin/fw vendor self --check

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

## RCA

**Symptom:** With several concurrent writers (this session, the SEQ-T3411
workers, the 30-minute cron audit), `git push` fails with "audit COULD NOT
RUN (another audit holds the lock)" — 10 and 8 hits in two workers'
transcripts, 25 across this session's three pushes, on one morning. Each
retry re-runs a full structure audit and holds the lock against the next
pusher, so the queue amplifies itself.

**Root cause:** T-3297's bounded wait defaults to 90 s (`FW_PREPUSH_LOCK_WAIT`)
while the audit it waits for — `--section structure`, the one the gate
itself runs — measures 292 s in the framework's own timing ledger. The
window is shorter than the event it waits for by ~3×, so under any real
contention the wait always expires and the push always blocks. The constant
was asserted from a premise ("a minute or two") that the ledger already
contradicted.

**Why structurally allowed:** the timing ledger (T-3127) and the wait
default (T-3297) were written two weeks apart by two tasks that never
referenced each other; nothing compares a wait to the duration it waits for.
T-3297's own pin — test (i) asserted the literal `90` in the hook source —
made the constant look load-bearing rather than measured, so the next reader
saw a pinned design decision and not a decayed premise. This is the second
decay of the same premise (T-3297 corrected "finishes within a minute or
two"), one level down.

**Prevention:** the default is now derived from the ledger at push time
(`lib/prepush-lock-wait.sh`, 1.25× measured structure seconds, clamped
[90, 600]), so the wait tracks the audit as the audit grows, and the pin in
`t3297 (i)` now asserts the derivation is wired rather than the number.

**Not prevented by this task, with evidence.** The SEQ-T3411 round-3 worker
(`docs/reports/SEQ-T3411/r3-procasfit-handback.md`, Selection 1) verified
this task's premise independently and then reported that its own
`FW_PREPUSH_LOCK_WAIT=320` push still failed: with several pushers plus the
30-minute cron, the lock is re-acquired by a new entrant the moment it
frees, and the T-3297 poll loop has no queue fairness — each waiter's window
is spent racing, not queueing. A longer window therefore converts *some*
contention into a pause, not all of it. The structural next step is to stop
re-running the audit at all when a fresh verdict exists for the same tree
(a tree-hash-keyed verdict cache, or a `flock -w` blocking acquire that the
kernel serialises instead of a poll race). Named here, not built; it is a
gate-semantics change and warrants its own task.

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

### 2026-09-22T08:14:13Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3421-pre-push-audit-lock-wait-90s-is-shorter-.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cdb33e80
- **Timestamp:** 2026-09-22T08:29:51Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — `lib/prepush-lock-wait.sh:fw_prepush_lock_wait_default <project_root>` prints the derived wait: ceil(1.25 × `structure` seconds) from `.context/audits/full-audit-timing.yaml`, clamped to [90, 600]; 36
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/full-audit-timing.yaml in: `lib/prepush-lock-wait.sh:fw_prepush_lock_wait_default <project_root>` prints the derived wait: ceil(1.25 × `structure` seconds) from `.context/audits`
- **AC#2 (Agent)** — `agents/git/lib/hooks.sh` sources the lib and uses the derived default when `FW_PREPUSH_LOCK_WAIT` is unset; an explicit value still overrides; the block message quotes the window and its source (`der
  - **AC-verify-mismatch** (narrow, heuristic) — `path=context/audits/full-audit-timing.yaml in: `agents/git/lib/hooks.sh` sources the lib and uses the derived default when `FW_PREPUSH_LOCK_WAIT` is unset; an explicit value still overrides; the bl`
### 2026-09-22T08:27:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
