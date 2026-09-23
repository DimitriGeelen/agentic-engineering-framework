---
id: T-3440
name: "Dispatched claude -p workers end their turn while 'waiting' on a run_in_background
  Bash job, and the process exits before the notification can arrive — the close is
  never run. Seen three times on 2026-09-22: T-3433 (push + peer e2e detached, turn
  ended), T-3435/T-3431 earlier, T-3211 ('The background bash test run will notify
  me on completion — no need to poll.' as the final message, task left started-work
  with the work done). In a claude -p worker there is no next turn: a background job
  is a fire-and-forget. Structural fix candidates: (1) agents/dispatch/preamble.md
  states 'never use run_in_background; run tests inline with a timeout' for workers;
  (2) the dispatch stanza sets a marker the harness reads to disable background jobs;
  (3) the driver treats 'exit_code=0 but task still started-work' as a failed step
  and reports it. The parent has been finishing these closes by hand."
description: >
  Promoted from observation OBS-481

status: work-completed
workflow_type: build
owner: agent   # operator assignment 2026-09-23 ("On two, okay that's fine"); no fw verb sets owner — edit recorded on the task
horizon: null
tags: []
components: [agents/dispatch/preamble.md, agents/termlink/termlink.sh]
related_tasks: []
arc_id: arc-001                   # T-3440: dispatch-safety — worker close discipline
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
created: 2026-09-22T21:29:33Z
last_update: 2026-09-23T11:57:46Z
date_finished: 2026-09-23T11:57:46Z
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
  - ts: '2026-09-22T21:30:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-22T21:30:29Z'
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

# T-3440: Dispatched claude -p workers end their turn while 'waiting' on a run_in_background Bash job, and the process exits before the notification can arrive — the close is never run. Seen three times on 2026-09-22: T-3433 (push + peer e2e detached, turn ended), T-3435/T-3431 earlier, T-3211 ('The background bash test run will notify me on completion — no need to poll.' as the final message, task left started-work with the work done). In a claude -p worker there is no next turn: a background job is a fire-and-forget. Structural fix candidates: (1) agents/dispatch/preamble.md states 'never use run_in_background; run tests inline with a timeout' for workers; (2) the dispatch stanza sets a marker the harness reads to disable background jobs; (3) the driver treats 'exit_code=0 but task still started-work' as a failed step and reports it. The parent has been finishing these closes by hand.

## Context

Promoted from OBS-481. Three dispatched workers on 2026-09-22 (T-3433, T-3211, and the
T-3431/T-3435 pair earlier) ended their `claude -p` turn "waiting for the background job to
notify me" and exited; the job's result reached nobody and the task was left `started-work`
with the work done. The parent finished each close by hand. The cause is in our own text:
`agents/dispatch/preamble.md:179` tells the reader to "Use `run_in_background: true` for any
agent expected to produce >500 tokens" — advice for a parent session using the Task tool,
delivered verbatim into a worker that has no next turn. The driver side is blind to it: the
`run.sh` post-step (`agents/termlink/termlink.sh` ~:917–:999) writes `exit_code`,
`finished_at`, `result.md` and records the outcome as success on exit 0, whether or not the
task the worker was dispatched for ever left `started-work`.

## Acceptance Criteria

### Agent
- [x] `agents/dispatch/preamble.md` no longer tells a worker to use `run_in_background`; the
      background-agent guidance (lines ~179–182) is scoped to "parent sessions using the Task
      tool", and a new rule for dispatched workers states: never `run_in_background`, run
      tests inline under `timeout`, and finish every unit to its close in the same turn,
      because a `claude -p` worker has no next turn.
- [x] The dispatch post-step in `agents/termlink/termlink.sh` (the run.sh template) checks,
      when `--task T-XXXX` was given and the exit code is 0, whether that task's file is still
      under `.tasks/active/` with `status: started-work`; if so it writes
      `close_state: incomplete` (plus the task id) into `meta.json`, prints a one-line warning
      naming the task, and records the outcome as `incomplete` rather than success. A task in
      `.tasks/completed/`, or partial-complete (`status: work-completed` in `active/`), records
      `close_state: closed`.
- [x] `fw termlink result <name>` and `fw termlink status` surface `close_state` so the parent
      sees "exit 0, close incomplete" without opening the worker's directory.
- [x] bats: a fixture project with one started-work task and a stub run.sh exit 0 → `meta.json`
      carries `close_state: incomplete` and the warning names the task; the same fixture with
      the task moved to `completed/` → `close_state: closed`; a preamble grep pins the new rule
      and the absence of the old line. `TEST_TEMP_DIR` set in setup; no bare `! grep -q`.
- [x] Vendored copies synced for `agents/termlink/termlink.sh` and `agents/dispatch/preamble.md`;
      `bin/fw vendor self --check` clean; `arc_id: arc-001` set in this task's frontmatter.

**Evidence (one line per AC, in order):**
1. `preamble.md:203-210` — §Orchestrator-Side Rules now opens "**Scope: a parent session using the Task tool.**" and its item 1 reads "any **Task-tool** agent"; the old unscoped line is gone (`grep -c 'for any agent expected to produce'` = 0). New §TermLink Workers subsection `preamble.md:89-112` — "Never background a job — a worker has no next turn (T-3440)".
2. `termlink.sh:987-1035` (run.sh template, between the `T-3440 close-state check` markers) — resolves the task file after `EXIT_CODE` is known; writes `$WDIR/close_state` + `meta.json` `.close_state`/`.close_state_task`; prints the warning; `record-outcome --close-state` makes an incomplete close land in `failures`, not `successes` (exercised live: route-cache showed successes=1/failures=1 for closed/incomplete).
3. `termlink.sh:394-402` (status) and `:1104-1116` (result) — live run printed `WARN close_state: incomplete — T-9001 is still started-work (worker exited 0, close not run)` and the status row `[T-9001]  close: incomplete`.
4. `tests/unit/t3440_close_state.bats` — 14/14 ok, 0 skips; every verdict covered from a fixture project + stub run.sh; absence asserted via `run grep -q` + status 1.
5. `FW_VENDOR_ONLY="agents/termlink/termlink.sh agents/dispatch/preamble.md" bin/fw vendor self` → synced 2 files; `bin/fw vendor self --check` → "vendored .agentic-framework/ in sync with source"; `arc_id: arc-001` set above.

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

timeout 900 bats tests/unit/t3440_close_state.bats > /tmp/.t3440-v1.out 2>&1 && ! grep -q "^not ok" /tmp/.t3440-v1.out
test "$(grep -c '# skip' /tmp/.t3440-v1.out)" -eq 0
timeout 900 bats tests/unit/t3346_termlink_exit_marker.bats tests/unit/termlink.bats tests/unit/lib_dispatch.bats tests/unit/t3422_dispatch_seeds_focus.bats > /tmp/.t3440-v2.out 2>&1 && ! grep -q "^not ok" /tmp/.t3440-v2.out
test "$(grep -c '# skip' /tmp/.t3440-v2.out)" -eq 0
timeout 900 python3 -m pytest tests/unit/test_termlink_worker.py tests/unit/test_termlink_dispatch_task_type.py tests/unit/test_dispatch_pause.py -q > /tmp/.t3440-v3.out 2>&1 && grep -q "passed" /tmp/.t3440-v3.out
bash -n agents/termlink/termlink.sh
grep -q "T-3440 close-state check (start)" agents/termlink/termlink.sh
grep -q "Never background a job — a worker has no next turn" agents/dispatch/preamble.md
test "$(grep -c 'for any agent expected to produce' agents/dispatch/preamble.md)" -eq 0
bin/fw vendor self --check

## RCA

**Symptom:** Three dispatched `claude -p` workers on 2026-09-22 (T-3211, the T-3431/T-3435
pair, T-3433) ended their turn with a sentence of the form "the background job will notify me
on completion — no need to poll", and exited. The work was done; the task stayed in
`.tasks/active/` as `started-work`; the parent closed each one by hand. The driver recorded
all three as successes.

**Root cause:** Two independent halves, neither of which is a coding error.

1. *We told them to.* `agents/dispatch/preamble.md` §Orchestrator-Side Rules item 1 read "Use
   `run_in_background: true` for any agent expected to produce >500 tokens". That is correct
   advice for a parent session using the Task tool — a session that survives the dispatch and
   can read the result on a later turn. The preamble is delivered verbatim *into* the worker,
   where the premise it rests on is false: a `claude -p` worker has no later turn, so a
   backgrounded job is fire-and-forget and everything sequenced after it never happens.
2. *Nothing checked.* The run.sh post-step wrote `exit_code`, `finished_at` and `result.md`,
   and recorded the outcome from the exit code alone. A worker that exits 0 having done the
   work but not the close is byte-for-byte indistinguishable, at every driver surface, from
   one that closed cleanly.

**Why structurally allowed:** the failure is a *false green*, the same family as the port-3000
and stale-Watchtower classes in CLAUDE.md. A red signal gets looked at; a green one that
asserts less than it appears to never prompts anyone. `exit_code=0` looked like a complete
dispatch while answering a strictly narrower question — "did the process terminate without
error" — than the one the parent was reading it as: "did the dispatched unit of work land".
Scope also hid it: the preamble's guidance was *right* for its author's context and only wrong
after delivery, so no reviewer of that line was ever looking at the case where it breaks.

**Prevention** (distinct from the fix):
- The preamble now states its scope on the orchestrator section and carries an explicit
  worker rule, so the sentence that caused this cannot be read as addressed to a worker.
- `close_state` makes the difference *observable*: the post-step resolves the task file after
  the exit code is known, and an unclosed task turns exit 0 into `incomplete` at
  `meta.json`, `$WDIR/close_state`, `fw termlink result` and `fw termlink status`.
- An incomplete close is recorded as a non-success in the route cache, so the routing
  substrate stops learning from dispatches that did not actually land.
- `tests/unit/t3440_close_state.bats` lifts the block out of the live template between its
  markers: editing the post-step moves the assertions rather than orphaning them.

## Evolution

### 2026-09-23 — the outcome ledger is shared, so the new value could not go where it looked like it belonged

- **What changed:** the AC asks for the outcome to be recorded as `incomplete`, and the
  obvious home — a counter in `model_stats` next to `successes`/`failures` — turns out to be
  a cross-repo surface. `route-cache.json` is written by this framework *and* by the TermLink
  hub's Rust `RouteCache`, and its field set is pinned by
  `tests/fixtures/termlink-route-cache-schema.json` (T-1650). Whether the Rust side tolerates
  an unknown key is not verifiable from here: the project-boundary gate (T-559) refuses to
  read `/opt/termlink`, which is correct and was not worth bypassing for a counter.
- **Plan impact:** split the record in two. The *judgement* goes into the shared file in its
  existing vocabulary (an incomplete close is not a success → `failures`), and the *value*
  goes to a new append-only sidecar, `dispatch-close-states.jsonl`, that only we read. Same
  information, no schema change, no reader broken — which is what "add the value without
  breaking existing readers" actually required once the boundary was visible.
- **Triggered:** no new task. Recorded as a decision below; if the hub ever wants the
  distinction, the sidecar is already the join.

### 2026-09-23 — the verdict needed a fourth state the AC did not name

- **What changed:** the AC names `incomplete`, `closed` and (by implication) "no task". A real
  worker also exits non-zero, and a real task file can sit at `captured` or `issues`. Asserting
  `incomplete` there would be wrong — a non-zero exit already failed for a reason the operator
  will read, and the rule says nothing about the other statuses.
- **Plan impact:** `n/a` became the residual rather than only the no-task case, and the
  surfaces stay silent on it. Three values total, so a reader never has to handle a fourth.
- **Triggered:** two extra bats cases (non-zero exit, `captured`) pinning the silence.

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

### 2026-09-23 — where the `incomplete` outcome value is recorded

- **Chose:** leave `route-cache.json`'s `model_stats` shape untouched and let an incomplete
  close increment `failures`; write the literal `incomplete` value to a new append-only
  sidecar `dispatch-close-states.jsonl` beside the cache, plus `meta.json` and
  `$WDIR/close_state`.
- **Why:** the cache is shared with the TermLink hub and pinned by T-1650's schema fixture;
  the boundary gate (correctly) prevents verifying the Rust deserialiser from this session.
  `failures` already means "not a success", which is exactly the judgement being recorded,
  and the sidecar keeps the richer value without asking another repo's parser to tolerate it.
- **Rejected:** an `incompletes` key inside `ModelStats` (unverifiable cross-repo risk for a
  counter); a new top-level key in `RouteCache` (same risk, same reason); counting an
  incomplete close as a success with the detail only in `meta.json` (that is the false green
  this task exists to remove).

### 2026-09-23 — `n/a` as the residual verdict

- **Chose:** exactly three values — `incomplete`, `closed`, `n/a` — with `n/a` covering no
  task dispatched, no task file found, a non-zero exit, and any status outside
  `started-work`/`work-completed`. Both surfaces print nothing for `n/a`.
- **Why:** the check exists to assert one thing. Where it cannot assert it, silence is honest
  and a fourth vocabulary word is a cost every reader pays forever.
- **Rejected:** `unknown`/`other` as a separate state (more vocabulary, no new decision it
  would change); treating `issues`/`captured` as incomplete (the rule says nothing about them,
  and a worker that hit `issues` reported that itself).

### 2026-09-23 — testing the template by extraction rather than by dispatching

- **Chose:** wrap the post-step in `T-3440 close-state check (start/end)` markers and have the
  bats suite lift that region out of the live `termlink.sh` into a stub run.sh.
- **Why:** the logic lives inside a quoted heredoc that is only materialised by a real
  dispatch. Extraction tests the shipped text with no `claude -p`, no TermLink session and no
  network, and editing the block moves the assertions (house style: t3346).
- **Rejected:** re-implementing the logic in the test (pins a copy, not the ship); running a
  real dispatch (needs a live worker and minutes per case).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-22T21:29:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3440-dispatched-claude--p-workers-end-their-t.md
- **Context:** Initial task creation

### 2026-09-23T11:47:46Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f1b47e50
- **Timestamp:** 2026-09-23T11:57:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-23T11:57:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
