---
id: T-4385
name: "Defuse the 2026-10-31 baseline cliff: triage the 22 always-red tests (fix,
  quarantine with an owner, or delete with evidence) and stagger expiries"
description: >
  32 of 44 baseline entries expire 2026-10-31; T-3747's already expired; 22 tests
  are red in 20/20 reports and can catch nothing. Each always-red test gets an outcome;
  adding to the baseline stays operator-only. Arc test-suite-health (arc-026); source:
  external review T-4376 (docs/reports/T-4376-reviews/).

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
created: 2026-10-19T12:29:07Z
last_update: 2026-10-19T14:55:35Z
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
  - ts: '2026-10-19T12:30:40Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=287,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-10-19T12:31:39Z'
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

# T-4385: Defuse the 2026-10-31 baseline cliff: triage the 22 always-red tests (fix, quarantine with an owner, or delete with evidence) and stagger expiries

## Context

44 baseline entries (28 files) in `.context/audits/unit-suite/baseline.yaml`; triage
ledger with per-file cause, outcome, and red-before/green-after evidence:
`docs/reports/T-4385-baseline-triage.md`. Source: docs/reports/T-4376-test-suite-measurement.md §3.3.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] Every one of the 28 baselined files has a row in `docs/reports/T-4385-baseline-triage.md` naming: result when run alone today, cause (file:line), and one outcome — `fixed` / `defect T-XXXX` / `deleted (reason)` / `green-alone (load-only)` / `stays (proposed expiry+owner)`
- [ ] Every `fixed` test is red before the change and green after when run alone, both results recorded in the triage report; no fix weakens an assertion so that it no longer fails on its origin bug (fault-detection-fidelity)
- [x] Each real product defect found has its own captured task (one bug = one task), referenced from the triage row
- [x] Entries that must stay are listed in `## Proposed baseline changes` below with a proposed new expiry (staggered, not one cliff day) and owner, plus a single `fw runme` line the operator can run; the agent did NOT run `unit_suite_baseline.py add` and did not edit `baseline.yaml`
- [x] `bash -n` clean on every edited shell file; `bin/fw vendor self --check` clean (or red only on other workers' in-flight files, named) — no shell/lib/vendored path edited (tests/ + docs/ only); 2026-10-19 `--check` red only on `tools/corpus_spec.py`, another worker's uncommitted edit, not synced

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

test -f docs/reports/T-4385-baseline-triage.md
for f in $(grep -oE "file: [^ ]+" .context/audits/unit-suite/baseline.yaml | awk '{print $2}' | sort -u); do grep -q "$f" docs/reports/T-4385-baseline-triage.md || { echo "missing $f"; exit 1; }; done
git diff --quiet HEAD -- .context/audits/unit-suite/baseline.yaml
bats tests/unit/handover_push_timeout.bats
bats tests/unit/check_render_surface_human_ac_sigpipe.bats
bats tests/unit/t2298_audit_structure_no_perfile_fork.bats
bats tests/unit/t2244_audit_self_vendor_drift.bats
bats tests/unit/test_cron_registry_generated_drift.bats
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

**Symptom:** 32 of 44 baseline entries expire on 2026-10-31 and 22 tests are red in 20/20
suite reports. On expiry every one of them turns into a pre-push FAIL on the same day.

**Root cause:** two separate things.
(1) *The cliff:* `unit_suite_baseline.py cmd_add` (`agents/audit/unit_suite_baseline.py:220`)
sets expiry to `today + --days`, and the catch-up re-arm (runme `t4221-extend-baseline`,
2026-10-17) re-armed all 28 expired reds in one run, each with `--days 14`, so every entry
got the same day as its deadline. The original batch (all added 2026-10-01, 14 days) had
already fallen due together on 2026-10-15, so 10-31 is the second cliff of the same shape.
(2) *The always-red core:* 7 of the 22 were test-side. The tests pinned wording or structure
that later commits changed on purpose: T-3063 (`handover.sh:229`), T-3450 (`handover.sh:159`),
the checkpoint `bash` prefix (`checkpoint.sh:299`), T-3099's rename in the audit.sh T-2096
block, and T-2436's mitigation wording (`audit.sh:3405`). Or they ran a ~690 s live audit
twice (`t2244`, `audit.bats`). The other 16 are correct tests on real product defects that
already had owner tasks (T-3611, T-3609, T-3615, T-3612, T-3614, T-3632, T-3605) but no
horizon pressure. Off the always-red list, three more were test-side: the sigpipe sentinel
relied on a race (2/20), and the cron test inferred severity from doctor's whole exit code,
which T-3783's vector-index FAILs moved to 2 (17/20).

**Why structurally allowed:** a baselined red grades WARN, so nothing escalates while it is
baselined. A commit that changes the pinned string never runs the pinning test (it runs only
nightly, in a 900 s per-file pool), and the owner tasks sat at `captured`/`horizon: next`.
Nothing tied an entry's expiry to the size of its fix.

**Prevention:** (a) the stale tests now pin the invariant rather than the wording, and the
two live-audit tests became hermetic, so they're quick and no longer read shared state;
(b) the proposed re-arm staggers expiries by fix size (7–25 days, below), so at most a few
entries fall due on any one day; (c) re-owning: T-4221 → T-3632 / T-4325 and completed
T-2787 → T-4325, so every remaining entry points at a live task.

## Proposed baseline changes

Operator-only (`add --i-am-human`). The agent did not run it and did not edit `baseline.yaml`.
`--days` is counted from the day the script runs; the dates below assume it runs 2026-10-19.

| Entries | File | Owner (new) | Expires | Why this date |
|---:|---|---|---|---|
| 1 | atomic_yaml_write_lint.bats | T-3612 | 2026-10-26 | one-file atomic write |
| 5 | approvals_close_ready_arcs.bats | T-3611 | 2026-10-28 | catch SystemExit, one site |
| 1 | test_bin_fw_no_heredoc_cmd_sub.bats | T-3632 (was T-4221) | 2026-10-30 | two bin/fw sites |
| 3 | doctor_hook_counters.bats | T-3615 | 2026-11-02 | re-route Stop hook + parity |
| 4 | audit_inception_recommendation / lib_review (2) / review_pipefail | T-3609 | 2026-11-04 | needs a decision (honour or retire the env) |
| 1 | audit_split_root_asset_lint.bats | T-3614 | 2026-11-06 | 8 sites to disposition |
| 1 | test_operator_facing_stderr.py | T-3605 (+T-4407) | 2026-11-09 | two web/ sites + Watchtower restart |
| 4 | t1719_index_one_post_write, t3662, t4119, no_root_framework_markers | T-4325 (was T-4221 / T-2787) | 2026-11-11 | load-only: green alone |
| 1 | t2243_doctor_self_vendor_templates.bats (expired 10-18) | T-4325 (was T-3747) | 2026-11-13 | load-only: green alone |

Left alone: the 10 entries fixed here plus context_safe_commands (fixed by T-4368), which
`regenerate` drops after the next full green report; fw_focus_alias, t1719_ask_routing, audit,
hook_telemetry_race (T-4325), t2452 (T-3992), fw_mode_detection (T-4038) and
test_doctor_litellm_ollama (T-4138), which are already staggered between 10-22 and 11-01; and
fabric_coverage_single_source, which another worker has in flight.

One line (generated with `fw runme new`, not run):

    bash /opt/999-Agentic-Engineering-Framework/.context/runme/t4385-baseline-rearm/runme.sh

## Evolution

### 2026-10-19 — the cliff is mostly owned defects, not broken tests
- **What changed:** at filing, "22 always-red tests" read as 22 tests that cannot pass. Run alone, 6 of the 22 were stale/slow tests (fixed here), and 16 are correct tests on real product defects, each already with an owner task.
- **Plan impact:** "fix it or delete it" covers only the test-side third. The rest needs the owner tasks to move (they sit at captured/next) plus staggered re-arms, which is the operator's call.
- **Triggered:** T-4407 (second stderr site, approvals.py:643); proposed re-own of T-4221's and T-2787's entries.

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

## Updates

### 2026-10-19T12:29:07Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-4385-defuse-the-2026-10-31-baseline-cliff-tri.md
- **Context:** Initial task creation

### 2026-10-19T14:55:35Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
