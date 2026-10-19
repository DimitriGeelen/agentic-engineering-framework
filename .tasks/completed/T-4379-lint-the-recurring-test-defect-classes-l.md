---
id: T-4379
name: "Lint the recurring test-defect classes: live-repo anchors, reading this project's
  config, missing temp project root"
description: >
  Static lint in tests/lint (like the dead-negation lint): flag tests that run the
  live audit/doctor against the repo, read the repo's .framework.yaml or .context,
  or drive fw without a temp project root. Each rule pinned with a fixture that it
  catches and one it lets pass. Arc test-suite-health (arc-026), anchor T-4376; build
  only after the inception GO.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
arc_id: test-suite-health
# write_set:                      # T-3512: optional — globs (relative to PROJECT_ROOT)
#                                 # naming the files this task intends to write. Declared
#                                 # at CAPTURE, unlike components: which the framework
#                                 # resolves from git history at close. Feeds TWO things:
#                                 #   1. `fw write-set check T-A T-B` — without it the
#                                 #      comparison has nothing to compare and every real
#                                 #      pair exits 2 (undecidable). 0 of 3032 tasks
#                                 #      declared it, so that gate has never had an input.
#                                 #   2. BVP blast_radius before close — the 0.6-weighted
#                                 #      cost term, unavailable for 85% of rankable tasks
#                                 #      because components: only exists once the task is
#                                 #      finished (T-3471).
#                                 # Example: write_set: ["lib/bvp.sh", "tests/unit/t*_bvp*"]
#                                 # An EMPTY list is a real declaration ("writes nothing"),
#                                 # which is not the same as omitting the field. Omitted
#                                 # means unknown, and unknown must never score as cheap.
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
created: 2026-10-19T11:58:37Z
last_update: 2026-10-19T17:46:04Z
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
  - ts: '2026-10-19T12:00:44Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=287,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-19T12:01:46Z'
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
    rationale: verdict-determinacy=? (unscored (no scorer for 
      verdict-determinacy; not counted)); fault-detection-fidelity=? (unscored 
      (no scorer for fault-detection-fidelity; not counted)); D1=4 
      (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3 
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-4379: Lint the recurring test-defect classes: live-repo anchors, reading this project's config, missing temp project root

## Context

Arc test-suite-health (arc-026), anchor T-4376 (GO). Evidence: docs/reports/T-4376-test-suite-refactor.md,
docs/reports/T-4382-bimodal-triage.md, T-4372 / T-4383 (audit.bats live-repo cases), T-2746 / T-4313 (fw without a
temp project), the t4347 key-0 test (read this project's .framework.yaml). Static lint over `*.bats`, modelled on
tools/bats-dead-negation-lint.py. Flagged tests are NOT fixed here (later arc work); the lint starts as a WARN in
`fw test lint` against a committed baseline of current offenders.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `tools/bats-test-isolation-lint.py` exists with three rules: `live-audit` (audit.sh / `fw doctor|audit|handover` run with no temp PROJECT_ROOT in scope), `repo-state` (a repo-root variable joined to `/.framework.yaml` or `/.context/`), `fw-no-temp-root` (bin/fw driven, other verbs, no temp PROJECT_ROOT in scope); heredoc bodies and comments ignored; allow comment `# test-isolation: allow <rule|all> — reason` at line, block or file level
- [x] Each rule pinned in `tests/lint/bats-test-isolation.bats` by a fixture it catches and one it lets pass (incl. the allow comment and a temp PROJECT_ROOT), plus baseline behaviour (old offenders pass, a new one over the baseline is reported, exit 1)
- [x] Committed baseline `tests/lint/test-isolation-baseline.txt` of current offenders; the corpus scan against it is clean; current corpus count per rule recorded in this task
- [x] `fw test lint` runs the lint and reports new offenders as WARN (does not set a failing exit)
- [x] Dead-negation lint runs at commit time on staged `tests/**/*.bats` (pre-commit hook block, hook versions bumped, staged blob scanned, not the worktree file); pinned by a regression test that is red without the block
- [x] `python3 tools/bats-dead-negation-lint.py tests/` clean; vendor self --check clean (or red only on other workers' files)

### Evidence (2026-10-19)
- **Corpus count at landing** (1,003 `.bats` files): 261 offending lines in 113 (rule, file) pairs.
  `live-audit` 60 lines in 27 files, `repo-state` 69 in 40 files, `fw-no-temp-root` 132 in 46 files.
  All are in `tests/lint/test-isolation-baseline.txt`; the scan against it reports `new 0`.
- Of T-4401's 32 grep candidates, most are already hermetic (temp PROJECT_ROOT in setup). The lint names the
  ones that are not: audit.bats (8), doctor_designer_pin_drift (5), handover.bats (8), t3119/t3158 designer
  currency, worker_kinds_parity and others.
- `tests/lint/bats-test-isolation.bats`: 16/16 ok, 0 skips. Red before: the tool did not exist.
- `tests/unit/t4379_precommit_dead_negation.bats`: 4/4 ok. Against HEAD's `hooks.sh` (scratch copy):
  `not ok 1` (dead negation refused) and `not ok 3` (staged blob scanned), so it is red without the block.
- `bin/fw test lint`: rc 0, new "Test-Isolation Lint" section, `new 0`, "OK  no new offenders".
- hook_version_marker_parity 7/7, t4403_hook_block_preserve 7/7 after the version bump (commit-msg 1.17→1.18,
  pre-commit 1.5→1.6). Hooks installed in this repo (`bin/fw git install-hooks`).

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

<!--
  Render-touching build tasks (web/templates, web/static, web/blueprints, web/shared.py,
  web/app.py …) add a section headed "Visual Verification" (level-2 heading) after
  Verification, with one checklist table — the check-visual-verification gate reads it
  at commit time (T-4213; T-4202 GO):

    | state | control | 1024 | 1440 | 1920 | note |
    |-------|---------|------|------|------|------|
    | toolbar | Load | ok | ok | ok | |

  Cells: ok / clipped / hidden / overlap / unreachable (non-ok needs a note). Each
  listed state needs screenshots at every UX_SHOT_WIDTHS width:
  fw ux shots <T-ID> <state>=<URL>. This comment is inert: the gate ignores it.
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
# Build/refactor/decommission tasks with NO command here are refused. If nothing can be
# run, add the line `# verification: none — <why nothing can be run>`; it is serviced
# (queued for review: add a check / other evidence / accept). See docs/reports/T-4024-servicing-loop.md.
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
test -f tools/bats-test-isolation-lint.py
timeout 300 bats tests/lint/bats-test-isolation.bats > /tmp/.t4379-lint.out 2>&1 && ! grep -q "^not ok" /tmp/.t4379-lint.out
test "$(grep -c '# skip' /tmp/.t4379-lint.out)" -eq 0
python3 tools/bats-test-isolation-lint.py tests/ > /tmp/.t4379-corpus.out 2>&1 && grep -q "new 0" /tmp/.t4379-corpus.out
python3 tools/bats-dead-negation-lint.py tests/ > /tmp/.t4379-dn.out 2>&1 && grep -q "clean" /tmp/.t4379-dn.out
timeout 300 bats tests/unit/t4379_precommit_dead_negation.bats > /tmp/.t4379-pc.out 2>&1 && ! grep -q "^not ok" /tmp/.t4379-pc.out
timeout 120 bats tests/unit/hook_version_marker_parity.bats > /tmp/.t4379-hv.out 2>&1 && ! grep -q "^not ok" /tmp/.t4379-hv.out
bash -n bin/fw && bash -n agents/git/lib/hooks.sh
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

**Symptom:** the same three test defects recur: tests run the live audit/doctor against this repo (audit.bats,
T-4372 ratchet loop; 32 candidates in T-4401), read this project's own `.framework.yaml` / `.context/` (t4347 key-0),
or drive `bin/fw` with no temp project (T-2746, T-4313). Each was fixed one file at a time, and the next one landed.

**Root cause:** isolation is opt-in. `tests/test_helper.bash` sets no PROJECT_ROOT, and `bin/fw` falls back to its
own repo when nothing else resolves (`bin/fw:94`, `PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"`), so a test that
forgets a temp root silently runs against the live repo and passes.

**Why structurally allowed:** no static check names these shapes. The existing lints (dead negation, silent skip)
cover assertion shape, not what a test is pointed at; review caught each instance only after it went red or slow.
Separately, the dead-negation lint ran only at pre-push / structure audit (T-3191), so a dead `!` was found a push
later than the commit that wrote it (T-4398).

**Prevention:** `tools/bats-test-isolation-lint.py` in `fw test lint` with a committed baseline: any new offender is
named; old ones are the work queue. The pre-commit hook now runs the dead-negation lint on staged `tests/**/*.bats`.

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

### 2026-10-19 — scope at build start
- **What changed:** T-4382 showed the live-audit class is worse than slow: those tests mostly *skip* on the
  repo-wide audit lock and report `ok`. The lint therefore treats "runs the live audit" as a membership defect
  regardless of how the test copes with contention.
- **Plan impact:** the lint is a WARN plus baseline (ratchet), not a FAIL, so the 32-file T-4401 backlog does not
  block anything while new offenders are still named.
- **Triggered:** none yet; the baseline list is the work queue for T-4401 / T-4378.

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

### 2026-10-19 — scope: .bats only
- **Chose:** lint `*.bats` only.
- **Why:** 1,003 of the suite's files are bats. The heredoc and continuation parsing is reused from the
  dead-negation lint, and the rules are shell shapes.
- **Rejected:** pytest coverage in the same tool. The t4347 key-0 origin was a pytest file, so that leg stays
  open for later arc work. It needs a Python AST rule, not a shell regex.

### 2026-10-19 — what counts as "temp-rooted"
- **Chose:** the nearest `PROJECT_ROOT=` / `cd` / `unset PROJECT_ROOT` event decides: the line itself, then
  earlier in the block, then setup, then file level. Anything that is not recognisably this repo counts as temp.
- **Why:** a test that does `cd "$FRAMEWORK_ROOT"` after a temp setup is live again (t3119). Being lenient on
  unknown values keeps the lint precise, so it does not get an allowance added just to quiet it.
- **Rejected:** a flag on any presence of a temp assignment in the file. That missed the cd-back case and the
  inline `PROJECT_ROOT="$BATS_TEST_DIRNAME/../.."` case.

### 2026-10-19 — baseline granularity
- **Chose:** a count per (rule, file).
- **Why:** line numbers drift with every edit. A count ratchet still catches a new offender in an already
  baselined file.
- **Rejected:** per-line keys, which churn on unrelated edits.

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

### 2026-10-19T11:58:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4379-lint-the-recurring-test-defect-classes-l.md
- **Context:** Initial task creation

### 2026-10-19T17:46:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
