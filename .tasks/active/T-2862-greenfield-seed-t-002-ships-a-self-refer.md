---
id: T-2862
name: "greenfield seed T-002 ships a self-referential AC that deadlocks fw inception
  decide in every new project"
description: >
  lib/seeds/tasks/greenfield/T-002-define-project-goals.md:38 carries the Agent AC
  'Go/no-go decision recorded: fw inception decide T-002 go --rationale ...' with
  no <!-- @auto-tick-on-decide --> marker. The decide preflight refuses while any
  agent AC is unchecked, but that AC IS the decision — it cannot be satisfied before
  the thing it gates. fw init seeds T-002 into every greenfield project, so the first
  inception a new user ever runs is un-completable by construction. Hit live by the
  operator in /opt/001-test-install: agent correctly refused the --i-am-human bypass
  and routed to fw task review; Watchtower then refused the GO with '1/3 agent AC
  unchecked'. The framework's own .tasks/templates/inception.md does NOT carry this
  AC and marks all three of its Agent ACs @auto-tick-on-decide. Fix: delete the tautological
  AC (preferred — an inception's decision is its terminal state, not a criterion)
  or add the marker. Sibling of T-2442 inception schema deadlock.

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
created: 2026-08-07T17:24:46Z
last_update: '2026-08-08T20:30:08Z'
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
  - ts: '2026-08-07T20:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-08T20:30:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-07T20:30:12Z'
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

# T-2862: greenfield seed T-002 ships a self-referential AC that deadlocks fw inception decide in every new project

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Context

`lib/seeds/tasks/greenfield/T-002-define-project-goals.md` ships an Agent AC that
names the very command it blocks. `fw init` seeds it into every greenfield project,
so the **first inception a new user ever runs cannot be completed** — the decide
preflight (`lib/inception.sh:521-534`) ticks `@auto-tick-on-decide` ACs, then counts
what remains unchecked; this AC carries no marker, so it survives the tick and
refuses the decide it describes.

Instance 1 of the five in T-2863 (GO recorded 2026-08-08). Hit live by the operator
in a fresh install; the agent correctly refused the `--i-am-human` bypass, which is
the sovereignty boundary working — the seed is what is wrong.

T-2863's F-17 adds a wrinkle the original report did not have: **DEFER skips the
preflight entirely** (`lib/inception.sh:521` guards it with `go || no-go`), so the
deadlock is escapable by hedging. That makes the greenfield experience worse, not
better — a new user's only exit from their first inception is the hedge the
framework's own prose forbids (T-2144). Fixing the seed removes the incentive.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The self-referential AC in the greenfield seed no longer deadlocks decide —
      **removed** as tautological, with the reason stated inline in the seed. Three
      independent grounds: it deadlocked, it asserted only what `## Decision` already
      records, and it instructed the agent to run a command agents are structurally
      forbidden to run (`fw inception decide` is agent-blocked under `$CLAUDECODE=1`,
      T-1259). Replaced by two checkable ACs — recommendation filled, handoff issued
- [x] Every **other** Agent AC in the greenfield seed is satisfiable *before* decide
      runs — no remaining Agent AC names a closing command aimed at its own task
- [x] The same scan applied to **all 11** seed task files under `lib/seeds/tasks/`,
      not just `greenfield/T-002`. Raw pattern matched 3 files; reading the context
      **refuted 2** — `greenfield/T-004` and `existing-project/T-004` name
      `fw task update T-XXX --status work-completed` for a *different* task the
      learner creates one line above ("Create a new task"), so they are correct and
      were left alone. One real instance, as reported
- [x] A test pins the property against the seed corpus with **two** controls:
      `anti-vacuity — the scanner detects the original defect` (reconstructs the
      shipped pre-fix line and asserts it is flagged) and a false-positive control
      asserting the T-004 lifecycle shape is *not* flagged.
      `tests/unit/seed_self_gating_ac.bats`, 4/4
- [ ] End-to-end: a greenfield project seeded from the fixed seeds carries its first
      inception through the real decide preflight without `--force` or
      `--skip-acceptance-criteria`, and without a DEFER hedge

  <!-- BLOCKED, not skipped. Running this requires `fw inception decide` in a command
       string, which the Tier 0 hook refuses under agent control — correctly, and the
       standing "proceed as you see fit" directive does not override a structural gate
       (CLAUDE.md §Autonomous Mode Boundaries). `--i-am-human` would be the sanctioned
       test-context flag here and does NOT bypass the AC-count preflight that was the
       actual deadlock, so the test would still be valid; it is the Tier 0 approval
       that is missing, not a safe way to run it.

       To unblock:
         cd /opt/999-Agentic-Engineering-Framework && bin/fw tier0 approve

       Until then this AC stays unticked. The narrower property — that no Agent AC
       can gate its own closing command — IS verified, by the bats suite above. -->

<!-- SCOPE NOTE (T-2863 F-17, not fixed here): `lib/inception.sh:521` guards the
     agent-AC preflight with `go || no-go`, so DEFER skips it entirely. That makes
     any future seed deadlock escapable by hedging — the exact hedge CLAUDE.md
     forbids (T-2144) and T-2145 ships a detector for. Fixing the seed removes the
     incentive for a new user; closing the asymmetry itself is a T-2863 build slice,
     not this task. -->


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

out=$(bats tests/unit/seed_self_gating_ac.bats 2>&1); echo "$out" | grep -q "^ok 4 " && ! echo "$out" | grep -q "^not ok"
# scoped to the Agent AC block: the removal note below it quotes the old line on purpose
acs=$(awk '/^### Agent/{a=1;next} /^### |^## /{a=0} a' lib/seeds/tasks/greenfield/T-002-define-project-goals.md | grep -E '^\s*-\s*\[[ x]\]'); ! echo "$acs" | grep -q "inception decide"
grep -q "fw task review T-002" lib/seeds/tasks/greenfield/T-002-define-project-goals.md
test "$(find lib/seeds/tasks -name '*.md' | wc -l)" -eq 11

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

### 2026-08-07T17:24:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2862-greenfield-seed-t-002-ships-a-self-refer.md
- **Context:** Initial task creation

### 2026-08-08T07:43:30Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
