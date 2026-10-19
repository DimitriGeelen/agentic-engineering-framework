---
id: T-4400
name: "fw init bootstrap commit secret-scans the whole vendored framework (~92 s per
  fresh install)"
description: >
  fw init (lib/init.sh ~line 870) runs 'git add -A' then the T-000 bootstrap commit,
  so the project's own pre-commit hook runs secret-scan.sh scan-staged over all 2,678
  vendored .agentic-framework files (38 MB). Measured T-4382, 2026-10-19: 92 s alone
  (14 s of it the per-file name-axis loop with forks per path). Every fresh install
  pays it; install_target_project.bats (5 installs) and t4248_install_init_failure.bats
  (3 installs + fixture clone) inherit it and run 550-730 s alone, 900 s timeout under
  suite load. Candidate fixes: skip vendored framework bytes in the bootstrap scan
  (they are the framework's own, scanned upstream), or scan the bootstrap commit with
  a scoped path list; keep the scan on project files. Evidence: docs/reports/T-4382-bimodal-triage.md.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-4382, T-4377]
origin: {kind: "agent", source: "T-4382"}
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
created: 2026-10-19T15:25:48Z
last_update: 2026-10-19T16:56:23Z
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
  - ts: '2026-10-19T15:30:49Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=287,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-19T15:32:00Z'
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

# T-4400: fw init bootstrap commit secret-scans the whole vendored framework (~92 s per fresh install)

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Baseline measured: scan-staged time over a fresh `fw init` bootstrap index recorded in ## Updates (before)
- [x] The bootstrap commit's scan no longer spends its time on the vendored framework files; after-time recorded (target: scan < 10 s)
- [x] A secret planted in a project-owned file staged in the same bootstrap commit is still caught (regression test)
- [x] No path is exempted: a secret (content and name axis) in a staged `.agentic-framework/` file is still caught (regression test)
- [x] Regression test red before the fix, green after (recorded here)
- [x] tests/unit/upgrade_fresh_machine_simulation.bats and tests/unit/install_target_project.bats green, each run alone
- [x] `python3 tools/bats-dead-negation-lint.py tests/` clean; `bin/fw vendor self --check` clean

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

bash -n agents/git/lib/secret-scan.sh
timeout 600 bats tests/unit/t4400_secret_scan_bootstrap_scale.bats > /tmp/.t4400.out 2>&1 && ! grep -q "^not ok" /tmp/.t4400.out
test "$(grep -c '# skip' /tmp/.t4400.out)" -eq 0
timeout 600 bats tests/unit/test_secret_scan.bats tests/unit/secret_scan_name_axis.bats tests/unit/t4211_secret_scan_no_catalogue_sigpipe.bats tests/unit/t4316_secret_scan_allowlist_union.bats tests/unit/t3665_secret_scan_crlf.bats tests/unit/t3971_secret_scan_no_catalogue.bats > /tmp/.t4400b.out 2>&1 && ! grep -q "^not ok" /tmp/.t4400b.out
python3 tools/bats-dead-negation-lint.py tests/ > /tmp/.t4400l.out 2>&1 && grep -q clean /tmp/.t4400l.out
bin/fw vendor self --check

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

## RCA

**Symptom:** every fresh `fw init` spends 92 s (T-4382, quiet host) to 198 s (this
measurement, loaded host) in the T-000 bootstrap commit's pre-commit secret scan;
install tests inherit it and run 9-12 min.

**Root cause:** three compounding costs in `agents/git/lib/secret-scan.sh`, none of
them in what the scan checks:
- the content-pattern grep ran under the user's UTF-8 locale, where GNU grep's
  multibyte matcher spends 8.4 s on the Azure PAT pattern `[a-z2-7]{52}` over the
  57 MB stream (0.3 s under LC_ALL=C; all 13 patterns < 1.5 s in C).
- `scan_staged` (line ~190) captures the whole staged diff into `diff_stream=$(…)`, then
  `echo "$diff_stream" |` pipes it into `_secret_scan_run_patterns`, which captures it
  AGAIN (`_input=$(cat)`, line ~145) and re-echoes the 57 MB variable once per pattern
  (`echo "$_input" | grep -E`, line ~158) — 77 s measured for the pattern loop.
- the name axis (line ~224) forks 3 processes per newly added path
  (`$(printf | tr)` + `$(_secret_name_classify)`) — 24 s for 3,772 paths.

**Why structurally allowed:** the scanner was written for ordinary commits (a few KB
of diff, a handful of new paths) where both costs are invisible; nothing exercised it
at bootstrap scale with a time bound, and the only symptom was "install tests are slow",
which reads as load rather than as a defect.

**Prevention:** `tests/unit/t4400_secret_scan_bootstrap_scale.bats` stages a
bootstrap-scale commit (thousands of new paths + a multi-MB diff) and bounds scan time,
alongside legs proving a planted secret in a project file and in a vendored file are
still caught in that same commit.

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

### 2026-10-19 — make the scan fast instead of narrowing it
- **Chose:** keep scanning every staged byte and every new path; remove the bash
  overhead (stream the diff through a temp file, grep the file per pattern; classify
  all new paths in one pass with no per-path forks).
- **Why:** measurement showed the regex work itself is < 1 s; the 100 s was pure
  variable/fork overhead. Fixing that keeps the scan's coverage identical (no new trust
  assumption) and speeds up every large commit, not only the bootstrap.
- **Rejected:** (a) skip `.agentic-framework/` files byte-identical to the vendored
  source — needs a trusted reference copy and hashing, adds a trust assumption
  ("framework bytes were scanned upstream"), and a tampered or locally edited vendored
  file would need special handling; (b) scope the bootstrap scan to project-owned paths
  — a blanket path exemption is exactly the weakening the task forbids, and would also
  exempt a secret dropped into `.agentic-framework/` by hand.

### 2026-10-19 — run the catalogue greps under LC_ALL=C
- **Chose:** `LC_ALL=C grep -E` for the content patterns only.
- **Why:** every catalogue regex is ASCII; GNU grep's multibyte matching made one
  pattern cost 8.4 s of 9.6 s. Under C a non-ASCII byte is just a byte, so negated
  classes like `[^[:space:]@]+` match at least as much as before, and invalid UTF-8 no
  longer flips grep into "binary file matches" (which hid the hit line). Accepted edge:
  `[[:space:]]` no longer matches Unicode spaces (e.g. U+2003) inside the AWS secret
  pattern's `key = value` gap — not a shape real credentials files use.
- **Rejected:** dropping or rewriting the Azure PAT regex — that changes coverage.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-19T15:25:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4400-fw-init-bootstrap-commit-secret-scans-th.md
- **Context:** Initial task creation

### 2026-10-19T16:56:23Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-10-19 — baseline measurement (before)
- `bin/fw init` into a fresh git repo (loaded host): 4m16s wall; bootstrap commit staged 3,772 files.
- `secret-scan.sh scan-staged` alone over that bootstrap index (HEAD unset, same staging): **3m18s** wall.
- Breakdown: name axis 24 s; diff+awk 2 s; pattern loop 77 s (13 patterns). Each grep on the
  57 MB stream as a FILE: 24-347 ms, < 1 s total — the cost is variable capture/echo, not regex.
  CORRECTION: those per-grep numbers came from the agent harness's `grep` shell function
  (ugrep). Real `/usr/bin/grep` under en_US.UTF-8 spends 8.4 s on the Azure PAT pattern
  `[a-z2-7]{52}` alone (0.3 s under LC_ALL=C); the other 12 patterns are < 0.25 s each.

### 2026-10-19 — after
- Step 1 (temp file instead of variables + fork-free name axis): scan-staged 198 s → 15 s.
- Step 2 (`LC_ALL=C` on the pattern grep): **3.3 s** (two runs, same 3,772-file bootstrap index).
- `bin/fw init` end-to-end into a fresh repo: 4m16s → **31 s** wall (load avg ~12-19 both times;
  bootstrap commit still created, 3,777 files).
- Regression test `tests/unit/t4400_secret_scan_bootstrap_scale.bats`: BEFORE fix
  `not ok 1 … scans within 30 s` (took 66 s), legs 2-4 ok; AFTER fix 4/4 ok, 0 skips.
- Neighbouring secret-scan suites (test_secret_scan, name_axis, span_rule, t3665, t3971,
  t4211, t4316): 72/72 ok after the fix.
- Consumer-facing, each alone: install_target_project.bats 5/5 ok (9m22s wall, sys 7m —
  load avg 12-19, other workers running); upgrade_fresh_machine_simulation.bats 16/16 ok,
  0 skips (12m8s). The scan is no longer what these suites spend their time on; the time
  left is elsewhere in install (sys-heavy: copying/cloning). Not measured here; out of scope.
- dead-negation lint clean; `bin/fw vendor self --check` clean.
