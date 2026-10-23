---
id: T-4695
name: "Cron-written generated files stay modified and uncommitted (docs/generated/components
  x35, .context/working x22, monitors, audit LATEST snapshots): commit them from their
  writers or stop tracking them"
description: >
  Operator 2026-10-23: file it. After the T-4676 (estimator sweeps commit their own
  writes) and T-4694 (episodic) fixes, ~87 tracked files are still modified in a live
  session, all written by scheduled jobs: docs/generated/components (35), .context/working
  (22), .context/monitors (4), .context/audits/{unit-suite,integration-suite,...}
  LATEST/timing snapshots, .context/project (2), .context/sidecar (1). For each writer
  decide (record in ## Decisions per class): (a) the job commits its own output like
  T-4676 (one commit per run, own task id, only its files, skip files with foreign
  edits), or (b) the file is derived state that should not be tracked (gitignore +
  git rm --cached, keeping anything audits read from git history). Add a rail: after
  a cron job runs, the files it wrote are either committed or ignored. Do not touch
  .tasks/.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/audit/audit.sh]
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
created: 2026-10-23T13:57:26Z
last_update: 2026-10-23T14:18:42Z
date_finished: 2026-10-23T14:18:42Z
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
  - ts: '2026-10-23T13:58:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-10-23T14:15:26Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=333,acs=5)
    rubric_sha: e4a00f38e801
---

# T-4695: Cron-written generated files stay modified and uncommitted (docs/generated/components x35, .context/working x22, monitors, audit LATEST snapshots): commit them from their writers or stop tracking them

## Context

050 be.9 field report (sidecar ac57ecb6): in a framework clone used as an upgrade SOURCE, even the dry run modifies the TRACKED `.context/working/.verb-counter` (tracked at v1.8.15-be.9 together with `.verb-counter.lock`), so T-4688's byte-identical promise fails on `git status`. Any runtime counter/lock that `fw` writes on every invocation must not be tracked in the framework repo either.

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every class of cron-written tracked file named in the description (docs/generated/components, .context/working, .context/monitors, .context/audits LATEST/timing/runs snapshots, .context/project, .context/sidecar) has its writer identified and a per-class decision (a) commit-from-writer or (b) untrack+gitignore recorded in ## Decisions with the reason
- [x] Class decisions are applied: (a) classes commit through the T-4676 committing helper; (b) classes are gitignored and removed from the index with `git rm --cached` (files stay on disk)
- [x] A rail exists that reports a tracked, cron-written file left modified-and-uncommitted (neither committed nor ignored), with a regression test that fails when such a file exists and passes when it is committed or ignored

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
#
# Vendored-path hint (T-3236, T-4419): if you edited bin/fw, lib/, agents/, policy/,
# web/, tools/ or .tasks/templates/, run `bin/fw vendor self` and add
#     bin/fw vendor self --check --task T-XXXX
# (your own task id). It checks only the files your commits changed, so another
# worker's uncommitted edit does not block your close; that drift is listed as
# "in flight, not this task". The whole-tree `--check` stays for audit/pre-push.
python3 lib/cron_commit.py selftest > /tmp/.t4695-selftest.out 2>&1 && grep -q "PASS rail clean once committed and untracked" /tmp/.t4695-selftest.out && ! grep -q "^FAIL" /tmp/.t4695-selftest.out
python3 lib/cron_commit.py check > /tmp/.t4695-check.out 2>&1
test -z "$(git ls-files .context/monitors .context/project/metrics-history.yaml .context/audits/unit-suite/LATEST.yaml .context/working/.hook-counter .context/working/watchtower.pid)"
git ls-files --error-unmatch .context/audits/unit-suite/baseline.yaml .context/working/focus.yaml .context/working/.gate-bypass-log.yaml >/dev/null
python3 -c "import yaml; d={j['id']:j for j in yaml.safe_load(open('.context/cron-registry.yaml'))['jobs']}; assert d['docs-daily']['commit_paths'] and 'cron_commit.py run --job docs-daily' in d['docs-daily']['command']"
grep -q "cron_commit.py run --job docs-daily" .context/cron/agentic-audit.crontab
bash -n agents/audit/audit.sh
out=$(bin/fw doctor 2>&1); echo "$out" | grep -q "Cron registry in sync" && ! echo "$out" | grep -q "Cron registry edited but not generated"
bin/fw vendor self --check --task T-4695

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

**Symptom:** ~87 tracked files modified and uncommitted in a live session, all written by scheduled jobs or hooks: docs/generated/components (35), .context/working (22), .context/monitors (4), audit LATEST/timing/runs snapshots, .context/project (2). Broad commits by unrelated tasks later swept them in (e.g. T-3514 committing unit-suite LATEST and the T-1549 report).

**Root cause:** two independent gaps. (1) Jobs that produce reviewed, repo-worthy output never commit it: `docs-daily` runs `fw docs --all` (agents/docgen/generate-component.sh:21 writes docs/generated/components) and `escalation-drift-daily` runs tools/escalation-scan-v0.py (writes docs/reports/T-1549-escalation-scan-v0.md); the registry entry is just the command (.context/cron-registry.yaml docs-daily / escalation-drift-daily) and nothing after it stages or commits. (2) Per-host runtime output was committed once and stayed tracked: an ignore rule does not untrack a file. The framework repo's own .context/working/.gitignore never received the T-4231 ruleset (lib/working-gitignore.sh:25 `fw_working_ignore_rules`) because that list is only applied to consumers by `fw init`/`fw upgrade` (lib/init.sh:414, lib/upgrade.sh:3158), and the monitors, suite reports, audit snapshots and metrics-history had no ignore rule at all.

**Why structurally allowed:** no rail tied a cron job to what it writes. T-4676 fixed the estimator sweeps inside estimator.py only; T-4689's working-ignore-rail checks the consumer ignore list against writers, not the framework repo's tracked set; the uncommitted-changes audit rail cannot tell a job's output from a session's edit.

**Prevention:** jobs declare their outputs in the registry (`commit_task`+`commit_paths` → wrapped in `lib/cron_commit.py run`, which commits them; `ignore_paths` → must be untracked). `python3 lib/cron_commit.py check`, run by `fw audit` as `check_cron_output_hygiene` (WARN), flags a declared commit output still modified 26h after it was written and any tracked file matching a job's ignore_paths. `python3 lib/cron_commit.py selftest` pins both directions in a temp repo.

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

### 2026-10-23 — per-class decision (a) commit-from-writer vs (b) untrack + gitignore
Readers checked first: no code reads any of these files from git history (grep of lib/ agents/ bin/ web/ tools/ for git log/show/diff on these paths: none). Audit, Watchtower and the suite grader read them from disk; the only git-HEAD read is unit_suite_baseline.py on baseline.yaml, which stays tracked.
- **docs/generated/components** — writer `docs-daily` (`fw docs --all`, agents/docgen/generate-component.sh). **(a)**: reviewed documentation whose diffs are real content changes. Command wrapped in `lib/cron_commit.py run --job docs-daily`, `commit_task: T-387`. The 35 files dirty now are committed once under T-4695 (the wrapper skips pre-dirty files by design).
- **docs/reports/T-1549-escalation-scan-v0.md** — writer `escalation-drift-daily` (tools/escalation-scan-v0.py). **(a)**: a human-readable report historically committed (38 commits). Wrapped, `commit_task: T-1555`. Its machine summary `.context/working/escalation-drift-LATEST.yaml` is **(b)**.
- **.context/working runtime files** (counters, locks, pids/url/port, logs, cursors, `.mirror-sync.log`, `.fabric-describe.last`, `continuous-run.jsonl`, ...) — writers: mirror-sync-15m, fabric-describe-daily, hooks, Watchtower. **(b)**: per-host runtime state. Applied the existing consumer ruleset to the framework repo itself (`fw_working_ensure_ignored`, same list `fw upgrade` writes) and `git rm --cached` the 61 matched files (98 untracked in total across classes). Kept tracked: `focus.yaml`, `session.yaml` (deliberately tracked per .gitignore T-3038 note), `qa_feedback.db`, `.gate-bypass-log.yaml`, `happiness.jsonl` (on `fw_working_keep_tracked`: records a project keeps). Those are session/hook-written, not cron output, and out of this rail's scope.
- **.context/monitors/** — writers liveness-1m, watchtower-rss-5m. **(b)**: per-host samples (liveness.jsonl grew 1680 lines in a day).
- **.context/audits snapshots** (full-audit-timing, orchestrator-LATEST, discoveries/LATEST, cron/LATEST-CRON, go-scope-unpropagated/LATEST.md, unclosed-satisfied/LATEST.md) — writer `fw audit --cron` (attributed to full-daily; every audit cron rewrites some of them). **(b)**: regenerated each run, read from disk.
- **.context/audits/{unit,integration}-suite** LATEST, LAST-COMPLETE, runs.log, dated `2*.yaml` — writers unit-suite-nightly / integration-suite-nightly. **(b)**: the grader reads them from disk; a missing report is a WARN, not a failure (audit.sh check_unit_suite_report). `baseline.yaml` stays tracked (operator-owned, append-checked against git HEAD).
- **.context/project/metrics-history.yaml** — writer agents/audit/audit.sh; Watchtower reads it from disk (web/metrics_history.py). **(b)**: a per-host time series.
- **.context/project/decisions.yaml** — not cron output: written by decision capture at task completion (agents/context/lib/decision.sh / extract_decisions.py). **(a)**, but the writer runs inside the closing session, so the fix belongs in the close path, not the cron wrapper. Catch-up committed here (406 lines of auto-captured decisions since 2026-10-11 were in no commit); the writer-side fix is left open (reported to parent).
- **.context/sidecar/.gitignore** — writer lib/sidecar/lifecycle.py:100 `_ensure_runtime_ignored`, which appends missing T-4231 rules (idempotent, append-missing). **(a)** one catch-up commit: the rules are legitimate and once committed the writer finds nothing missing and stops touching the file. Its new `hub-id` rule matched a tracked file, so `.context/sidecar/hub-id` (per-host hub cache) is **(b)**, untracked.
- **Helper reuse:** T-4676's `_commit_sweep_writes` is private to estimator.py and scoped to `.tasks/`. `lib/cron_commit.py` generalises it with the same semantics (snapshot pre-dirty, commit only what the run wrote with `git commit -- <paths>`, index.lock retry, exit 1 on commit failure). estimator.py left unchanged so its tests (tests/unit/test_t4676_sweep_self_commit.py) are untouched.
- **Rejected:** wrapping every job in the generator (`fw cron generate` in bin/fw) — would change all 34 lines and route read-only jobs through a commit step; per-job opt-in through the registry command is narrower. Rejected a global "tracked ∩ ignored" rail: 66 intentionally force-added review evidence files would fire it.
- **Regression test location:** the parent reserved tests/ for T-4696, so the check is `lib/cron_commit.py selftest` (temp git repo, 7 cases). A tests/unit wrapper calling it can be added once T-4696 lands.
- **Crontab install:** `bin/fw cron generate` was run; the installed /etc/cron.d copy differs until the operator runs `bin/fw cron install` (doctor: "Cron registry drift"). The doctor verification line stays red until then.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-10-23T13:57:26Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4695-cron-written-generated-files-stay-modifi.md
- **Context:** Initial task creation

### 2026-10-23T13:58:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0f8907b6
- **Timestamp:** 2026-10-23T14:20:04Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#2 (Human)** — [REVIEWER] Block message names both bypass mechanisms
  - **reviewer-prose-mismatch** (partial, heuristic) — `matched='reads' in: Verdict: PASS; no findings on `block-message-completeness``

**Verification-level findings:**

  1. **empty-output-success** (partial, heuristic) @ Verification:line 139
     - evidence: `git ls-files --error-unmatch .context/audits/unit-suite/baseline.yaml .context/working/focus.yaml .context/working/.gate-bypass-log.yaml >/dev/null`

### 2026-10-23T14:18:42Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
