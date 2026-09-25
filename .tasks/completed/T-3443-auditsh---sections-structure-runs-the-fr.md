---
id: T-3443
name: "audit.sh --sections structure runs the framework's own tests/lint invariant
  suite (timeout 300 bats tests/lint/, 110 tests) and the dead-negation lint even
  when PROJECT_ROOT is a synthetic fixture project. Measured 2026-09-22: one fixture
  audit in tests/unit/fabric_watch_pattern_fitness.bats took ~4 min (control test,
  load 7/24 cores); that file runs 6 such audits, so it alone needs 24+ min and any
  verification line bundling it under timeout 900 exits 124 regardless of host load
  (T-3435 close blocked twice on this). Two defects: (1) the invariant suite is a
  framework-repo property and should be skipped when PROJECT_ROOT != FRAMEWORK_ROOT;
  (2) every bats test that shells audit.sh on a fixture pays the full structure cost
  — a --sections structure run on a 3-file fixture should be seconds. Sibling of the
  fabric_coverage_single_source.bats exclusion noted in T-3435."
description: >
  Promoted from observation OBS-471

status: work-completed
workflow_type: build
owner: agent   # operator assignment 2026-09-23 ("On two, okay that's fine"); no fw verb sets owner — edit recorded on the task
horizon: null
tags: []
components: [agents/audit/audit.sh, tests/unit/t3443_audit_structure_framework_scope.bats]
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
created: 2026-09-22T21:30:18Z
last_update: 2026-09-23T18:05:40Z
date_finished: 2026-09-23T18:05:40Z
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
  - ts: '2026-09-22T21:32:57Z'
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
cost_estimate_proposed:
  - ts: '2026-09-22T21:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=291,acs=7)
    rubric_sha: e4a00f38e801
---

# T-3443: audit.sh --sections structure runs the framework's own tests/lint invariant suite (timeout 300 bats tests/lint/, 110 tests) and the dead-negation lint even when PROJECT_ROOT is a synthetic fixture project. Measured 2026-09-22: one fixture audit in tests/unit/fabric_watch_pattern_fitness.bats took ~4 min (control test, load 7/24 cores); that file runs 6 such audits, so it alone needs 24+ min and any verification line bundling it under timeout 900 exits 124 regardless of host load (T-3435 close blocked twice on this). Two defects: (1) the invariant suite is a framework-repo property and should be skipped when PROJECT_ROOT != FRAMEWORK_ROOT; (2) every bats test that shells audit.sh on a fixture pays the full structure cost — a --sections structure run on a 3-file fixture should be seconds. Sibling of the fabric_coverage_single_source.bats exclusion noted in T-3435.

## Context

Promoted from OBS-471. `agents/audit/audit.sh --sections structure` runs the framework's
invariant suite (`timeout 300 bats tests/lint/`, 110 tests, via `check_invariant_suite`
~:1196) and the dead-negation lint over `tests/` regardless of what `PROJECT_ROOT` is. Both are
properties of the framework repository (`FRAMEWORK_ROOT`), not of the project being audited.
Measured 2026-09-22: one fixture audit in `tests/unit/fabric_watch_pattern_fitness.bats` took
about 4 minutes; that file runs six, so it needs 24+ minutes and any verification line bundling
it under `timeout 900` exits 124 on every host (T-3435's close was blocked twice on this and the
file was excluded with reason). `audit.sh` derives `FRAMEWORK_ROOT` from its own path (line 18)
and `PROJECT_ROOT` from `lib/paths.sh`, so the discriminator already exists.

## Acceptance Criteria

### Agent
- [x] `check_invariant_suite` and the dead-negation lint run only when `PROJECT_ROOT` resolves
      to the same directory as `FRAMEWORK_ROOT`; otherwise each emits one `[INFO]` line naming
      the skip and the reason ("framework-repo property; PROJECT_ROOT is not the framework
      repo") and the section continues. No other structure check changes.
      **Evidence:** `agents/audit/audit.sh` — new `_t3443_project_is_framework_root()` helper
      (resolves both roots via `pwd -P`, guards against symlink/trailing-slash false-negatives)
      gates the top of both `check_invariant_suite()` and `check_dead_negation_lint()`; each
      emits `info "... skipped — framework-repo property; PROJECT_ROOT is not the framework
      repo"` and returns 0. No other line in either function, or elsewhere in the structure
      section, was touched (`git diff --stat agents/audit/audit.sh` shows one hunk per function
      plus the shared helper).
- [x] Measured: `PROJECT_ROOT=<fixture> bash agents/audit/audit.sh --sections structure` on a
      minimal fixture project completes in under 60 s (record the number in this task); the
      same command with `PROJECT_ROOT` = the framework repo still runs both checks (control:
      the PASS/WARN line for the invariant suite is present).
      **Evidence:** fixture run (3-file `.fabric`/`.tasks` skeleton, real `PROJECT_ROOT`≠
      `FRAMEWORK_ROOT`) measured **1.78s wall** (`real 0m1.780s`), emitting both `[INFO]` skip
      lines and no invariant-suite/dead-negation verdict line. Control run (`PROJECT_ROOT` =
      `/opt/999-Agentic-Engineering-Framework` = `FRAMEWORK_ROOT`) measured **4m47.4s wall**
      (`real 4m47,408s`) and emitted `[PASS] Invariant suite (tests/lint) green — examined 110
      structural invariant(s)` and `[PASS] Dead-negation lint (tests/) clean — examined 772
      bats file(s)`. Both raw outputs captured at `/tmp/t3443_fixture_out.txt` and
      `/tmp/t3443_control_out.txt` during the session (not committed — ephemeral measurement).
- [x] bats: fixture audit emits the two `[INFO]` skip lines and no `Invariant suite` PASS/FAIL
      line; framework-root audit emits the `Invariant suite` line (pin the control, not just the
      silence); `TEST_TEMP_DIR` set in setup; no bare `! grep -q`.
      **Evidence:** `tests/unit/t3443_audit_structure_framework_scope.bats`, 2 tests, both
      green (`bats tests/unit/t3443_audit_structure_framework_scope.bats` → `1..2`, `ok 1`,
      `ok 2`). Uses `load ../test_helper` (setup()/teardown() incl. `TEST_TEMP_DIR="$(mktemp
      -d)"` from `tests/test_helper.bash`, not redefined). `python3 tools/bats-dead-negation-lint.py
      tests/unit/t3443_audit_structure_framework_scope.bats` → `dead 0 in 0 file(s)` (no `!`
      assertions in the file at all; negative assertions use
      `[ "$(echo "$out" | grep -c PAT)" -eq 0 ]`).
- [x] Existing suites that shell the audit on fixtures are re-run and their timing recorded:
      `tests/unit/fabric_watch_pattern_fitness.bats` completes under `timeout 900`, and T-3435's
      exclusion comment is updated to say the file is runnable again (its verification block
      stays as closed; note only).
      **Evidence:** `timeout 900 bats tests/unit/fabric_watch_pattern_fitness.bats` measured
      **11.8s wall** (`real 0m11,832s`), well under the 900s ceiling (was 124/timeout at 24+min
      before this fix). Comment updated in
      `.tasks/active/T-3435-fabric-card-quality-second-pass-header-c.md` (its `## Verification`
      shell commands, line 323, unchanged — comment-only edit). Re-running surfaced 2
      pre-existing `not ok` results unrelated to timing (wording drift between the test's
      expected string and current `pass_over()` output format) — filed as OBS-487, out of this
      task's scope per the operator's explicit narrowing instruction.
- [x] Vendored `agents/audit/audit.sh` synced; `bin/fw vendor self --check` clean; audit
      cron-touching rule not triggered (no registry edit) — state so in `## Decisions`.
      **Evidence:** `FW_VENDOR_ONLY=agents/audit/audit.sh bin/fw vendor self` → "synced 1
      agents/ file(s)"; `bin/fw vendor self --check` → "vendored .agentic-framework/ in sync
      with source" (exit 0). `.context/cron-registry.yaml` not touched this task — see
      `## Decisions`.

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

bash -n agents/audit/audit.sh
out=$(timeout 90 bats tests/unit/t3443_audit_structure_framework_scope.bats -f "fixture audit" 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok" && [ "$(echo "$out" | grep -c '# skip')" -eq 0 ]
out=$(timeout 600 bats tests/unit/t3443_audit_structure_framework_scope.bats -f "control" 2>&1); echo "$out" | grep -q "^ok 1 " && ! echo "$out" | grep -q "^not ok" && [ "$(echo "$out" | grep -c '# skip')" -eq 0 ]
bin/fw vendor self --check

## RCA

**Symptom:** `agents/audit/audit.sh --sections structure` ran the framework's own
`tests/lint/` invariant suite (`timeout 300 bats tests/lint/`, 110 tests) and a
source-text dead-negation lint over `tests/` on every invocation, regardless of what
project `PROJECT_ROOT` pointed at. A bats file shelling `audit.sh --sections
structure` against a synthetic 3-file fixture paid the full framework-repo cost:
measured 2026-09-22, ~4 min per call; `tests/unit/fabric_watch_pattern_fitness.bats`
shells six such calls and needed 24+ min, so any verification line bundling it under
`timeout 900` exited 124 on every host — T-3435's close was blocked twice on exactly
this and the file was excluded with a comment rather than fixed.

**Root cause:** `check_invariant_suite` and `check_dead_negation_lint` (T-2837,
T-3191) both scan `$FRAMEWORK_ROOT/tests`, a fixed path derived from `audit.sh`'s
own location (`agents/audit/audit.sh` → `FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.."
&& pwd)"`) — never from `$PROJECT_ROOT`, which `lib/paths.sh` resolves independently
(git toplevel, or the vendored-consumer sibling). Neither function had a check for
whether the two roots coincide. They were written correctly for the one case the
authoring session had in view — `fw audit` invoked against the framework repo
itself, where the two roots ARE the same directory — and the split-root case
(a consumer project, or a test fixture, auditing under a shared framework
installation) was never a distinct code path.

**Why structurally allowed:** `PROJECT_ROOT` vs `FRAMEWORK_ROOT` is a real,
pre-existing discriminator (`lib/paths.sh`, sourced by every agent script,
including `audit.sh` itself) — the framework already models "the repo I'm running
from" as different from "the project I'm auditing". But nothing in the structure
section's authoring discipline required a check to ask "is this check a property of
FRAMEWORK_ROOT or of PROJECT_ROOT?" before scanning `$FRAMEWORK_ROOT/tests`
unconditionally. T-3356 hit an adjacent case three tasks earlier (the T-1856
anchor-task check nested inside the same structure section, extracted to
`lib/audit-anchor-task.sh` specifically so its detection was reachable without
paying the `check_invariant_suite` cost) and even documented the cost
(`agents/audit/audit.sh:1194-1197`) — but extracted around the cost rather than
scoping the check that caused it, so the underlying defect (both checks running
unconditionally on every root) persisted for both T-3356 and every fixture-shelling
bats file written since T-2837/T-3191 landed.

**Prevention:** `_t3443_project_is_framework_root()` is now the explicit gate at the
top of both functions — any check added to this section that is a property of the
framework repository (not of the audited project) has a one-line pattern to copy.
`tests/unit/t3443_audit_structure_framework_scope.bats` pins both the skip (fixture)
and the non-skip (framework-root control) so a future refactor that accidentally
drops the gate, or one that makes it fire on the framework repo itself, both go red.

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

### 2026-09-23 — Cron-touching verification rule does not apply
This task edits `agents/audit/audit.sh` only. It does not touch
`.context/cron-registry.yaml`, anything under `.context/cron/`, or any cron
generator code (`bin/fw cron generate|install`, `agents/audit/audit.sh` cron
schedule helpers at the top of the file that emit crontab lines). CLAUDE.md's
Cron-touching verification rule (L-364, T-1771, T-1942, T-1943) therefore does
not apply and no `bin/fw doctor` cron-sync verification line was added.

### 2026-09-23 — Path-comparison method: resolved `pwd -P`, not string equality
- **Chose:** `_t3443_project_is_framework_root()` resolves both `PROJECT_ROOT` and
  `FRAMEWORK_ROOT` via `cd ... && pwd -P` before comparing, per the AC's explicit
  instruction.
- **Why:** a symlinked path (e.g. a vendored consumer where `.agentic-framework`
  is a symlink) or a trailing-slash `PROJECT_ROOT` would compare unequal to an
  unresolved `FRAMEWORK_ROOT` under plain string equality even when they name the
  same directory — a false "not the framework repo" that would wrongly skip the
  checks on the framework repo itself.
- **Rejected:** plain `[ "$PROJECT_ROOT" = "$FRAMEWORK_ROOT" ]` (both vars are
  already absolute per `lib/paths.sh`, but not guaranteed symlink-resolved or
  trailing-slash-normalised — rejected per the AC's own reasoning).

### 2026-09-23 — OBS-487 (pre-existing wording-mismatch) left unfixed
- **Chose:** file OBS-487 and leave `tests/unit/fabric_watch_pattern_fitness.bats`'s
  2 `not ok` results (unrelated string-format drift between the test's expected
  text and current `pass_over()` output) unfixed.
- **Why:** the operator's dispatch instructions were explicit and narrow ("Five
  Agent ACs, no Human ACs... Do not widen it"); AC 4 only requires the file to
  *complete* under `timeout 900` (it does, in ~12s) and the exclusion comment to
  be updated to say so, not for its tests to pass. The wording drift is a separate,
  pre-existing bug unmasked by this fix (the assertions never got a chance to run
  before, because the whole file always hit the 900s ceiling first).
- **Rejected:** fixing the wording drift inline — out of scope, no reviewing AC
  covers it, and it is unrelated to the PROJECT_ROOT/FRAMEWORK_ROOT scoping defect
  this task exists to close.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-22T21:30:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3443-auditsh---sections-structure-runs-the-fr.md
- **Context:** Initial task creation

### 2026-09-23T17:39:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-24dabce6
- **Timestamp:** 2026-09-23T18:10:27Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-23T18:05:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
