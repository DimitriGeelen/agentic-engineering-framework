---
id: T-3253
name: "tier-ceiling breach disarms the loop but neither stops the running session
  nor the budget-restart path, which never consults enabled"
description: >
  tier-ceiling breach disarms the loop but neither stops the running session nor the
  budget-restart path, which never consults enabled

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
arc_id: continuous-run
components: [agents/context/inject-next-directive.py, bin/claude-fw, tests/unit/t3253_preflight_brake.bats]
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
created: 2026-09-01T22:47:09Z
last_update: 2026-09-03T10:10:17Z
date_finished: 2026-09-03T10:10:17Z
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
  - ts: '2026-09-01T23:00:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=319,acs=7)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-01T23:00:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      Discard fidelity: 0
      Loop closure (conditional): 0
      D1: 4
      D2: 0
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 1
    rationale: Discard fidelity=0 (no-signal); Loop closure (conditional)=0 
      (no-signal); D1=4 (body:structural-gate); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-3253: tier-ceiling breach disarms the loop but neither stops the running session nor the budget-restart path, which never consults enabled

## Context

Found by arc-012 E10 (T-3250), the experiment that first pressed the bounded-autonomy
brake. The ceiling **fires correctly** — that part is now evidenced. What it does not do
is stop the loop.

**Measured, one run, wall-clock from the run's own ledger and task frontmatter:**

```
22:38:49  start                 armed, MAX_RESTARTS=10, tier_ceiling=1
22:40:45  iterate restart #1    session tripped at 69309 tokens
22:40:55  BREACH                last_terminated_reason = "tier ceiling exceeded:
                                T-022 blast-radius 5 > tier_ceiling 1"
                                current_iteration frozen at 0, enabled -> false
22:42:29  iterate restart #2    <- after the disarm
22:43:38  iterate restart #3    <- after the disarm
22:44:59  backlog item 16 closed
22:45:21  T-022 CLOSED          the over-ceiling task, 4m26s after the brake
22:45:50  exit no-signal        clean exit; the re-arm correctly refused
```

**Two separate holes, one symptom.**

1. **The running session is not stopped.** The breach is evaluated in the SessionStart
   hook of the session that has *already been relaunched*, and the notice arrives as
   `additionalContext`. That session's actual prompt is still the armed directive
   ("work the backlog… do not stop until every task is closed"), so the notice is
   advisory text competing with an instruction. It lost.

2. **The budget-restart path never consults the disarm.** `bin/claude-fw:506` enters the
   restart branch on a fresh signal plus `MAX_RESTARTS` alone. `_continuous_armed`
   (`:354`, reads `enabled`) gates only the clean-exit **re-arm** branch at `:652`. So
   `enabled: false` suppresses re-arms and nothing else — which is exactly the two extra
   restarts above.

**The same hole is not specific to the ceiling.** The control leg of the same
experiment terminated on a different bound — `iteration 9 exceeds max_iterations 8`,
recorded at 22:51:30 with `enabled -> false` — and the wrapper restarted again at
22:53:08 regardless. So this is not "the tier ceiling is weak"; it is that **every
termination the injector records disarms the loop and nothing else**, because the
disarm is only read on the re-arm branch. The ceiling is simply the bound with the
sharpest consequence.

## Progress — 2026-09-03 (session hit budget critical mid-task)

**Hole 2 is CLOSED and committed** (`450a5952b`). `bin/claude-fw` gained
`_continuous_terminated()` and the restart branch consults it before spending
budget. Verified against four cases: absent state file → allow (the regression
guard), armed+running → allow, ceiling termination → refuse with reason,
`max_iterations` termination → refuse with reason.

**The trap that shaped the fix, recorded so it is not "simplified" later.** The
obvious spelling is `! _continuous_armed`. That is wrong: `_continuous_armed`
returns 1 on an *absent* state file, so gating the restart branch on it reads
"no continuous mode configured" as "do not restart" and **silently deletes
T-179 budget auto-restart for every user who never armed a run** — nearly all of
them. `_continuous_terminated` is the narrow predicate: it fires only when a
termination was actually written. `enabled: false` on a fresh file means "never
switched on"; a non-empty `last_terminated_reason` means "switched on, then
stopped for this reason". Only the second is a brake.

**Hole 1 (AC3) is NOT started.** The design settled on, with reasoning:

- Fix-2 alone does **not** satisfy AC3. The breach is recorded at SessionStart of
  a session that has *already launched* with the armed directive as its prompt.
  That session can still work the over-ceiling task; in the E10 run it happened
  not to, which is luck, not a guarantee.
- The mechanism chosen is a **pre-launch ceiling check**: the wrapper evaluates
  the planned next action *before* spending the restart, so the breaching session
  never launches. That is the only variant where the notice cannot be ignored,
  because there is nothing running to ignore it.
- **Single-writer constraint (T-3233 W1-F3).** The wrapper must NOT write
  `.continuous-mode.yaml` itself — `current_iteration` has exactly one writer and
  a second one reintroduces the class this arc keeps hitting. So the preflight
  must be a new mode ON the injector (`agents/context/inject-next-directive.py`,
  which already exposes `evaluate`, `resolve_task_blast_radius` and
  `find_task_reference` as importable functions), invoked earlier by the wrapper.
- **The preflight must not double-advance the counter.** On the non-breach path it
  evaluates and writes NOTHING, letting SessionStart do its normal single write.
  Only the breach path writes (terminate + disarm + frozen counter) and signals
  the wrapper to refuse. Getting this wrong advances `current_iteration` twice per
  restart, which would be invisible until someone counted.

**Remaining:** AC3 (above), then AC4 (re-run E10 breach leg — `AC4a`/`AC4b` must
pass and no `closed-AFTER-the-breach` attribution) and AC5 (control leg unchanged).
Both legs run via `LEG=breach|control bash
docs/reports/T-3239-continuous-loop-demo/livefire-brake-tier-ceiling.sh`, ~35 min
each, and they may run concurrently. **Run them from a copy** — editing the script
while a run executes it corrupts that run (bash reads scripts by byte offset).

That widens AC 1: the restart branch must consult the disarm, not consult a
ceiling-specific flag.

**What the ceiling therefore is, today:** a bound on how the loop *ends*, not on what it
*does*. It reliably prevents the loop from arming another cycle, and it reliably records
why. It does not prevent the over-ceiling work from being done in the cycle already
running — and that work is the entire reason an operator sets a ceiling.

The disarm-on-termination behaviour itself is correct and is T-3167's; nothing here
argues against it. The gap is that `enabled` is read in one of the two places that spend
autonomy.

**Why E10 could tell.** The assertion "the over-ceiling task was not closed" fails
identically whether the session ignored the brake or the rig was too small for the brake
to matter — and on the first run at `N_BACKLOG=8` it was the latter, wrongly. The rig
records each close's `date_finished` against the breach timestamp and prints the
attribution, so the two readings are separated mechanically rather than by inference.
Evidence: `docs/reports/T-3239-continuous-loop-demo/evidence/E10-brake-breach.txt`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A ceiling breach stops the budget-restart path too. `bin/claude-fw`'s restart branch consults the disarm before spending a restart, instead of being gated only by a fresh signal and `MAX_RESTARTS`.
- [x] The refusal is recorded as its own loop-event reason, distinct from `max-restarts` — an operator reading the ledger must be able to tell "stopped because the ceiling was breached" from "stopped because it was spinning".
- [x] The session that receives the breach notice is stopped rather than asked to stop. Whatever the mechanism, the acceptance is behavioural: with the ceiling breached, the over-ceiling task is not worked.
- [x] E10's breach leg is re-run and `AC4a`/`AC4b` pass with the attribution line reading `closed-AFTER-the-breach` nowhere — i.e. the escalation task is not closed at all. The same rig that found this is what closes it.
- [x] The control leg still passes unchanged: under the ceiling, the loop restarts, works the whole backlog including the escalation task, and never records a termination reason. A fix that stops the breach case by stopping every case is not a fix.

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

# --- T-3253 gate ---
# The preflight brake, every case against a control (11 tests). Two lines because
# they answer different questions: "did anything fail" and "did everything run" —
# a skipped bats test reports `ok` (T-3217).
timeout 300 bats tests/unit/t3253_preflight_brake.bats > /tmp/.t3253-bats.out 2>&1 && ! grep -q "^not ok" /tmp/.t3253-bats.out
test "$(grep -c '# skip' /tmp/.t3253-bats.out)" -eq 0
# Vendored paths touched (bin/, agents/). The live-fire sandbox is a real `fw init`
# project and runs the VENDORED injector, so an unsynced vendor makes the E10 legs
# green for the wrong reason — the preflight would simply not be found and fail open.
bin/fw vendor self --check

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


**Symptom:** The bounded-autonomy ceiling fired, recorded `tier ceiling exceeded:
T-022 blast-radius 5 > tier_ceiling 1`, froze the counter and disarmed the state
file at 22:40:55 — and the loop restarted twice more (22:42:29, 22:43:38) and
closed the over-ceiling task at 22:45:21, 4m26s after the brake. The control leg
lost `max_iterations` to the identical hole.

**Root cause:** Two places spend autonomy and only one of them read the disarm.
`enabled` was consulted on the clean-exit **re-arm** branch (`bin/claude-fw:652`,
via `_continuous_armed`) and nowhere on the **budget-restart** branch (`:506`),
which entered on a fresh signal plus `MAX_RESTARTS` alone. Separately, the ceiling
itself was evaluated in the SessionStart hook of a session that had *already
launched* carrying the armed directive as its prompt, so the breach arrived as
advisory `additionalContext` competing with "do not stop until every task is
closed" — and lost.

**Why structurally allowed:** Both halves are the same shape — a brake wired to
the wrong side of the thing it brakes. The disarm was written by the injector and
read by one consumer, so "recorded" and "enforced" were separate properties with
nothing asserting they matched. And a notice delivered *into* a running session
can only ever be advisory: the session's own prompt outranks it. Neither gap was
visible from the state file, which holds only the last value of
`current_iteration` — "the counter froze across the transition" is a claim about
two adjacent samples, and nothing sampled.

**Prevention:** `tests/unit/t3253_preflight_brake.bats` — 11 tests, every brake
case against a control, including the ordering invariant (the preflight must
precede `_restart_budget_take`, or a loop stopped by a BOUND gets reported as a
RATE limit) and the two regression controls that the fix could plausibly have
broken: the clear path must leave the state file byte-identical, and an absent
state file must stay absent. The E10 rig's per-close attribution line
(`closed-AFTER-the-breach` / `closed-BEFORE-the-breach`) is what separates "the
session ignored the brake" from "the rig was too small for the brake to matter" —
the two readings that were indistinguishable on the first run at N_BACKLOG=8.

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


### 2026-09-03 — the brake had to move before the launch, not into the session

- **What changed:** Closing hole 2 (the restart branch consulting the disarm) was
  necessary and not sufficient. The breach is discovered by the SessionStart hook
  of a session that has, by then, already launched with the armed directive as its
  prompt. In the E10 run that session happened not to work the over-ceiling task
  after the notice — luck, not a guarantee. A notice that has to win an argument
  with a running session is not a brake.
- **Plan impact:** AC3 could not be satisfied by any refinement of the notice's
  wording or delivery. The decision moved *before* the launch, where there is
  nothing running to ignore it. That made the wrapper the enforcement point and
  the injector the evaluator — a split the single-writer constraint then shaped.
- **Triggered:** `--preflight` mode on `inject-next-directive.py` rather than
  wrapper-side logic (T-3233 W1-F3: `current_iteration` has exactly one writer,
  and a second one reintroduces the class this arc keeps hitting). The wrapper
  reads only an exit code.

### 2026-09-03 — the clear path must write nothing, and that is not an optimisation

- **What changed:** `evaluate()` returns an *advanced* counter as a matter of
  course, and SessionStart is about to advance it again for the same restart.
  The obvious implementation — evaluate, write, then decide — double-advances
  every iteration.
- **Plan impact:** The preflight writes on the terminating path only, and that
  write carries a frozen counter. The non-breach path is byte-identical, pinned by
  a control test rather than left to review.
- **Triggered:** Nothing new filed; the constraint was already recorded in this
  task's Progress section before the build and held on contact.

### 2026-09-03 — the vendored copy is what the live-fire actually runs

- **What changed:** The E10 sandbox is a real `fw init` project, so it executes
  `.agentic-framework/agents/context/inject-next-directive.py`, not the source
  tree. An unsynced vendor would have made both legs green for the wrong reason:
  the preflight would not be found, `_continuous_preflight` fails open by design,
  and that is indistinguishable from a brake that held.
- **Plan impact:** `bin/fw vendor self --check` is in `## Verification` as a
  correctness gate for the evidence, not as vendored-path hygiene.
- **Triggered:** Sync run before the legs were launched, not after.

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

### 2026-09-01T22:47:09Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3253-tier-ceiling-breach-disarms-the-loop-but.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1392ea2c
- **Timestamp:** 2026-09-03T10:10:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-03T10:10:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
