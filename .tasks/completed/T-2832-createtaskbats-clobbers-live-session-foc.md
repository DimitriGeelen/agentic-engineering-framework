---
id: T-2832
name: "create_task.bats clobbers live session focus via half-isolated sandbox"
description: >
  create_task.bats clobbers live session focus via half-isolated sandbox

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [tests/unit/create_task.bats]
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
created: 2026-08-06T16:15:36Z
last_update: 2026-08-06T16:34:23Z
date_finished: 2026-08-06T16:34:23Z
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
  - ts: '2026-08-06T16:30:06Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-06T16:30:11Z'
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

# T-2832: create_task.bats clobbers live session focus via half-isolated sandbox

## Context

Running `bats tests/unit/create_task.bats` from inside a live session **denies service to
that session**. Its `setup()` exports `PROJECT_ROOT="$FRAMEWORK_ROOT"` — the real repo —
while sandboxing only `TASKS_DIR`. Tasks are therefore created in the sandbox, where the
first allocated id is `T-001`, but `create-task.sh --start` sets focus via
`agents/context/lib/focus.sh`, which writes `$CONTEXT_DIR/working/focus.yaml` — and
`CONTEXT_DIR` was never redirected, so it resolves to the **live** `.context/`.

The live session is then focused on `T-001`, which does not exist in the live `active/`,
and the `check-active-task` PreToolUse hook refuses **every subsequent Bash call** with
"Task T-001 is not active". Recovery requires knowing to run `fw context focus T-XXX` by
hand.

Hit live this session: after a routine 8-suite regression run, every Bash call started
failing. Bisected across the 8 suites — only `create_task.bats` leaks.

Family: L-404 is the same half-isolated-sandbox shape in the **read** direction (test
walks the real `.tasks/`); T-2807 is bats dirtying the live tree via concurrency. This is
the **write** direction, and it is the worst of the three because the damage lands on
session-control state rather than on a data file — the symptom is not a wrong test result
but a session that can no longer run commands.

## Acceptance Criteria

### Agent
- [x] `tests/unit/create_task.bats` sandboxes `CONTEXT_DIR` so no test in it can write the
      live `.context/working/focus.yaml`.
- [x] A hermeticity pin test in that suite fails if the isolation is ever removed —
      sibling to the existing `T-100185: setup strips inherited CLAUDECODE` pin, matching
      the file's own established convention.
- [x] Measured proof: live `focus.yaml` is byte-identical before and after a full run of
      the suite, asserted by a test rather than by hand.
- [x] Sweep: every other `tests/unit/*.bats` that points `PROJECT_ROOT` at the real repo
      and can trigger a focus write is either already isolated or fixed in this task —
      with the measured count recorded in `## Decisions`.
- [x] Mutation-checked: removing the `CONTEXT_DIR` export turns the pin red.

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

# -F (fixed string): the pattern contains a literal `$`, which grep's BRE reads as an
# anchor and never matches. Fails loud at the gate rather than false-greening, but wrong.
grep -qF 'export CONTEXT_DIR="$TEST_DIR/.context"' tests/unit/create_task.bats
out=$(bats tests/unit/create_task.bats 2>&1); echo "$out" | grep -q '^ok 1 ' && ! echo "$out" | grep -q '^not ok'
# The gate itself is the end-to-end proof: this line runs the suite, and the live
# focus.yaml it compares against is the one this very session is focused through.
b=$(md5sum .context/working/focus.yaml | cut -d' ' -f1); bats tests/unit/create_task.bats >/dev/null 2>&1; a=$(md5sum .context/working/focus.yaml | cut -d' ' -f1); [ "$b" = "$a" ]

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

**Symptom:** after a routine regression run of 8 bats suites, every subsequent Bash call
in the live session was refused by the `check-active-task` hook with "BLOCKED: Task T-001
is not active". The session could not run commands until focus was restored by hand.

**Root cause:** `tests/unit/create_task.bats` sandboxed `TASKS_DIR` but not `CONTEXT_DIR`,
while deliberately pointing `PROJECT_ROOT` at the real repo. Task *files* went to the
sandbox — so the first id allocated was `T-001` — but `create-task.sh --start` calls
`context.sh focus`, which writes `$CONTEXT_DIR/working/focus.yaml`. Unset, that resolved
to the live `.context/`. The live session was left focused on a task that exists only in
a temp directory that `teardown()` then deleted.

**Why structurally allowed:** isolation was treated as a property of the data the suite
*asserts on* (tasks), not of everything the code under test *touches*. `--start` is one
flag, but it crosses from `.tasks/` into `.context/` — and nothing in the sandbox setup
reflects that crossing. The suite looked fully isolated to a reader, because the variable
that would reveal the gap is the one that isn't mentioned. Absence is not visible in a
setup block.

The failure is also silent at the point of damage: the suite passes, all 28 tests green,
and the harm lands on a *different* process. Nothing in the run's own output could ever
report it. It surfaces only later, as an unrelated-looking hook refusal.

**Prevention:** a two-part pin in the suite itself. The static half asserts `CONTEXT_DIR`
points inside the sandbox; the behavioural half hashes the **live** `focus.yaml`, runs a
real `--start`, and asserts the hash is unchanged — so it witnesses the actual bug rather
than a proxy for it, and would stay red if focus resolution moved to a different path.
Both go red under mutation. Sibling in form to the file's existing `T-100185` hermeticity
pin, which is the convention this file already established for exactly this class.

## Evolution

### 2026-08-06 — found by being the victim
- **What changed:** this bug was not looked for; it fired on me mid-task while I was
  verifying T-2830 and locked the session out of Bash. The diagnosis path started from a
  hook refusal naming a task ID I had never seen.
- **Plan impact:** none for T-2830 (already committed and pushed); this became its own
  task per one-bug-one-task.
- **Triggered:** OBS-181.

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

### 2026-08-06 — sweep measured by execution, not by grep

A static grep for suites that set `PROJECT_ROOT`, never set `CONTEXT_DIR`, and can reach a
focus write returned **8** candidates. Running each against a hashed live `focus.yaml`
returned **1** — `create_task.bats`. The other 7 either never actually reach `--start`,
or redirect focus by another route.

Recorded because the gap is the finding: the grep is a superset of the defect by 8:1, and
fixing all 8 "for safety" would have meant six unnecessary edits to suites that were
already correct, plus a false belief about how widespread the class is. Same shape as
T-2762 (grep 44, execution 6). The sweep AC is satisfied by the behavioural number.

### 2026-08-06 — fix the isolation, not the caller

- **Chose:** sandbox `CONTEXT_DIR` in `setup()`.
- **Why:** it is the smallest change that makes the suite's isolation match what the code
  under test actually touches, and it leaves `PROJECT_ROOT="$FRAMEWORK_ROOT"` intact —
  that line is load-bearing for template resolution.
- **Rejected:** dropping `--start` from the tests (would delete real coverage of the
  start path); snapshot-and-restore `focus.yaml` in `setup`/`teardown` (restores the file
  but still writes it, so a crashed or interrupted run still leaves the live session
  broken — treats the symptom); a global guard in `test_helper` (not every suite loads
  it, so it would give coverage that looks total and isn't).

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-08-06T16:15:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2832-createtaskbats-clobbers-live-session-foc.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ca23dc35
- **Timestamp:** 2026-08-06T16:34:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-08-06T16:34:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
