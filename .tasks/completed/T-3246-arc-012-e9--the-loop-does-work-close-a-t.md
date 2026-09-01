---
id: T-3246
name: "arc-012 E9 — the loop does WORK: close a task, trip, restart, close another"
description: >
  arc-012 E9 — the loop does WORK: close a task, trip, restart, close another

status: work-completed
workflow_type: test
owner: agent
horizon: null
tags: []
components: [bin/fw, lib/init.sh, lib/upgrade.sh]
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
created: 2026-09-01T19:51:04Z
last_update: 2026-09-01T20:53:50Z
date_finished: 2026-09-01T20:53:50Z
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
  - ts: '2026-09-01T20:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 1
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=1 
      (workflow:test); effort=8 (lines=262,acs=8)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-01T20:00:24Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3246: arc-012 E9 — the loop does WORK: close a task, trip, restart, close another

## Context

Every prior arc-012 evidence leg measured the loop's **engine**. E8's restart fired
on a session that read four files and exited — it closed no task and advanced no
backlog. This asks the only question the arc's headline actually makes: does the
loop **close a task, trip, restart, and close another**?

### State at 2026-09-01 handover — two runs, one fix, one tuning gap

**Run 1 (pre-fix): 1/4 PASS.** Restart fired; zero tasks closed. Cause localised to
`bin/claude-fw:551` — `CLAUDE_ARGS=()` relaunched a headless `--print` session with
no prompt, so it exited on "Input must be provided" before doing anything. Filed
and fixed as **T-3247** (committed 7326394d5). This error was visible in E5, E7, E8
and E9 and was read as expected T-3166 behaviour each time, because the wrapper's
banner reports a successful auto-restart one line above it.

**Run 2 (post-fix): 1/4 PASS, but the mechanism now works.** Restarts 1 → 3, each
relaunching a live session that does real work. One task closed. The remaining
failure is **the harness dial, not the loop**, and the number is the useful finding:

| trip | tokens | critical | headroom |
|---|---|---|---|
| initial | 58284 | 55100 | — |
| restart 1 | 61980 | 55100 | ~2.5k |
| restart 2 | 62299 | 55100 | ~2.5k |

A sandbox session baselines near **52.6k tokens** before doing anything (CLAUDE.md,
hooks, handover). So:

> **useful work per iteration = WINDOW − BASELINE, not WINDOW** — and every restart
> re-pays the baseline in full. A fresh session is fresh in both directions: it
> drops the context it could not afford *and* the orientation it had already bought.

At a 58000 window that leaves ~4% to work in, so the loop cycles correctly and
progresses barely. In production the same arithmetic is comfortable (300k window,
~50k baseline, ~4.7× headroom) — but **nothing in the framework measures or reports
this ratio**, and it is what decides whether an armed loop makes progress or merely
spins. Worth its own task.

### Next step (harness edit was blocked by this session hitting critical)

Retune and re-run — the edit is prepared but unapplied:

- `WINDOW=58000` → **72000** (critical 68400, ~15.8k headroom)
- `MAXR=3` → **4**; backlog `for n in 1 2 3` → **1 2 3 4 5**; `--iterations 6` → **8**

Then `bash docs/reports/T-3239-continuous-loop-demo/livefire-loop-does-work.sh`.
Assertion 3 (`tasks closed after first restart ≥ 1`) is the arc's headline claim;
assertions 1 and 4 already pass.

### Run 3 (2026-09-01 22:2x) — the rig was measuring the wrong five tasks

Before the retune could be evaluated, the harness itself failed review. Four
setup steps had been failing silently behind `>/dev/null 2>&1` in **every** E9
run, this one included:

| # | step | failure | consequence |
|---|---|---|---|
| 1 | `fw task create` | called with only `--name`/`--type`; non-interactively also requires `--description` and `--owner` | created **nothing** |
| 2 | AC graft | globs `.tasks/active/T-*.md`; with no backlog that matched `fw init`'s T-001..T-005 | `item1..item5` grafted onto the **onboarding curriculum** |
| 3 | verification graft | anchors on `## RCA`, absent from the onboarding template | **no task in any run ever carried a verification line** — the close gate had nothing to run |
| 4 | baseline commit | `git commit -m "baseline: ..."` carries no `T-XXX` | rejected by `fw init`'s own commit-msg hook |

None of it surfaced because `BACKLOG=$(ls .tasks/active/T-*.md | wc -l)` returned
5 either way. The header line `backlog: 5 real tasks` was **true of the wrong
five**. This is the same false-green shape the framework already documents for
the port-3000 class: a check that answers the question *next to* the one it
appears to answer, and so is never the thing that prompts anyone to look.

**What this retracts.** Two claims in the Run-2 write-up above do not survive:

- the "1 task closed" was an **onboarding task**, not a backlog item;
- the retune's backlog widening 3 → 5 was a **no-op** — the population was the
  same five onboarding tasks in both runs, because `for n in 1 2 3` never
  produced anything either way.

The Run-2 *headroom* finding is unaffected: the token/critical/headroom table was
read from the ledger and the wrapper transcript, neither of which depends on
which tasks were in the backlog. That finding stands and is filed as **T-3248**.

**Fixed here**, in `docs/reports/T-3239-continuous-loop-demo/livefire-loop-does-work.sh`:
every setup step is fail-loud and aborts; the population is asserted **by name**,
not by count; `fw init`'s onboarding tasks are removed (T-005 *"Generate first
session handover"* would otherwise exercise the very restart machinery under
test); the verdict counts only E9 tasks and only artefacts with **correct
content**, not files that merely exist. `SETUP_ONLY=1` added so the rig can be
checked in a minute rather than 30 — which is precisely why this hid for so long.

**Positive control (L-653), before trusting any result** —
`evidence/E9-positive-control.txt`. The close gate was driven in all three
directions on a real sandbox task:

| control | state | outcome |
|---|---|---|
| 1 | AC ticked `[x]`, artefact **absent** | `FAIL: grep -qx 'done1' item1.txt (exit 2)` → **refused** |
| 2 | artefact present, **wrong** content (`done9`) | `FAIL ... (exit 1)` → **refused** |
| 3 | artefact present, **correct** content (`done1`) | `PASS`, `started-work → work-completed`, moved to `completed/` |

Control 1 is the one that matters: **ticking the box is not sufficient.** A close
in the live run is therefore evidence that the loop did the work, not evidence
that it edited a checkbox — which is what AC #4 asks for and what no prior E9 run
could actually support.

**Process note.** While inspecting, I read a *stale* sandbox as if it were the
live run — `KEEP_SANDBOX=1` accumulates sandboxes under `/tmp/tmp.*/proj` and a
`head -1` glob returns the **oldest**. Caught from the ledger timestamps; the
harness header now warns about it.

### Run 4 (2026-09-01 20:41-20:49) — 4/4. The loop closes a task, trips, restarts, closes another.

`evidence/E9-loop-does-work.txt`. Dials `FW_CONTEXT_WINDOW=72000` (critical
68400), `N_BACKLOG=12`, `MAX_RESTARTS=4`. Backlog asserted by name at setup:
*"backlog OK: 12 E9 tasks, each with a tickable AC and a verification line"*.

| assertion | result | figure |
|---|---|---|
| the budget trip produced a real restart | **PASS** | 3 `iterate/restart` events |
| the loop closed at least two real tasks | **PASS** | 12 E9 tasks in `completed/` |
| **WORK CONTINUED ACROSS THE RESTART** | **PASS** | **7 tasks closed after the first restart** |
| the closes were real work, not bookkeeping | **PASS** | 12 artefacts with correct content, 0 wrong |

**The join, mechanically.** Restarts fired at `20:44:57`, `20:46:51`, `20:49:20`,
each carrying a token count above the 68400 critical (`tokens=69246`, `70134`,
`74354`). Task `date_finished` values:

- **before** the first restart: T-006 `20:43:48` … T-010 `20:44:43` — five tasks
- **after** it: T-011 `20:45:26` … T-016 `20:46:44`, then T-017 `20:47:31` — **seven**

Nothing here is read off a transcript or asserted from narrative: the restart
timestamps come from `continuous-run.jsonl` and the close times from task
frontmatter, joined by the verdict script. T-018 (a task the loop created for
itself) was correctly excluded as non-E9.

**The prediction held.** The trip landed after task 5 of 12 — exactly where the
run-3 measurement (~2926 tokens/task against 15559 of headroom → 5.3 tasks per
window) said it would. Sizing the backlog from a measured per-task cost, rather
than nudging a dial, is what turned 2/4 into 4/4.

### What this settles, and what it does not

**Settles (E9's question):** the wrapper-level loop does real, gated work across
a context boundary. Not the engine turning over — the car moving. Every one of
the 12 closes passed the P-011 verification gate, and the positive control shows
a tick alone is refused, so "closed" here means the work was done.

**Does not settle (the arc):** three things stand between this and arc closure,
and none of them are affected by this result.

1. **It took three non-default dials.** `FW_CONTEXT_WINDOW`, `FW_BUDGET_STATUS_MAX_AGE`
   and `FW_BUDGET_RECHECK_INTERVAL` were all overridden. On stock settings the
   trip does not fire on a session this short — that is **T-3241**'s territory,
   and E7 remains the live negative.
2. **M1 still caps at one continuation** (**T-3240**): the Stop-hook loop yields
   to `stop_hook_active` before any of our own caps. The arc's headline sentence
   bundles M1 and M2; only M2 ships. The arc YAML already records this.
3. **The headroom ratio is unmeasured** (**T-3248**). This run needed two attempts
   precisely because nothing reports `WINDOW - BASELINE`. A green result obtained
   by hand-tuning a ratio the framework cannot see is not a green result the
   operator can rely on.

Per §Arc Completion Discipline the arc stays **OPEN**, and the demo artefact
below is offered as evidence for M2 only.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A live-fire harness drives a real `claude` under real `bin/claude-fw` against a sandbox holding a **real backlog** (tasks created through `fw task create`, each with a tickable AC and a verification line the close gate actually runs) — not a session that merely reads files and exits, which is what every prior arc-012 evidence leg did.
- [x] **The budget trip fires mid-backlog and the wrapper restarts** — at least one `event=iterate reason=restart` in `continuous-run.jsonl`, carrying a real token count above the configured critical threshold.
- [x] **Work continues across the restart — the deliverable.** At least one task's `date_finished` is later than the first restart event's timestamp, joined mechanically from the task frontmatter and the loop ledger rather than asserted from the transcript. This is the claim the arc's headline mechanic actually makes and the one nothing has yet tested.
- [x] **The closes are real work, not bookkeeping** — each closed task's named artefact file exists with the exact required content, so a task cannot be counted as closed by moving a file alone.
- [x] The result is reported honestly whichever way it lands, with any blocker localised to a named file and line and either fixed here or filed as its own task. A negative result names the positive control that would have fired (L-653), so "the loop did not work" is never confused with "the harness could not have seen it work".
- [x] Evidence committed under `docs/reports/T-3239-continuous-loop-demo/` (raw ledger, task-close join, wrapper transcript) and re-readable by someone who did not run it.

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


# E9 landed 4/4 against a real backlog.
grep -q "PASS: 4  FAIL: 0" docs/reports/T-3239-continuous-loop-demo/evidence/E9-loop-does-work.txt
# The deliverable assertion specifically — work continued across the restart.
grep -qE "PASS  WORK CONTINUED ACROSS THE RESTART .* = [1-9]" docs/reports/T-3239-continuous-loop-demo/evidence/E9-loop-does-work.txt
# Real work, not bookkeeping: artefact content checked, none wrong.
grep -q "artefacts with CORRECT content = 12 (wrong = 0)" docs/reports/T-3239-continuous-loop-demo/evidence/E9-loop-does-work.txt
# The rig is only trustworthy because the positive control fires (L-653).
test -f docs/reports/T-3239-continuous-loop-demo/evidence/E9-positive-control.txt
grep -q "gate moves in all three directions" docs/reports/T-3239-continuous-loop-demo/evidence/E9-positive-control.txt
# The calibration that sized the backlog is preserved, not just its conclusion.
grep -q "MISSED THE TRIP BY" docs/reports/T-3239-continuous-loop-demo/evidence/E9-run3-calibration.txt
# The harness still parses after the rewrite.
bash -n docs/reports/T-3239-continuous-loop-demo/livefire-loop-does-work.sh

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

**Recommendation:** GO — E9 is answered. Do **not** close arc-012 on it.

**Rationale.** The arc's headline mechanic promises the operator a multi-cycle
continuous session, and the point of a cycle is the work in it. E9 asked the only
question that tests that, and the answer is now demonstrated rather than asserted:
the loop closed 12 real tasks through the real verification gate across 3 real
budget trips, with **7 of them closed after the first restart**, joined
mechanically from the loop ledger and task frontmatter. Every prior E9 leg
measured the engine; this one measures the car moving.

The result is trustworthy in a way the earlier ones were not, and that is the
substance of this task rather than a footnote. The rig was found to be measuring
`fw init`'s onboarding curriculum instead of a real backlog — four setup steps
failing silently — which means the earlier "1 task closed" was an onboarding task
and no run had ever carried a live verification line. That is fixed, and the fix
is *proved* by a positive control driving the close gate in all three directions
(tick-only → refused, wrong content → refused, correct content → closes). Without
that control this 4/4 would be a number, not evidence.

**Why NOT to close the arc on this.** Three things stand, none touched by this run:

1. It required three **non-default dials** (`FW_CONTEXT_WINDOW`,
   `FW_BUDGET_STATUS_MAX_AGE`, `FW_BUDGET_RECHECK_INTERVAL`). On stock settings the
   trip does not fire — T-3241, with E7 as the live negative.
2. **M1 still caps at one continuation** (T-3240). The headline sentence bundles
   M1 and M2; only M2 ships.
3. The **headroom ratio is unmeasured** (T-3248). This run took two attempts
   *because* nothing reports `WINDOW - BASELINE`. A green obtained by hand-tuning
   a ratio the framework cannot see is not a green the operator can rely on.

Per §Arc Completion Discipline, and given the arc's existing default-to-OPEN
note, the demo artefact below is offered as evidence for **M2 only**.

**Evidence.**
- `docs/reports/T-3239-continuous-loop-demo/evidence/E9-loop-does-work.txt` — 4/4; ledger, join, wrapper transcript
- `docs/reports/T-3239-continuous-loop-demo/evidence/E9-positive-control.txt` — the control that makes the above readable as evidence
- `docs/reports/T-3239-continuous-loop-demo/evidence/E9-run3-calibration.txt` — the 2/4 run and the measurement (~2926 tok/task) that sized the fix
- Restart events `20:44:57 / 20:46:51 / 20:49:20` at `tokens=69246 / 70134 / 74354`, all above the 68400 critical
- Closes after the first restart: T-011 … T-017 (7)

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

### 2026-09-01T19:51:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3246-arc-012-e9--the-loop-does-work-close-a-t.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6469cc10
- **Timestamp:** 2026-09-01T20:53:52Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-01T20:53:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
