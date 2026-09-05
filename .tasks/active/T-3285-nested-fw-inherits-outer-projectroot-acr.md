---
id: T-3285
name: "nested fw inherits outer PROJECT_ROOT across project boundaries and writes
  into the wrong repo (OBS-370)"
description: >
  An outer fw process exports PROJECT_ROOT/TASKS_DIR/CONTEXT_DIR (lib/paths.sh:352);
  a nested invocation of a DIFFERENT project's bin/fw preserves the inherited PROJECT_ROOT
  (_fw_reexec_authority, bin/fw:361) instead of re-deriving from its own tree, so
  its writes land in the outer project. Demonstrated: T-3250's close gate ran a sandbox
  harness whose fw task create wrote 34 junk tasks into the live framework repo while
  the sandbox saw 0. Candidate fix: when inherited PROJECT_ROOT does not contain PWD
  (or PWD resolves to a different .framework.yaml/.tasks root), re-derive from PWD
  and drop the inherited value; pin with a two-project bats test run under exported
  outer env. See OBS-370, T-3250 Evolution rig-defect-5 entry.

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
created: 2026-09-05T18:19:14Z
last_update: 2026-09-05T19:37:38Z
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
  - ts: '2026-09-05T18:30:18Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=258,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-05T18:30:33Z'
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

# T-3285: nested fw inherits outer PROJECT_ROOT across project boundaries and writes into the wrong repo (OBS-370)

## Context

An outer fw process exports `PROJECT_ROOT`/`TASKS_DIR`/`CONTEXT_DIR` (lib/paths.sh:352)
plus the provenance sentinel `_FW_PATHS_DERIVED_BY` (lib/paths.sh:74). A nested fw
invoked in a **different** project inherits all four; `_project_root_is_stale`
(bin/fw:175) deliberately keeps any inherited root that is a real project
("env wins", pinned by test_resolve_project_root_env_wins_unconditionally), so the
nested fw acts on the OUTER project. Demonstrated live by T-3250's close gate: the
E10 sandbox's `fw task create` wrote 34 junk tasks into this repo while the sandbox
saw 0 (OBS-370, T-3250 Evolution rig-defect-5).

The discriminator that makes this fixable without breaking env-wins: an
operator-explicit `PROJECT_ROOT=/x fw …` carries **no** `_FW_PATHS_DERIVED_BY`
(interactive shells never source lib/paths.sh; the sentinel only exists inside fw
process trees). So: inherited PROJECT_ROOT whose value **equals** the inherited
sentinel = fw-machinery leakage → when the cwd ancestry walk finds a *different*
real (non-stale) project root, re-anchor to it and drop the sibling TASKS_DIR/
CONTEXT_DIR so lib/paths.sh re-derives them. Sentinel absent or mismatched =
ambiguous/explicit → env wins, unchanged. Same shape as the T-2446 fix for
CLAUDE_PROJECT_DIR, one branch further down.

## Acceptance Criteria

### Agent
- [x] bin/fw re-anchors an fw-derived inherited PROJECT_ROOT (sentinel == value) to the cwd's project root when they name different real projects — pinned by new `tests/unit/t3285_nested_fw_cross_project.bats` (t1 6/6 green; red-check: with the fix stashed, the same probe resolves the OUTER root)
- [x] Operator-explicit env still wins unconditionally: no sentinel, or sentinel != PROJECT_ROOT, keeps the inherited root (t2/t3 green; t2446 t4 green; test_resolve_project_root_env_wins_unconditionally green)
- [x] Write-leg proof: with the full T-3250 poisoned-env shape (PROJECT_ROOT+TASKS_DIR+CONTEXT_DIR+sentinel from the outer project), `fw task create` in the inner project writes to the INNER `.tasks/`, zero files in the outer (t6 green)
- [x] All resolution-adjacent suites stay green: 34 bats tests across t2289/t2390/t2391/t2446/guard_project_root/resolve_framework/t3285 — 0 not-ok, 0 skips; t3111_worktree_reexec 16/16 incl. "PROJECT_ROOT does NOT move to the authority"; test_project_root_discovery.py 7/7

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

timeout 300 bats tests/unit/t3285_nested_fw_cross_project.bats > /tmp/.t3285-pin.tap 2>&1 && ! grep -q "^not ok" /tmp/.t3285-pin.tap
test "$(grep -c '# skip' /tmp/.t3285-pin.tap)" -eq 0
timeout 500 bats tests/unit/t2289_paths_env_leak.bats tests/unit/t2390_project_root_claude_dir.bats tests/unit/t2391_project_root_inherited_stale.bats tests/unit/t2446_project_root_cwd_consistency.bats tests/unit/guard_project_root.bats tests/unit/resolve_framework.bats tests/unit/t3111_worktree_reexec.bats > /tmp/.t3285-adj.tap 2>&1 && ! grep -q "^not ok" /tmp/.t3285-adj.tap
test "$(grep -c '# skip' /tmp/.t3285-adj.tap)" -eq 0
python3 -m pytest tests/unit/test_project_root_discovery.py -q > /tmp/.t3285-py.out 2>&1 && grep -q passed /tmp/.t3285-py.out
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

**Symptom:** T-3250's P-011 close gate ran the E10 sandbox harness; the sandbox's
`fw task create` wrote 34 junk tasks (`T-3285-e10-backlog-item-*`) into the LIVE
framework repo's `.tasks/active/` while the sandbox's own tree stayed empty — the
harness then failed its own "expected 16 backlog" assertion because the tasks
never landed where it looked (OBS-370).

**Root cause:** `update-task.sh` (like every fw process) carries
`PROJECT_ROOT`/`TASKS_DIR`/`CONTEXT_DIR` exported by lib/paths.sh:352. The nested
sandbox fw inherited them; bin/fw's staleness guard (`_project_root_is_stale`,
T-2391) deliberately keeps any inherited root that IS a real project — the
"env wins" contract for operator cross-dir targeting — so a *valid but wrong*
root sailed through, and lib/paths.sh's T-2289 sentinel check (`_FW_PATHS_DERIVED_BY
!= PROJECT_ROOT` → re-derive) never fired because BOTH were inherited from the
same outer process and matched each other perfectly.

**Why structurally allowed:** validity and provenance were conflated. Every
existing guard asks "is this root a real project?" (T-2391) or "does the sentinel
match the root?" (T-2289) — both answer YES for machinery leakage across a project
boundary, because the leaked values are internally consistent. No guard asked
"did an operator set this, or did another fw process?" — even though the sentinel's
mere *presence* answers exactly that (interactive shells never source lib/paths.sh).

**Prevention:** (1) the fix itself is a class guard, not a spot fix — any nested
fw in any different project now re-anchors, which covers every future harness,
dispatch worker, and consumer-project crossing, not just E10; (2)
`tests/unit/t3285_nested_fw_cross_project.bats` pins all six contract cells
(re-anchor, two env-wins controls, same-project no-op, non-project cwd, write-leg);
(3) the T-3250 harness independently carries `ENV_CLEAN` (defence in depth — belt
at the rig, braces in the resolver).
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
**Rationale:** The cross-project write hazard OBS-370 documented is structurally closed at the resolver, with the env-wins contract for operator-explicit targeting proven intact. Red→green demonstrated: with the fix stashed, the poisoned probe resolves the outer root; with it applied, the standing tree wins and a real `fw task create` under the full T-3250 poison lands in the inner project with zero outer leakage.
**Evidence:**
- bin/fw T-3285 branch (36 lines incl. rationale comment) after the resolution block, before reexec
- tests/unit/t3285_nested_fw_cross_project.bats — 6/6, incl. write-leg t6
- Adjacent suites: 34 bats green (0 skips), t3111 16/16, pytest discovery 7/7

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

### 2026-09-05T18:19:14Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3285-nested-fw-inherits-outer-projectroot-acr.md
- **Context:** Initial task creation

### 2026-09-05T19:37:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
