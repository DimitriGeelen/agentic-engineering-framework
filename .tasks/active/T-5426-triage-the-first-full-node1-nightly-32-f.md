---
id: T-5426
name: "Triage the first full node1 nightly: 32 failed + 1 timeout not seen on the
  local fast tier"
description: >
  Run 202611260233 (commit deff203f7, 1770 submitted, 1737 passed). Reds cluster on
  version/tag checks (fw_version_output, pre_push_version_monotonicity, version_relation,
  test_pre_push_monotonic_ancestor), upgrade/vendor simulations (t2762, t3965, t4568,
  t4678, upgrade_fresh_machine_simulation, t4705 timeout) and gates (t3454, t3457).
  Hypothesis: the test bundle lacks git tags/history or the host differs; decide per
  file: fix the test, fix the bundle, or add to node1-incompatible.txt with a reason.
  Logs are not kept in the report, so re-run single files with --only once node1's
  canary is healthy again.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [node1, unit-suite]
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
created: 2026-11-26T15:47:57Z
last_update: 2026-11-28T10:25:26Z
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
  - ts: '2026-11-26T16:00:29Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? 
      (no-components-no-fabric-paths-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=303,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-11-26T16:00:58Z'
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
---

# T-5426: Triage the first full node1 nightly: 32 failed + 1 timeout not seen on the local fast tier

## Context

<!-- All four parts are required before source edits (T-4907). Plain language; link design docs for substantial tasks. -->
**Background / trigger:** The first complete node1 nightly (run 202611260233, commit deff203f7) ran 1770 test files: 1737 passed, 32 failed, 1 timed out; the 2026-11-27 run gave 34 failed, 1 timeout. All are "new" because there is no node1 baseline. The report keeps no per-file logs, and node1 has been reported unhealthy since 2026-11-26, so re-running files there is on hold.

**Problem / hypothesis:** The reds cluster on version/tag checks, upgrade/vendor simulations and a few gates. The bundle node1 runs (lib/test-bundle.sh) is ONE commit with no history and no tags, and no .context state. Tests that read git tags, history or local state fail there for reasons that say nothing about the code.

**Goal:** Classify each red by reproducing it locally inside a clone of the same bundle: fix the test (host or history assumption), fix the bundle (if many tests legitimately need something it drops), or list the file in scripts/node1/node1-incompatible.txt with a reason.

**Expected outcome:** Every red from the latest node1 report has a recorded cause and disposition; the next nightly's reds are only real failures.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] The bundle-clone reproduction is recorded: which of the node1 reds fail there, and the cause class of each (no tags/history, missing state, host tool, real failure)
- [x] Each red has a disposition recorded in this task: test fixed, bundle changed, or excluded in node1-incompatible.txt with its reason
- [x] The dispositions are applied and the affected files pass in the bundle clone (or are excluded with a reason)

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

python3 -c "import os; ls=[l.strip() for l in open('scripts/node1/node1-incompatible.txt') if l.strip() and not l.startswith('#')]; assert ls and all(os.path.isfile(l) for l in ls), [l for l in ls if not os.path.isfile(l)]; assert len(ls)==len(set(ls))"
python3 scripts/node1/node1_nightly.py --dry-run > /tmp/.t5426_dry 2>&1 && grep -q "excluded=" /tmp/.t5426_dry
timeout 300 bats tests/unit/t4813_doctor_hook_paths.bats > /tmp/.t5426_a 2>&1 && ! grep -q "^not ok" /tmp/.t5426_a
test "$(grep -c '# skip' /tmp/.t5426_a)" -eq 0
timeout 300 bats tests/unit/t3768_boundary_quoted_read_paths.bats > /tmp/.t5426_b 2>&1 && ! grep -q "^not ok" /tmp/.t5426_b
test "$(grep -c '# skip' /tmp/.t5426_b)" -eq 0

<!-- T-4906: guidance is an HTML comment so GitHub does not render its `#` lines as
     headings; the completion gate strips HTML comments before running anything.
     Write your commands BELOW this comment, one per line.
# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# The completion gate runs each command — if any exits non-zero, completion is blocked.
# End a line with `# needs: fixture` if it must not be re-run unattended later by the audit (CTL-013, verify-queue); the gate still runs it (T-5268).
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
# THE EXCEPTION — capture first, grep the capture with a HERE-STRING:
#     out=$(cmd 2>&1); grep -q "PATTERN" <<<"$out"
# No pipe, so no SIGPIPE at any size. Do NOT write `echo "$out" | grep -q PAT`:
# it is not safe "below 64 KB" as this file used to say (T-4921, 832 T-1340). The
# builtin writes a multi-line value line by line, so grep -q can exit before the
# last write at ANY size (measured 4 in 3,000 for a 40-line value), and above the
# pipe buffer it fails every time (T-2743: 146,366-byte page, 3/3). In a gate that
# allows on "no match" that is a fail-OPEN (T-4920: the Tier 0 pre-filter).
# The capture still discards cmd's exit code, so a 404 yields an empty capture that
# grep merely fails to match rather than a failed line — prefer THE DEFAULT above.
#
# TEST RUNNERS need a guard either way (T-2738). `set -e` is suppressed inside the
# `if` condition the gate runs each line in, so in `cmd1; cmd2` only cmd2 is the
# verdict — and the pass marker you grep for survives a partial failure: a suite
# printing "3 failed, 9 passed" satisfies `grep -q "9 passed"`, and generalising
# to `grep -qE "[0-9]+ passed"` matches the same output. Keep the exit code:
#     python3 -m pytest <file> -q > /tmp/.out 2>&1 && grep -q passed /tmp/.out
# or add the guard the exit code used to supply:
#     out=$(python3 -m pytest <file> -q 2>&1); grep -q passed <<<"$out" && ! grep -q failed <<<"$out"
#     out=$(bats <file> 2>&1); grep -q '^ok 1 ' <<<"$out" && ! grep -q '^not ok' <<<"$out"
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
-->

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

**Symptom:** the first full node1 nightlies reported 32-35 red files, all "new", none red in the local nightly.

**Root cause:** node1 runs a one-commit bundle clone (no history, no tags, no installed git hooks, no .context state such as the vector index) in a temp dir on a shared, loaded host. 16 files read git history or tags, 6 copy or grep this checkout's installed hooks, 3 have individual environment causes (vector index, temp-dir checkout, a 3 s wall-clock budget). One was a real stale test: t4813 test 5, red on this repo too since T-5302 changed doctor's advice to a full `cd <root> && .agentic-framework/bin/fw upgrade` line; its sibling negative check (test 4) had gone vacuous for the same reason. t3768 test 5 assumed the checkout sits two levels deep (`../../`).

**Why structurally allowed:** node1-incompatible.txt was built from the earlier partial batches; the first complete run is the first time every file met the bundle. The local nightly runs in the full checkout, so history, hook and depth assumptions are invisible there.

**Prevention:** every exclusion carries its class and reason, so a file can be re-admitted when its cause goes (class B by one setup step, see Dispositions). The two fixed tests no longer depend on the host path or the old advice wording. t4259's intermittent teardown race is tracked as T-5440 instead of excluded, so node1 keeps seeing it.

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Reproduction (2026-11-28)

Bundle built exactly as node1 gets it (`bin/fw test bundle --ref HEAD`), cloned (1 commit, 0 tags), and the 35 files from the latest node1 report (run 202611270233) run inside it with a 300 s cap each. Result: 28 fail here too, 7 pass (doctor_hook_counters, hook_version_marker_parity, t5032_grant_links, t5403_hook_wiring, test_t5198_handoff_blockers, test_t5236_profile_remediation, upgrade_fresh_machine_simulation: node1-only, recheck once node1 is healthy), t4705 times out as on node1. Repo history is 510 MB against node1's 64 MB bundle cap, so shipping history is not an option.

| Class | Files | First failure | Disposition |
|---|---|---|---|
| A. needs git history/tags (the bundle is one commit) | fw_version_output, version_relation, t2762, t3453, t3454, t3457, t3965, t4232, t4568, t4678, t4705, t5217, test_testhost_controller, test_upgrade_template_sync_t3955 (+ confirm test_tier0_origin, test_t5193) | `HEAD~5`, `git show <old ref>`, `git archive <tag>`, ancestry → exit 128 | node1-incompatible.txt, reason "needs git history" (they run in the local nightly and CI with full history) |
| B. reads this checkout's installed git hooks | pre_push_version_monotonicity, t2240, t2294, test_pre_push_monotonic_ancestor, test_secret_scan | `cp "$FRAMEWORK_ROOT/.git/hooks/pre-push"` fails: a bundle checkout has no framework hooks | install hooks in the node1 run setup if possible, else exclude with reason |
| C. individual | t5221 (timing < 3 s), t4259 (teardown rm race), t4813 (remedy wording), test_index_doctor_rail, t3768, test_cockpit_activity | see logs | investigate each: fix the test or exclude with reason |

### Dispositions (2026-11-28, worker w-t5426)

All 35 files re-run in a fresh bundle clone with `env -u CLAUDECODE -u FRAMEWORK_ROOT -u PROJECT_ROOT` (the spec's clean-env rule; the first run above inherited them). Same reds, except t4259 and t5221 passed.

| File(s) | Cause (verified) | Disposition |
|---|---|---|
| fw_version_output, version_relation, t2762, t3453, t3454, t3457, t3965, t4232, t4568, t4678, t4705, t5217, test_testhost_controller, test_upgrade_template_sync_t3955, test_t5193_runtime_projection_v2, test_cockpit_activity | `git show <old sha>`, tag `v1.8.15-be.11`, `HEAD~1`, `git log` of a path, commits that reference tasks: none exist in a one-commit bundle | excluded, class A (16) |
| pre_push_version_monotonicity, t2240, t2294, test_pre_push_monotonic_ancestor, test_secret_scan, test_index_doctor_rail | copy or grep `$FRAMEWORK_ROOT/.git/hooks/*`; all 6 pass after `bin/fw git install-hooks` in the clone (offline, no root, exit 0) | excluded, class B (6) |
| t1719_ask_routing (test 11) | fails "no vector index at .context/working/fw-vec-index.db" before the ollama path it pins | excluded |
| test_tier0_origin | precondition `is_sandbox(root) is False`; a checkout under a temp dir is a sandbox by design (node1's clone is in one too) | excluded |
| t5221_create_batch (test 13) | 3 s wall-clock budget: 3404 ms in the first bundle run, 1912-2373 ms in five reruns (bundle and repo), host load ~22 on 24 cores; nothing bundle-specific | excluded (CPU speed) |
| t4813_doctor_hook_paths (test 5) | stale test, red on this repo too: since T-5302 the advice is `Run: cd <root> && .agentic-framework/bin/fw upgrade (regenerates hooks…` | test fixed (also test 4's vacuous negative check) |
| t3768_boundary_quoted_read_paths (test 5) | `../../root` assumed /opt/<repo>; from a deeper clone it resolved under /tmp (allowed) | test fixed: climbs to / from the real depth |
| t4259_init_cron_generated | teardown `rm -rf` raced a writer under the fixture's .git; passed in the clean rerun and 4 more | kept; follow-up T-5440 |
| doctor_hook_counters, hook_version_marker_parity, t5032, t5403, test_t5198, test_t5236, upgrade_fresh_machine_simulation | pass in the bundle clone | kept; node1-only, recheck once node1 is healthy |

Final check: every kept file passes in a fresh bundle clone (fixed tests copied in), and the fixed tests pass on this repo.

**Class B proposal (not applied):** the node1 entry could run `bin/fw git install-hooks` in `repo/` after the clone; it needs no network or root and makes all six pass, so they could come off the list.

## Updates

### 2026-11-26T15:47:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-5426-triage-the-first-full-node1-nightly-32-f.md
- **Context:** Initial task creation

### 2026-11-28T09:31:50Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
