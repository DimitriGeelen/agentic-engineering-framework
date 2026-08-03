---
id: T-2758
name: "fw upgrade hard-fails at step 3 when a consumer has no .context/project/ directory"
description: >
  cp of seed files (practices/decisions/patterns) at lib/upgrade.sh:1117 targets $target_dir/.context/project/
  without mkdir -p. On a consumer that has .framework.yaml but no .context tree, cp
  fails and fw upgrade exits 1 at step 3 of 10 — steps 4-10 (hooks, resume.md, shims,
  vendor) never run. Reproduced live 2026-08-03; 3 tests in tests/unit/lib_upgrade.bats
  have been red on this.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [lib/upgrade.sh]
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
created: 2026-08-03T10:18:21Z
last_update: 2026-08-03T11:19:25Z
date_finished: 2026-08-03T11:19:25Z
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
  - ts: '2026-08-03T10:25:17Z'
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
cost_estimate_proposed:
  - ts: '2026-08-03T10:30:07Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 2
      effort: 8
    rationale: blast_radius=0 (no-signal); tier=2 (no-signal); effort=8 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2758: fw upgrade hard-fails at step 3 when a consumer has no .context/project/ directory

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `fw upgrade` completes (exit 0, all 10 steps) against a consumer that has only
      `.framework.yaml` and no `.context/` tree — the shape that currently dies at step 3.
      Fixed in 826010dfa: a new step 0 creates the full `.context/`, `.tasks/templates`,
      `.claude/commands` and `policy` skeleton before step 1 runs.
- [x] Every write target under `$target_dir` in `lib/upgrade.sh` has its parent directory
      guaranteed to exist before the write, not only the seven that happen to `mkdir -p`
      today. Audited as a set, not spot-fixed at the one line that was observed failing.
      Every remaining `cp`/`cat >`/heredoc write under `$target_dir` (steps 2, 3, 3b, 3c,
      5, 6, 7, 7b, shim migration) is either into a directory step 0 now guarantees
      (`.context/*`, `.tasks/templates`, `.claude/commands`, `policy`) or has its own
      immediately-preceding `mkdir -p` at the write site (e.g. `.context/cron` at :1182,
      `scripts/` at :1792). `$HOME/.agentic-framework` global-install sync writes are
      gated behind `[ -d "$global_dir/agents/context" ]` — a pre-existence check, not a
      target_dir write. No unguarded site remains.
- [x] The three pre-existing red tests in `tests/unit/lib_upgrade.bats` (resume.md drift /
      match / create) go green, and the reason they were red is stated — they were failing
      on this bug, not on resume.md. 12/12 green. They were red for two stacked causes:
      this task's ordering bug (cp into `.context/project/` before it existed) plus a
      second, unrelated cause split off as T-2759 (target_dir rebind at :1305 redirected
      steps 5-10 to the wrong directory) — both had to land before these tests could pass.
- [x] Regression test covers the bare-consumer shape end-to-end, so a future step added
      without a `mkdir -p` is caught by the suite rather than by a consumer.
      `tests/unit/lib_upgrade.bats:144` ("missing resume.md — created from template")
      already constructs exactly this shape (`mkdir -p "$proj"; echo framework_root >
      .framework.yaml` — nothing else) and asserts `do_upgrade` exits 0 end-to-end
      through all 10 steps. It was one of the three red tests; it is the regression
      coverage, not a new file — a future ordering regression fails it the same way
      it failed here.
- [x] `tests/unit/upgrade_fresh_machine_simulation.bats` stays green (CLAUDE.md
      §Consumer-Facing Command Hygiene). 7/7 green.

**Origin (2026-08-03).** Found while running the upgrade suite for T-2755, not reported by
a user — `lib_upgrade.bats` tests 10-12 were red and the assumed cause (resume.md drift)
was wrong. Live repro: a consumer with `.framework.yaml` and nothing else exits 1 at
`[3/10] Seed files` with `cp: cannot create regular file '.../.context/project/practices.yaml'`.
Steps 4-10 — hooks, resume.md, shim, vendor — never run. The failure is loud, but it is
loud *after* two steps have already written to the consumer, so it leaves a half-upgraded
project.

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

out=$(bats tests/unit/lib_upgrade.bats 2>&1); echo "$out" | grep -q '^1\.\.12' && ! echo "$out" | grep -q '^not ok'
out=$(bats tests/unit/upgrade_fresh_machine_simulation.bats 2>&1); echo "$out" | grep -q '^1\.\.7' && ! echo "$out" | grep -q '^not ok'

## RCA

**Symptom.** `fw upgrade` against a consumer holding only `.framework.yaml` (no
`.context/` tree yet — e.g. a project on `.framework.yaml` predating `fw init`'s tree
creation, or one reconstructed by hand) exits 1 at `[3/10] Seed files` with
`cp: cannot create regular file '.../.context/project/practices.yaml': No such file
or directory`. Steps 4-10 — hooks, `.mcp.json`, resume.md, shim, vendor sync, version
pin, enforcement baseline — never run, leaving the consumer half-upgraded (steps 1-2
already wrote).

**Root cause.** `.context/` subdirectory creation lived at step 8, five steps after
step 3 (seed files) first writes into `.context/project/`. The ordering, not the
absence of a `mkdir -p` on any single line, was the defect: the next write added to
any step between 3 and 8 would have inherited the identical failure.

**Why structurally allowed.** Every consumer that reached step 3 in practice had been
through `fw init`, which creates the tree up front — so the ordering gap was invisible
on every real upgrade path exercised so far. The one place the gap is visible is a
project holding `.framework.yaml` and little else, which is exactly the shape
`tests/unit/lib_upgrade.bats` constructs for its resume.md tests — so the tests were
red, and the failure surfaced under a name (resume.md drift) unrelated to its cause,
because the run was dying at step 3, long before resume.md at step 7. A second,
independent defect (T-2759 — `target_dir` rebound at :1305) was stacked on the same
three tests, which delayed isolating this cause until T-2759 was split out.

**Prevention.** Directory skeleton creation moved to a new step 0, before any write —
not a `mkdir -p` added at the observed failing line, which would only have protected
that one `cp`. Every other `$target_dir` write site in `lib/upgrade.sh` was then
audited as a set (see AC #2) to confirm it either lands under a directory step 0 now
guarantees, or already carries its own immediately-preceding `mkdir -p`. The bare-shape
test at `lib_upgrade.bats:144` is the regression guard — a future step written against
an unguaranteed directory fails it the same way this one did.

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

### 2026-08-03T10:18:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-2758-fw-upgrade-hard-fails-at-step-3-when-a-c.md
- **Context:** Initial task creation

### 2026-08-03T10:25:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-88369ca2
- **Timestamp:** 2026-08-03T11:20:24Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **mock-only-integration** (partial, heuristic) @ AC vs Verification cross-check
     - evidence: `out=$(bats tests/unit/lib_upgrade.bats 2>&1); echo "$out" | grep -q '^1\.\.12' && ! echo "$out" | grep -q '^not ok'`

### 2026-08-03T11:19:25Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
