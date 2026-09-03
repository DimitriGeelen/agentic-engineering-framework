---
id: T-3254
name: "arc-012: drive the loop from OUTSIDE when the agent stops early - cron reads
  status, injects a turn"
description: >
  The loop gives up whenever the agent stops without tripping the budget gauge: three
  'exit no-signal' entries in the live ledger. M1 (in-session Stop-hook continuation)
  is structurally capped at one turn by the platform runaway guard, and M2 only fires
  at budget-critical. This ships the third path: an external cron reads the continuous-mode
  status file and injects a turn into an idle registered session when the armed conditions
  hold. An injected prompt is a new user turn, not a hook-driven continuation, so
  stop_hook_active never applies - and cron is wall-clock rate-limited by construction,
  so the runaway ceiling is structural rather than a counter we must get right. Depends
  on T-3253: the brakes must actually stop things before the default flips from stop-on-silence
  to continue-unless-done.

status: started-work
workflow_type: build
owner: agent
horizon: now
arc_id: continuous-run
tags: []
components: []
related_tasks: [T-3253, T-3240, T-3239, T-3243]
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
created: 2026-09-03T08:56:16Z
last_update: 2026-09-03T10:10:59Z
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
  - ts: '2026-09-03T09:00:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=351,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-03T09:00:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      Discard fidelity: 0
      Loop closure (conditional): 0
      D1: 4
      D2: 2
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: Discard fidelity=0 (no-signal); Loop closure (conditional)=0 
      (no-signal); D1=4 (body:structural-gate); D2=2 
      (body:telemetry-or-audit-entry); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=1 (body/components:prompt-incidental); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-3254: arc-012: drive the loop from OUTSIDE when the agent stops early - cron reads status, injects a turn

## Context

### The hole

The live ledger (`.context/working/continuous-run.jsonl`) records eleven real
restarts between 2026-08-29 and 2026-09-02 — and, alongside them, three of these:

```
exit  no-signal  claude exited without a restart signal
```

Three times the loop simply ended. Not because the backlog was empty, but because
the agent stopped before filling 285K tokens of context. **Continuity currently
depends on the agent being wasteful enough to hit the wall**, which is exactly
backwards.

### Why neither existing mechanism covers it

- **M1** (Stop-hook in-session continuation) is capped at exactly one turn.
  `stop-driver.sh:98` honours Claude Code's `stop_hook_active` ahead of every cap
  we own (`:170+`), and that flag is set on any stop following a hook-driven
  continuation. Measured in E2. Widening it is a sovereignty call — T-3240.
- **M2** (budget compact-resume) only fires at budget-critical. It is proven and
  in production, but it is the wrong trigger for "the agent stopped early".

### The third path — and why it is not M1 by other means

An **injected** prompt is a *new user turn*, not a hook-driven continuation.
`stop_hook_active` is therefore never set by it, so this does not fight the vendor
guard, disable it, or depend on it changing. It is also the mechanism CLAUDE.md
already sanctions for this shape (§Cross-Agent Communication Protocol: "If you
need a response, use `inject`").

**The safety argument is structural, not a counter.** A hook loop can re-drive
itself at machine speed; a cron driver injects at most once per tick, bounded by
wall clock. The runaway ceiling is a property of the scheduler rather than of
logic we have to get right — which is a materially stronger guarantee than
anything M1 could offer.

### The honest cost

Going *around* the guard means **we own the bounding entirely**. That is the same
sovereignty exposure T-3240 names, reached by a different road: it relocates the
decision rather than dissolving it. The mitigation is that this driver reads the
same four bounds the SessionStart path reads, and refuses to inject when any of
them says stop.

### Prerequisite — T-3253, and it is not optional

This flips the default from *stop on silence* to *continue unless told done*.
That is the dangerous direction, and it is only safe once the brakes are real.
Today they are not: the tier ceiling records a breach, freezes the counter and
disarms the state file, and the session closes the over-ceiling task anyway four
and a half minutes later (E10, T-3250). `max_iterations` has the identical hole.
**Do not build this before T-3253 lands.**

### Design sketch (not settled — record decisions in ## Decisions)

1. Cron entry reads `.continuous-mode.yaml` + the ledger.
2. Injects only when ALL hold: `enabled: true`; not expired; `current_iteration`
   under `max_iterations`; `tasks_completed` under `max_tasks`; no
   `last_terminated_reason`; ceiling not breached; target session registered and
   **idle** (never `busy` — injecting into a working session interleaves input).
3. Injection via TermLink (`termlink inject --enter` / `termlink_inject`) against
   the session tagged for this project.
4. Every injection appends to the ledger, so the driver is as observable as the
   wrapper path and the two can be read as one history.
5. An explicit terminal signal from the agent ("work complete") disarms — so that
   silence stops meaning two different things, which is the class this whole arc
   keeps tripping over.

## Progress — 2026-09-03 (session hit budget critical mid-task)

**Prerequisite cleared.** T-3253 closed with all five ACs green and live-fire
evidence on both legs (breach 7/0, control 6/0). The build-order gate in
`## Verification` (`ls .tasks/completed/T-3253-*.md`) passes.

**Shipped and committed (`3ee3a88ac`):**

1. **`fw continuous status --json`** (`lib/continuous-mode.sh`). The same
   `verdict()` the text form prints, in machine-readable shape, plus the two
   conditions `verdict()` does not reach — `terminated` and `ceiling_breached`.
   This is the whole mitigation for going around the vendor guard: the driver
   refuses on exactly the bounds the SessionStart path refuses on and **does not
   re-type them**. If the bounds change they change in one place.
   - An unresolvable blast radius is NOT a breach (the enforcer's own
     `is not None` semantics) and is reported as `null`, so it stays
     distinguishable from a measured zero.
   - A ceiling check that *throws* becomes a blocker, never a green light. "No
     breach" and "could not evaluate" must not collapse into each other.
2. **`agents/context/continuous-driver.sh`** — reads that verdict, resolves the
   target session, observes busy, injects, and writes a typed ledger entry for
   **every** decision including refusals.

**Verified live:** run against this repo's real (disarmed, lapsed) state it
refused and logged all three actual blockers in the wrapper's own ledger schema,
so both paths read as one history:

```
{"event": "drive", "reason": "refused", "detail": "bounds say stop:
 enabled=False (not armed); recorded termination: expires_at 2026-06-17 passed;
 expires_at 2026-06-17T00:00:00Z lapsed"}
```

**The finding that shaped the busy check, recorded so it is not "simplified"
later.** The design sketch says to inject only into a session that is not `busy`.
**TermLink has no such state.** `termlink discover --json` reports
`state: "ready"` for every registered session — measured, 127 of 127 on this
host, including sessions mid-work. `ready` means REGISTERED, not IDLE. Gating on
that field would inject into a working session and interleave input, which is the
exact failure the condition exists to prevent.

So busy is **observed, not read**: sample the pty twice `--settle` seconds apart
and treat any change as "this session is producing output". That is an
observation of session state, which is what AC3 asks for, and it is testable in
both directions. It is deliberately biased: a session thinking *silently* can look
quiet, so this may occasionally inject one interleaved prompt. The opposite bias —
requiring proof of idleness — never injects at all.

Related measurement, in case it is assumed later: all 72 sessions tagged to this
project have **live PIDs and heartbeats under 120s**. They are real idle shells,
not stale registrations, so liveness is not the discriminator here — only
activity is.

**Remaining (none started):**

- AC2/AC3 tests — six refusal conditions, one test per condition, each with a
  passing control, plus the busy/quiet pair. The `--json` evaluator is the unit
  under test for the six; the driver is the unit under test for busy.
- AC4 is already satisfied in code (every path calls `_log`) but is untested.
- Cron registry entry + `fw cron generate` + `fw cron install`, and the two-clause
  doctor check already written into `## Verification`.
- Live-fire (AC5) and its negative control (AC6) — a sandbox session that stops
  early with backlog remaining, driven to completion by the cron path alone with
  the budget gauge never tripping; then the identical run with `enabled: false`
  which must NOT be injected into.
- `bin/fw fabric register agents/context/continuous-driver.sh`, and
  `bin/fw vendor self` (both `lib/` and `agents/` are vendored paths — the sync
  must happen BEFORE close, per CLAUDE.md §Vendored-path-touching tasks).

**Do not skip the negative control.** Without it, "the driver continued the work"
and "the agent finished on its own" read identically — the same
indistinguishability that made E9's ceiling result meaningless.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] T-3253 is closed before any injection path is wired — verified by the task
      being in `.tasks/completed/`. This is a build-order gate, not a courtesy.
- [x] The driver refuses to inject on every one of the six armed conditions, one
      test per condition, each with a passing control so a refusal that fires for
      the wrong reason is distinguishable from one that fires for the right one.
- [x] The driver refuses to inject into a `busy` session, and the test proves it
      by observing the session state rather than by asserting the refusal message.
- [x] Every injection and every refusal appends a typed entry to
      `.context/working/continuous-run.jsonl`, so a reader can reconstruct why the
      loop did or did not continue at each tick without re-running anything.
- [x] Live-fire: a sandbox session that stops early with backlog remaining is
      driven to completion by the cron path alone, with the budget gauge never
      tripping — proving this covers the `no-signal` case M2 cannot reach.
- [x] Negative control for the live-fire: the identical run with `enabled: false`
      is NOT injected into and stays stopped. Without this leg, "the driver
      continued the work" and "the agent finished on its own" read identically.
- [x] Cron registry → generated → deployed is in sync (see `## Verification`).

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

# --- T-3254 gate ---
# Build-order gate. T-3253 makes the brakes actually stop things; this task flips the
# default from stop-on-silence to continue-unless-done. Wiring an injection path before
# the brakes bind is the one sequencing error that turns a bug in our logic into an
# unattended runaway, so it is asserted mechanically rather than remembered.
ls .tasks/completed/T-3253-*.md >/dev/null 2>&1
# Cron chain: registry -> generated -> deployed (L-364, T-1771, T-1942, T-1943). This
# task adds a cron entry, so BOTH clauses are required - the in-sync line alone still
# fires when the registry was edited and never regenerated.
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"
# The refusal suite. Two lines because they answer different questions: "did anything
# fail" and "did everything run" — a bats skip reports as `ok` (T-3217), and the six
# armed conditions are exactly the kind of thing that would skip silently.
timeout 600 bats tests/unit/t3254_driver_refusals.bats > /tmp/.t3254.out 2>&1 && ! grep -q "^not ok" /tmp/.t3254.out
test "$(grep -c '# skip' /tmp/.t3254.out)" -eq 0
# Vendored paths: this task edits lib/ and agents/, both vendored. Sync BEFORE close
# (OBS-250) — after close there is no task the sync can run under.
# Live-fire (AC5) + negative control (AC6). Spawns a real PTY-backed TermLink
# session and drives it with the real driver; ~90s. The negative control is inside
# the same script deliberately — the two legs are only meaningful together.
timeout 500 tools/t3254-livefire.sh > /tmp/.t3254lf.out 2>&1 && grep -q "0 failed" /tmp/.t3254lf.out
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

### 2026-09-03 — three defects of one shape, all invisible from inside the repo

- **What changed:** Writing the refusal tests surfaced three defects in code that
  had already shipped and been reviewed, and all three are the same shape: *code
  that could only work in the environment it was written in, invisible to tests
  written in that same environment.*

  1. **The ceiling join imported the injector from `PROJECT_ROOT`.** That path
     exists in this repo — where the project and framework roots coincide — and
     nowhere else. On any consumer the import raised `FileNotFoundError`, which
     `_emit_json` correctly refuses to read as a green light, so `may_inject` was
     false forever. Fail-safe **and completely inert**: the mechanism could never
     fire outside the repo it was written in.
  2. **The registration check was `termlink info "$SESSION"`.** `termlink info`
     takes no positional target; it exits 2 with "unexpected argument" for every
     session. The driver would have refused every target it was pointed at, with
     the message "target session is not registered" — a plausible-sounding lie.
     It survived because the unit-test stub was written against the *driver's
     belief* about termlink rather than against termlink. Stub and driver agreed
     with each other; neither agreed with the tool.
  3. **A non-PTY session read as idle.** `pty output` errors and returns no bytes
     for a session registered without `--shell`; two empty samples compare equal,
     so the busy check saw perfect quiet and injected into something that cannot
     receive keystrokes. Every observable said "quiet" right up to the failure.

- **Plan impact:** None to the design — all three are implementation defects, and
  the design's own principle already covered the third ("could not evaluate is not
  a green light", written for the ceiling check but not applied to the pty check).
  What changed is the *evidence standard*: a stub is now treated as a claim about
  an interface that must itself be pinned against the real binary (test B4), not
  as a test fixture.

- **Triggered:** No new tasks. The three fixes, plus tests B4 (real-CLI contract)
  and B5 (false-quiet), landed inside this task because each is one edit and the
  suite that found them is this task's deliverable.

### 2026-09-03 — the busy check is an observation, and TermLink cannot help

- **What changed:** The design sketch says "never inject into a `busy` session".
  TermLink has no such state: `discover --json` reports `state: "ready"` for every
  registered session — 127 of 127 on this host, mid-work ones included. `ready`
  means REGISTERED, not IDLE.
- **Plan impact:** Busy is **observed, not read** — sample the pty twice `--settle`
  seconds apart, treat any change as output. Deliberately biased: a session
  thinking silently can look quiet, so this may occasionally interleave one prompt.
  The opposite bias never injects at all.
- **Triggered:** Nothing filed; the trade is recorded in the driver's header so it
  is not "simplified" away later.

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

### 2026-09-03T08:56:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3254-arc-012-drive-the-loop-from-outside-when.md
- **Context:** Initial task creation

### 2026-09-03T10:10:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
