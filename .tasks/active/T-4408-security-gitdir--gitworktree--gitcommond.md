---
id: T-4408
name: "SECURITY: GIT_DIR / GIT_WORK_TREE / GIT_COMMON_DIR env-var prefixes bypass
  T-4343: git reads an outside repository's config while judged read-only"
description: >
  Reported by ring20-dashboard (msg 16c721c9) on installed v1.8.12, reproduced on
  bleeding-edge 2026-10-19: is_bash_safe_command('GIT_DIR=/tmp/evil/.git git log'),
  ('GIT_WORK_TREE=/tmp/evil git status'), ('GIT_COMMON_DIR=/tmp/evil/.git git status')
  all SAFE. Same exposure as T-4343 (core.fsmonitor / core.pager / diff.external in
  that repo's config run arbitrary commands). Fix: treat GIT_DIR, GIT_WORK_TREE, GIT_COMMON_DIR,
  GIT_INDEX_FILE?, GIT_OBJECT_DIRECTORY?, GIT_CEILING_DIRECTORIES (decide each) like
  --git-dir: check the value resolves inside PROJECT_ROOT via _fw_git_dir_is_project,
  or deny the prefix in _fw_env_prefix_is_denied; also the 'env VAR=… git' and 'export
  VAR=…; git' shapes. Red run on current code; field test by ring20-dashboard (their
  tmp/t2541_probe.sh). Serial after T-4396 (same file).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
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
created: 2026-10-19T15:59:12Z
last_update: 2026-10-19T16:07:37Z
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
  - ts: '2026-10-19T16:00:53Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=287,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-19T16:02:03Z'
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
---

# T-4408: SECURITY: GIT_DIR / GIT_WORK_TREE / GIT_COMMON_DIR env-var prefixes bypass T-4343: git reads an outside repository's config while judged read-only

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

**Red run, pre-fix code (HEAD 06580ef92), 2026-10-19, PROJECT_ROOT=_FW_PAYLOAD_CWD=repo root:**

| command | verdict |
|---|---|
| `GIT_DIR=/tmp/evil/.git git log` | SAFE |
| `GIT_WORK_TREE=/tmp/evil git status` | SAFE |
| `GIT_COMMON_DIR=/tmp/evil/.git git status` | SAFE |
| `env GIT_DIR=/tmp/evil/.git git log` | SAFE |
| `GIT_DIR=/tmp/evil/.git; git log` | SAFE |
| `GIT_CONFIG_PARAMETERS=x git status` | SAFE |
| `GIT_EXEC_PATH=/tmp/evil git fetch` | SAFE |
| `GIT_INDEX_FILE=/tmp/evil/idx git status` / `GIT_OBJECT_DIRECTORY=/tmp/evil git log` / `GIT_ALTERNATE_OBJECT_DIRECTORIES=/tmp/evil git log` | SAFE |
| `export GIT_DIR=/tmp/evil/.git; git log` / `... && git log` | unsafe (export not allowlisted) |

New bats file against the HEAD copy of safe-commands.sh: 17 of 25 not ok (every NOT-SAFE case except the two `export` shapes, which were already refused). After the fix: 25/25 ok; after-fix probe: all of the above unsafe, `GIT_DIR=.git git log`, `env GIT_DIR=.git git log`, `GIT_CEILING_DIRECTORIES=/opt git status`, `GIT_CONFIG_NOSYSTEM=1 git status` SAFE.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Red run on the pre-fix code recorded in this task: the reporter's cases `GIT_DIR=/tmp/evil/.git git log`, `GIT_WORK_TREE=/tmp/evil git status`, `GIT_COMMON_DIR=/tmp/evil/.git git status` (and the `env VAR=x git` / bare-assignment shapes) classify SAFE
- [x] GIT_DIR, GIT_WORK_TREE, GIT_COMMON_DIR, GIT_INDEX_FILE, GIT_OBJECT_DIRECTORY are admitted only when the value resolves inside PROJECT_ROOT (`_fw_git_dir_is_project`, against the tracked cwd); outside / quoted / unresolvable → NOT SAFE, in the `VAR=x cmd`, `env VAR=x cmd` and bare-assignment `VAR=x; cmd` shapes
- [x] Each other git env var is decided and recorded in the source comment: GIT_ALTERNATE_OBJECT_DIRECTORIES and GIT_EXEC_PATH denied, GIT_CONFIG* (incl. GIT_CONFIG_PARAMETERS) denied, GIT_CONFIG_NOSYSTEM and GIT_CEILING_DIRECTORIES allowed
- [x] `export VAR=x; git …` / `export VAR=x && git …` are NOT SAFE (export is not allowlisted; pinned by test)
- [x] `GIT_DIR=<inside project> git status` stays SAFE; tests/unit/t4408_git_env_repo_boundary.bats passes, and every safe-commands / boundary bats file passes alone
- [ ] `python3 tools/bats-dead-negation-lint.py tests/` clean; `bin/fw vendor self --check` clean

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
bash -n agents/context/lib/safe-commands.sh
bash -c 'source agents/context/lib/safe-commands.sh; export PROJECT_ROOT=$PWD _FW_PAYLOAD_CWD=$PWD; for c in "GIT_DIR=/tmp/evil/.git git log" "GIT_WORK_TREE=/tmp/evil git status" "GIT_COMMON_DIR=/tmp/evil/.git git status" "env GIT_DIR=/tmp/evil/.git git log" "GIT_DIR=/tmp/evil/.git; git log"; do is_bash_safe_command "$c" && exit 1; done; is_bash_safe_command "GIT_DIR=.git git status"'
timeout 300 bats tests/unit/t4408_git_env_repo_boundary.bats > /tmp/.t4408.out 2>&1 && ! grep -q "^not ok" /tmp/.t4408.out
test "$(grep -c '# skip' /tmp/.t4408.out)" -eq 0
timeout 600 bats tests/unit/safe_commands_env_prefix.bats tests/unit/t4343_git_repo_path_boundary.bats tests/unit/t4264_git_global_opts_safe.bats tests/unit/t4344_boundary_read_free_text_opts.bats tests/unit/t4367_git_output_option.bats tests/unit/t4396_safe_commands_loops.bats tests/unit/context_safe_commands.bats tests/unit/check_project_boundary.bats tests/unit/t3096_safe_commands_wrappers.bats tests/unit/safe_commands_chain.bats > /tmp/.t4408b.out 2>&1 && ! grep -q "^not ok" /tmp/.t4408b.out
python3 tools/bats-dead-negation-lint.py tests/ > /tmp/.t4408l.out 2>&1 && grep -q clean /tmp/.t4408l.out
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

**Symptom:** `GIT_DIR=/tmp/evil/.git git log`, `GIT_WORK_TREE=/tmp/evil git status`, `GIT_COMMON_DIR=/tmp/evil/.git git status` were classified SAFE by `is_bash_safe_command`, so the task gate let git read an outside repository whose config (core.fsmonitor, core.pager, diff.external) runs arbitrary commands — the T-4343 hole through the environment instead of `-C` / `--git-dir` (ring20-dashboard, msg 16c721c9).

**Root cause:** `_fw_strip_env_prefixes` (agents/context/lib/safe-commands.sh:401) strips every `NAME=VALUE` prefix whose name `_fw_env_prefix_is_denied` (:334) does not deny, and that denylist excluded repository retargeting on purpose (:356-368, "a read of a different repo is still a read"). T-4343 later established that reading a different repo is NOT only a read (its config executes), but fixed only the `_fw_git_skip_globals` command-line options (:454); the git arm never sees env prefixes because they are stripped before it runs. `GIT_CONFIG_PARAMETERS` and `GIT_EXEC_PATH` were also missing from the denylist.

**Why structurally allowed:** the premise "retargeting is read-only" was written down and pinned by a test (`GIT_DIR=foo git status` SAFE, safe_commands_env_prefix.bats); T-4343 changed the premise for one channel without sweeping the other channels that select a repository (env vars, cwd — T-4409). The denylist is name-only, so it could not express "allowed with this value".

**Prevention:** the repo-selecting names are judged on name AND value by one predicate (`_fw_env_assign_is_denied`) used by the prefix stripper, the `env` re-entry and the bare-assignment arm; tests/unit/t4408_git_env_repo_boundary.bats pins every reporter case plus the inside-project controls.

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

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

### 2026-10-19 — per-variable decisions
- **Chose:** value-checked inside PROJECT_ROOT: GIT_DIR, GIT_WORK_TREE, GIT_COMMON_DIR (select the repository whose config executes), GIT_INDEX_FILE, GIT_OBJECT_DIRECTORY (written by allowlisted verbs: status refreshes the index, add writes objects). Denied by name: every GIT_CONFIG* incl. GIT_CONFIG_PARAMETERS (the `-c` channel, was missing), GIT_EXEC_PATH (git runs helper programs from it, was missing), GIT_ALTERNATE_OBJECT_DIRECTORIES (colon list, not resolvable as one path). Allowed: GIT_CONFIG_NOSYSTEM (only removes config), GIT_CEILING_DIRECTORIES (can only stop discovery). `export VAR=x` is not allowlisted, so those shapes already gate; pinned by test rather than changed.
- **Why:** same rule as T-4343's -C / --git-dir, one predicate (`_fw_env_assign_is_denied`) for all three entry points (prefix strip, `env` re-entry, bare assignment) so they cannot drift.
- **Rejected:** denying GIT_DIR etc. by name — would break the pinned `GIT_DIR=foo git status` contract for an inside-project value with no security gain. The pinned test now sets PROJECT_ROOT and the cwd (it has to: with no PROJECT_ROOT the value is unjudgeable and fails closed); its intent (in-project retargeting is a read) is kept.
- **Not decided here (out of scope, noted):** GIT_TRACE*=/path makes git write a trace file to that path — a write, not execution.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-19T15:59:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4408-security-gitdir--gitworktree--gitcommond.md
- **Context:** Initial task creation

### 2026-10-19T16:07:37Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
