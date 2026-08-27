---
id: T-3200
name: "the continuous-run halt has no Watchtower control — the only brake needs shell
  access"
description: >
  Verified while disposing T-3181 IW-2: 'grep -rln halt web/blueprints/ web/templates/'
  returns nothing. The halt mechanism is a file (.continuous-halt, read by agents/context/stop-driver.sh:80-82
  as Brake 1 ahead of every other vote), and being a file is exactly why it is trustworthy
  — it is written from a shell the model does not mediate, so a misbehaving model
  cannot suppress it. But it is also the ONLY affordance: an operator watching a runaway
  loop from a phone, or from anywhere without a shell on this host, has no brake at
  all. Sovereignty says the human can override anything; today that override is gated
  on SSH. Proposed: a POST control on Watchtower that writes the same halt file, so
  the file stays the single mechanism (no second code path, no new precedence question
  for stop-driver.sh to resolve) and the web surface is only a second way to write
  it. Note the security shape before building: an unauthenticated halt endpoint is
  a denial-of-service on your own agent, so it needs whatever auth the rest of Watchtower's
  mutating routes use.

status: started-work
workflow_type: build
owner: agent
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
created: 2026-08-27T11:17:12Z
last_update: 2026-08-27T12:51:36Z
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
  - ts: '2026-08-27T11:30:09Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=202,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-27T11:30:17Z'
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

# T-3200: the continuous-run halt has no Watchtower control — the only brake needs shell access

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] A Watchtower POST route writes the SAME halt file `stop-driver.sh` already reads (`.context/working/.continuous-halt`, `FW_CONTINUOUS_HALT`-overridable) — no second mechanism, no new precedence question for the driver to resolve
- [x] The route resolves the halt path from the same env-var-then-default rule as `stop-driver.sh:60`, so an operator who has overridden `FW_CONTINUOUS_HALT` does not get a button that writes a file nothing reads
- [x] A matching resume route clears the halt, so the operator who stopped the loop from a phone can also start it again from one — a brake with no release is a brake nobody dares use
- [x] The `/approvals` page shows current halt state (halted / running) and the button, since that is where operator actions already live
- [x] State-changing requests go through Watchtower's existing CSRF layer (`web/app.py:130` `before_request`) rather than inventing an auth story for one endpoint
- [x] End-to-end proof, not route-existence proof: POST halt → the file exists at the path `stop-driver.sh` reads → `stop-driver.sh` actually yields on it → POST resume → the file is gone → the driver stops yielding. Asserted against the driver's real exit behaviour, not against the HTTP status
- [x] Control leg: the driver still yields for a halt file created by plain `touch`, so adding the web writer has not made the shell path conditional on it
- [x] `curl -sf` against a live Watchtower confirms the rendered page carries the control (guards against the OBS-349 class, where a stale server serves code the change never reached)

### Human

- [ ] [REVIEW] The halt control is findable and unmistakable under pressure

  **Steps:**
  1. Open `http://192.168.10.107:3000/approvals` on a phone (or narrow the browser to phone width).
  2. Without scrolling past other sections, find the continuous-run halt control.
  3. Read the current state. Press the button. Read the state again.

  **Expected:** You can tell at a glance whether the loop is halted or running,
  the button says which way it will move things, and pressing it visibly changes
  the state. It should be usable by someone who is worried, on a small screen,
  without reading documentation.

  **If not:** Say which of the three failed — findability, legibility of state,
  or feedback after pressing. This AC is human because the question is whether
  it works for a person under pressure, which no curl can answer.


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

python3 -c "import ast;ast.parse(open('web/blueprints/approvals.py').read())"
python3 -m pytest tests/unit/test_continuous_halt_control.py -q > /tmp/.t3200.out 2>&1 && grep -q "8 passed" /tmp/.t3200.out && ! grep -q failed /tmp/.t3200.out
curl -sf "$(bin/fw watchtower url)/approvals" -o /tmp/.t3200page.html && grep -q "continuous-halt" /tmp/.t3200page.html
curl -sf "$(bin/fw watchtower url)/approvals" -o /tmp/.t3200page.html && grep -qE "RUNNING|HALTED" /tmp/.t3200page.html
grep -q "FW_CONTINUOUS_HALT" web/blueprints/approvals.py
grep -q "FW_CONTINUOUS_HALT" agents/context/stop-driver.sh

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

**Recommendation:** GO

**Rationale:** The brake is now reachable from any browser on the LAN, and the
mechanism did not change — Watchtower is a second *writer* of the one halt file,
never a second brake, so `stop-driver.sh` keeps exactly one thing to check and
there is no new precedence question. The shell path is untouched and pinned by a
control test. What remains is a judgment no command can make: whether the control
is findable and legible to a worried person on a phone.

**Evidence:**
- Eight tests drive the **real** `stop-driver.sh` as a subprocess and assert on
  its exit behaviour and logged reason, not on HTTP status — a route that writes
  the wrong path returns 200 just as readily as one that writes the right path.
- Mutation-verified rather than assumed: writing a parallel file kills 2 tests,
  ignoring `FW_CONTINUOUS_HALT` kills 1, a no-op resume kills 2, removing the
  release affordance kills 1.
- **The first cut of the suite was inert for the central claim.** It passed all
  seven tests while the route wrote a *parallel* file, because the fixture had
  pointed `FW_CONTINUOUS_HALT` at the same path as the default and so could not
  distinguish the two branches. Rewritten with deliberately divergent paths; the
  mutants die now. Recorded because the green suite looked identical before and
  after.
- CSRF: both routes sit behind Watchtower's existing `before_request` guard with
  no exemption; unauthenticated POST returns 403 and does not move the brake.
- Live-server check against a **restarted** Watchtower (OBS-349 class): the
  rendered `/approvals` carries the control and reads `RUNNING`.
- Security shape, as flagged at filing: the endpoint is fail-safe in the
  direction that matters. The worst an unauthorised caller achieves is *stopping*
  your agent — strictly less dangerous than `/api/approvals/decide`, which
  already runs on this posture.

**Residual, not claimed as done:** there is still no `fw` verb for the halt.
`grep` over `bin/fw` finds nothing, so on a shell the brake is still bare
`touch`. Out of scope here (this task is the Watchtower control) and deliberately
not filed — it is one line of the same file and belongs to whoever next touches
continuous-mode's CLI surface.

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

### 2026-08-27T11:17:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3200-the-continuous-run-halt-has-no-watchtowe.md
- **Context:** Initial task creation

### 2026-08-27T12:51:36Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
