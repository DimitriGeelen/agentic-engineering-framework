---
id: T-3580
name: "T-3557 slice 3: fw reviewer judge - dispatch an independent interpreting reviewer
  on a criterion, rung chosen by the IW-7 impact-risk model"
description: >
  T-3557 GO. The interpreting reviewer used by hand 2026-09-29/30 (render reviews,
  escalation spike 10/10 per key) becomes a verb: fw reviewer judge T-XXX [--criterion
  N] dispatches a TermLink reviewer that is not the producer, gives it the criterion
  + evidence (screenshots for render criteria), and writes the slice-2 verdict record.
  Rung per IW-7: hard human gate recognised and escalated; else impact=max(cost_if_wrong,
  value_at_stake) picks rung 1-2 (same-vendor independent) / 3-4 (different model)
  / 5-7 (3-vendor panel); weekly spend ceiling degrades one rung and says so.

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
created: 2026-09-30T07:54:10Z
last_update: '2026-09-30T21:45:18Z'
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
  - ts: '2026-09-30T08:00:13Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=277,acs=9)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-30T08:00:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-09-30T21:45:18Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=2 (body:env-class-handled); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=? 
      (unscored (no scorer for F3; not counted)); F1=? (unscored (no scorer for 
      F1; not counted)); F2=? (unscored (no scorer for F2; not counted))
    rubric_sha: e4a00f38e801
---

# T-3580: T-3557 slice 3: fw reviewer judge - dispatch an independent interpreting reviewer on a criterion, rung chosen by the IW-7 impact-risk model

## Context

Build slice 3 of T-3557. Depends on T-3578 (routing) and T-3579 (verdict records). It turns
the manual reviews of 2026-09-29/30 into a verb: render reviews (docs/reports/T-3557-render-
review-2026-09-29.md, T-3564-render-review.md, T-3574-T-3575-render-review.md) and the
escalation spike (T-3557-spike-prompt.md / -verdicts.md). The spike prompt is the proven
reviewer brief; reuse it rather than writing a new one.

### Worker attribution requirements (from T-3581 round 3; slice 3 must meet these)

T-3581 proves that a verdict row names a review dispatch the dispatcher registered for this
task, that the reviewer/worker/introducing-commit identities are not producers, and that the
ledger history is append-only. It does NOT prove the registered worker authored the verdict:
a registration is evidence of registration. Slice 3 must bind the following to the dispatch
RESULT (the completion the worker itself posts, e.g. on the fw bus), and `verdict record`
/ `_row_fault` must verify them before a row can count:

1. **Fresh worker/session identity** — the session that ran the review is new (not the
   producer's or issuer's session), recorded in the dispatch result, and matches the identity
   the row's `reviewer` and the commit that introduces the row are attributed to.
2. **Reviewed revision** — the git revision (HEAD sha) of the repo the worker reviewed,
   recorded in the result and in the row; the row is refused if the task's criterion or the
   evidence it cites is not at that revision.
3. **Criterion digest** — the digest the worker read, in the result, equal to the row's `ac_digest`.
4. **Evidence** — the evidence paths (with content hashes) in the result equal the row's evidence.
5. **Exact verdict contents** — a hash over the canonical row body (outcome, guidance,
   evidence, digest, revision) is part of the signed dispatch result; a row whose bytes differ
   from what the worker reported is refused.
6. **Completion and commit attribution** — the dispatch is recorded as COMPLETED by that
   worker (a registration alone is not enough), and the commit introducing the row is
   attributed to that worker identity, not merely to a non-producer.

The producer may still be the dispatch ISSUER (T-3581 Decisions). Same-user residual gap:
an agent that reads .context/secrets/review-dispatch.key can still sign a coherent result;
this list makes that a deliberate forgery rather than an unattributed append, and is not a
claim of forgery resistance. Do not build this in T-3581.

### Cost system integration (T-3583, for round 3)

The judge must read backends from `policy/review-backends.yaml` (no hardcoded vendor list)
and log a cost record for each seat via `fw review cost log --task T-XXX --backend ID ...`.
When the chosen rung requires a paid backend (OpenRouter), emit a proposal instead of
dispatching: `fw review propose --backend openrouter --task T-XXX --why "..."`.

## Acceptance Criteria

### Agent
- [x] `fw reviewer judge T-XXX [--criterion N] [--dry-run]` selects the task's open REVIEWER_JUDGES criteria, builds a reviewer brief (the spike prompt shape: role, the operator's risk rule, verdict contract, evidence), and dispatches it via `fw termlink dispatch` to a worker that is not the producer
- [x] For a render-surface criterion, the verb captures screenshots of the pages the task touched (Playwright) and hands them to the reviewer; if capture fails, the reviewer is told so, and it must not return green on a page it did not see
- [x] The reviewer's output is parsed into T-3579 verdict records, one per criterion; malformed output is recorded as `unknown`, never as green
- [x] Rung selection follows IW-7: criteria in the hard human classes are never dispatched (reported as operator-only); otherwise `impact = max(cost_if_wrong, value_at_stake)` from existing fields (reversibility/blast_radius/consumer paths, BVP/voi) picks rung 1-2 (same-vendor independent agent) or 5-7 (3-vendor panel via codex/opencode/claude, stdin closed); the chosen rung and its reason are in the record
- [x] A weekly spend ceiling is a config key in both registries (lib/config.sh and web/blueprints/config.py); when reached, the rung drops one step and the verdict says so; nothing is silently skipped
- [x] `--dry-run` prints criteria, rung and brief without dispatching; tests cover selection, rung choice, the ceiling and output parsing, with a fake dispatcher
- [ ] Live proof: run it on one real open render criterion, and the resulting record closes it through T-3579 with no bypass flag; `bin/fw vendor self --check` clean

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

python3 -m pytest tests/unit/t3580_judge_cli_test.py tests/unit/t3580_round2_test.py tests/unit/t3580_round3_test.py tests/unit/t3580_round4_test.py tests/unit/t3580_round5_test.py tests/unit/t3580_round6_test.py tests/unit/test_t3579_verdict_ledger.py tests/unit/test_t3581_ledger_integrity.py tests/unit/test_t3581_round4.py -q > /tmp/.t3580-py.out 2>&1 && grep -q passed /tmp/.t3580-py.out
timeout 600 bats tests/unit/t3579_verdict_close_path.bats > /tmp/.t3580-bats.out 2>&1 && ! grep -q "^not ok" /tmp/.t3580-bats.out
test "$(grep -c '# skip' /tmp/.t3580-bats.out)" -eq 0
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

### 2026-09-30 — round 3: who signs the worker completion
- **Chose:** the dispatch runtime (run.sh in agents/termlink/termlink.sh) calls `verdict_ledger.py complete` after `exit_code` is written; it binds session, exit state, result-stream hash, the revision registered at dispatch, and every row the worker left. `record` signs nothing. `complete` refuses inside the worker's environment and before exit; a second completion for a dispatch voids both.
- **Why:** round-2 review (HIGH): a completion built by `record` from its own row is self-asserted.
- **Rejected:** signing inside `record` with a stricter check (still the worker's own act).

### 2026-09-30 — round 3: work that lands after the reviewed revision
- **Chose:** the revision is captured by the judge before dispatch, registered with the dispatch, and used by `record`; a green is refused (at record and at every read) when a commit for the task touching anything outside `.context/` and `.tasks/` landed after it.
- **Rejected:** only re-binding the row to the reviewed sha (a green about code that no longer ships would still close the criterion).

### 2026-09-30 — round 3: seats and paid backends
- **Chose:** seats are the registry's internal backends that declare a `--worker-kind` match; the ones `fw termlink worker-kinds` accepts run, each logging one cost record. A seat no internal backend can fill gets a `fw review propose` on the registry's paid backend and waits; the judge never dispatches it. All seats stay required in the signed run, so the ledger keeps the criterion open.
- **Rejected:** a new registry field for worker kinds (the registry is operator-owned; its `match:` already names the worker kind).

### 2026-09-30 — round 4: completion needs a per-dispatch runtime secret
- **Chose:** `register_dispatch` writes a fresh secret (0600) to `<wdir>/.completion-secret` and registers only its sha256 (signed). run.sh reads it and deletes the file as its first act, never exports it, and passes it to `complete --secret-stdin` after the worker exits. `complete` refuses without it, with a wrong one, or for a dispatch registered without one. It also refuses a worker kind other than the registered one.
- **Why:** round-3 OpenAI HIGH: `complete` is public, and any caller holding a hand-written exit_code file could get a signed completion without the key.
- **Residual (stated, not closed):** a same-user process that reads the wdir between registration and run.sh's first line, or that reads run.sh's memory, can still act. So can one that reads `.context/secrets/review-dispatch.key` and signs a completion itself. This is inside the same-user boundary the operator accepted on T-3581. The secret removes the zero-effort path (write exit_code, call the public command), not a determined same-user forger.
- **Rejected:** a secret in the worker's env or argv (visible to the worker and in `ps`).

### 2026-09-30 — round 4: a vendor is what the dispatcher registered
- **Chose:** termlink.sh maps each worker kind to a vendor (`_worker_vendor`, printed by `worker-kinds --vendors`), and cmd_dispatch registers kind + vendor (signed) with every review dispatch. `_panel_fault` counts distinct VERIFIED registered vendors and refuses a seat with none (`panel-unverified-vendor`). The judge reports `degraded` when the dispatchable seats span fewer vendors than required.
- **Why:** round-3 OpenAI HIGH: three registry backend ids with one `--worker-kind` counted as three vendors.
- **Rejected:** counting worker kinds (two kinds may run one vendor); trusting the bind row's vendor argument (caller-supplied).

### 2026-09-30 — round 4: review waits require a finalised runtime
- **Chose:** cmd_dispatch writes `finalise_required` for review dispatches. run.sh writes `finalised` (signed|unsigned) after `complete` succeeds or fails, and `fw termlink wait` treats a review dispatch as done only when that marker exists. Non-review dispatches are unchanged.
- **Why:** round-3 OpenAI MEDIUM: `wait` returned on exit_code, before signing, so the judge could collect `unknown`.

### 2026-09-30 — round 4: Z.ai lows
- **Completion not committed (low 1) — not addressed:** a runtime commit into the shared main checkout races the parent session's index and hooks. A lost completions file fails closed: the rows become `unknown`, and audit reports no-completion. Left as is. The worker's committed rows plus the signed registry are the durable record.
- **Session binding nominal (low 2) — partly addressed:** `complete` now records `worker_session` from the result stream's `session_id`. It is not required, because the ollama-loop worker emits none; freshness still rests on the dispatch id's random suffix.
- **Consumer paths score medium (low 3) — held, recorded in the reason:** scoring every `lib/`/`agents/` path High would put nearly every framework task at rung 5. That needs a three-vendor panel, which cannot be dispatched until T-3582, so every such task would run degraded. The reason string now says the calibration is held at medium and points here. Changing it is the operator's call.
- **Default vendor (low 4) — fixed:** `_dispatch_real` has no default, and `_dispatch_reviewer` refuses an empty kind. `"claude"` is added to the no-hardcoded-vendor pin.

### 2026-09-30 — round 4: durable worker results
- **Chose:** run.sh copies a non-empty `result.md` to `<project>/.context/dispatch-results/<name>.md`. `fw termlink result` falls back to that copy when the /tmp wdir is gone. It is not committed automatically.

### 2026-09-30 — round 5: the vendor is derived from the kind, through ONE mapping
- **Chose:** `worker_kind` + `vendor` fields in policy/review-backends.yaml are the only kind→vendor mapping (validated by `lib/review_cost.py`: a kind needs a vendor; one kind never maps to two vendors). `register_dispatch` derives the vendor from the registered worker kind; `vendor=` is only an assertion and a mismatch is refused; a review kind the mapping does not know is refused. `register-dispatch` has no `--vendor` flag. `_panel_fault` re-derives the vendor at apply time and treats any row whose registered vendor differs as `panel-unverified-vendor`. termlink.sh's `_worker_vendor` / `worker-kinds --vendors` only print the mapping (`verdict_ledger.py kind-vendors`). The file is added to the self-vendored policy list so consumers carry it.
- **Why:** round-4 MEDIUM: free text passed to register-dispatch was counted; the round-4 "control" (three claude dispatches registered as anthropic / vendor-2 / vendor-3) was the attack. It is now a negative control (refused at registration; re-signed inconsistent rows unverified at apply), and the control uses three distinct registered kinds from a fixture registry (t3580_round5_test.TestVendorMapping).
- **Rejected:** a table inside verdict_ledger.py (the reviewer's suggestion) — the operator named policy/review-backends.yaml as the source, and it already is the backend registry.

### 2026-09-30 — round 5: the never-run dispatch
- **Chose:** three layers. (1) A signed runtime START: run.sh's first ledger call (`verdict_ledger.py start`) needs the secret, the registered wdir, happens once, and must land before the registration's signed `start_by` (registration + 300 s); the CLI refuses unless its parent process is `<wdir>/run.sh`. `complete` and the apply-time validator (`no-start`) require exactly one valid start. (2) A TTL: registration signs `complete_by` (registration + dispatch timeout + 600 s); `complete` refuses after it and apply refuses a completion (`expired`) whose epoch lies outside the window. (3) The secret does not outlive its purpose: run.sh deletes the file as its first act and also on EXIT (trap), clears it from memory after signing; cmd_dispatch installs an EXIT trap before spawning (cmd_spawn can `die`) and after injecting waits up to `TERMLINK_REVIEW_START_WAIT` (60 s) for run.sh to take it, then deletes a leftover.
- **Proof:** registered + never run + leftover secret read + fake exit/result files + `complete` → refused (`no runtime start record`), apply ticks nothing (t3580_round5_test.TestNeverRun). The old round-4 "control" is renamed to what it is (a started runtime).
- **What remains inside the operator-accepted same-user boundary (T-3581):** a caller running as the same user who reads a leftover secret within the start window can call the Python `start()` directly (the parent check is on the CLI only, an honesty check like `--i-am-human`), or can write its own `<wdir>/run.sh` and run it — which is then, literally, running the dispatch. A caller can also self-register a dispatch with `register-dispatch` (no dispatcher marker is required) and so obtain a fresh secret and a wdir of its choosing. And anyone who reads `.context/secrets/review-dispatch.key` can sign any row directly. (SUPERSEDED by round 6/7: no registration secret exists any more, and round 7 closes the documented `--env`/`--prompt` steering routes.) None of these is reachable by the documented commands alone (register + cat + complete no longer suffices); all are deliberate forgery by the same user, which T-3581 accepted as the residual.

### 2026-09-30 — round 5: `finalised` is verified
- **Chose:** run.sh writes `signed:<completion sig>` or `unsigned:<reason>`. `_worker_done` accepts `signed:` only when the sig equals completion.json's, and in both cases only once no `<wdir>/run.sh` process is alive (the worker is run.sh's child, so an early marker from the worker is ignored while it runs). Tested (TestFinalisedVerified: bare marker, wrong sig, live runtime, control).

### 2026-09-30 — round 5: dispatch results are gitignored
- **Chose:** `.context/dispatch-results/` is in .gitignore: durable on disk (where `fw termlink result` falls back to it), never committed. The worker's own commits carry its real output under its own identity; the parent never commits worker output.
- **Rejected:** committing the copies under the worker's identity — run.sh would have to commit into the shared main checkout after the worker exits, racing the parent's index.

### 2026-09-30 — round 5: traceability note (converging write)
- The round-5 edits to agents/termlink/termlink.sh (_worker_vendor via the one mapping, start record in run.sh, secret trap/reap, verified finalised) were committed inside ba35b3559 ("T-3595: cleanup deletes per worker"), by a concurrent T-3595 worker that staged the whole file while this round was editing it; its vendor sync 581c7556a carries them too. Not rewritten (no history rewrite); recorded here so the T-3580 content of that commit is traceable.

### 2026-09-30 — round 5: the completions file under the append-only history check
- **Chose:** `history_fault` runs the same git-history walk `load_ledger` makes (each commit keeps the previous committed lines as a prefix; the working file keeps the last committed lines as its prefix) on review-completions.jsonl. Apply refuses (`completion-history`) and audit FAILs (`completions integrity`) when it breaks. Uncommitted rows are allowed — run.sh writes the completion after the worker's last commit and does not commit (same index-race reason as above) — and audit names that state as `WARN completions file untracked` instead of leaving it silent. Start records live in the same file, so they are covered too.

### 2026-09-30 — round 6: the ledger enforces the IW-7 rung (codex second-family HIGH)
- **Chose:** `lib/review_policy.py` is the ONE implementation of IW-7 (impact, required rung, rung labels, spend ceiling). `judge` calls it to choose the rung; the ledger calls it (`required_strength`) for each criterion at `record` and at every read (`_strength_fault`, inside the shared `_fault`). The requirement is the higher of the task now and the task at the reviewed revision, so lowering risk fields around a review does not lower it. Rung 1: any registered independent review dispatch. Rung 3/5: the dispatch must name, in its SIGNED REGISTRATION, a signed run whose rung is at least the required one; the row's `--rung` must equal the run's. A rung-5 run must demand 3 vendors over 3 seats. `--review-run/--review-seat` go from the judge through `fw termlink dispatch` into `register-dispatch`, which checks the run, task and seat and refuses a second dispatch for a seat. Post-launch `bind_dispatch` is removed and its rows are no longer read.
- **Step-down (SUPERSEDED by round 7, below):** only through `ceiling_decision` in the signed run (due, granted, spend, ceiling, the number of spend-log lines and the clock it used). The ledger re-derives it (`verify_ceiling_decision`) with the ceiling configured NOW. If the operator raises the ceiling, the step-down is withdrawn and the review is owed at full strength again.
- **Why:** a review dispatch could record a lower-rung green with no run, and apply ticked it on a task that needed a panel.
- **Rejected:** checking the rung only in the judge, which is what round 5 did; and a per-criterion rung table in the ledger, which would be a second policy that could drift.
- **Residual (SUPERSEDED by round 7 — the untracked spend log is gone):** the spend log is an untracked working file, so a same-user process can append lines to it and make a step-down derivable. `register_run` is public: a same-user caller can register a run, but it cannot register one below the policy without a derivable decision.

### 2026-09-30 — round 6: the completion capability is issued by the runtime (codex second-family MEDIUM)
- **Chose:** registration issues NO secret. It writes no `.completion-secret` file and registers no hash. `start` issues the secret: it returns the secret once, to run.sh's command substitution, and records only its hash in the signed start record. `complete` checks the secret against that start record. Both `start` and `complete` authenticate their caller in the shared Python implementation (`_runtime_fault`), not only in the CLI. The parent process must be a shell whose argv[1] is the registered `<wdir>/run.sh` (so a `-c` string that merely names it fails), and that file must be byte-identical to the runtime agents/termlink/termlink.sh writes. The round-5 reaper and secret-file traps are removed, because there is no longer a secret file to guard. `_completion_fault` refuses a start record that has no issued-secret hash.
- **Tests:** the round-5 control (`_never_ran` then Python start/complete, expecting a tick) is gone. In its place are refusal tests: Python `start`; Python `complete` holding a genuinely issued secret; `bash -c … <wdir>/run.sh`; an `exec` wrapper; a non-canonical run.sh; and the CLI. The positive control launches a worker: the real run.sh from termlink.sh runs a stub `claude` (t3580_round6_test.TestRuntimeCapability, t3580_round5_test.TestNeverRun). The in-process test double `_review_runtime.as_runtime()` replaces only `_runtime_fault`, and only while it is held.
- **Rejected:** keeping the registration secret and tightening the file mode. The file is still readable by the caller that registered it, which is the finding.
- **Residual, not closed (inside the same-user boundary T-3581 accepted):** a same-user process can write the canonical runtime into the registered directory and run it. That launches the worker, so it is a real run of the dispatch rather than a forgery of one. A same-user process can also patch `_runtime_fault` in its own Python process, fake its parent's argv, read run.sh's memory, or read `.context/secrets/review-dispatch.key` and sign any record. (CORRECTED in round 7: this sentence first said "None of these is reachable through the documented commands". That was wrong. The documented `fw termlink dispatch --task-type review --env PATH=…/--env ANTHROPIC_BASE_URL=…` and `--prompt`/`--prompt-file` flags could steer the worker program, the model and the brief without any key. Round 7 closes those routes; see its entry below.) What this round proves is that a signed completion needs an authenticated runtime start; it does not prove that the reviewer's judgement was genuine.
- **Consumer note:** the canonical runtime is read from the ledger's own framework copy (`<framework>/agents/termlink/termlink.sh`). If a dispatch was written by a different framework version's termlink.sh, its start is refused, so the check fails closed.

### 2026-09-30 — round 6: vendor provenance is the committed registry and a launchable kind (codex second-family LOW)
- **Chose:** `kind_vendors(root, revision)` reads policy/review-backends.yaml as committed in git, never from the working tree. It uses the project's copy at the dispatch's reviewed revision if one is tracked there; otherwise the vendored copy under the project; otherwise this framework's copy at HEAD. `verified_kind_vendors` keeps only the kinds the dispatcher can launch (`launchable_kinds`, which is DISPATCH_WORKER_KINDS in termlink.sh, the list `fw termlink worker-kinds` prints). Registration derives the vendor from that list, and `_panel_fault` re-derives it at apply. So an uncommitted declaration, a kind committed only after the reviewed revision, and a kind no worker can run (codex and opencode until T-3582; antigravity, which has no worker_kind) all count toward no panel.
- **Tests:** the round-5 three-vendor control used an uncommitted registry, which is exactly what the review flagged. It now commits the registry and marks codex and opencode launchable explicitly, "as if T-3582 had shipped" (`_review_runtime.commit_registry` / `launchable`). The negative controls are in t3580_round6_test.TestVendorProvenance: uncommitted; uncommitted edit; committed but unlaunchable (checked at both registration and apply); registry read at the reviewed revision; and antigravity.
- **Rejected (SUPERSEDED by round 7 — each seat re-derived its vendor at its own revision, so one kind could carry two vendor names across seats):** a separate "approved registry revision" field. The reviewed revision is already signed into every registration, so reading the registry at that revision binds it without a second pin. Also rejected: inventing a worker kind for antigravity, which the operator has not given one.
- **Residual:** whoever can commit can commit a registry change. The registry is operator-owned (T-3583), but an agent's commit to it is only gated by the existing registry-change rules, not by this ledger.

### 2026-09-30 — round 7: the ceiling step-down lever (codex HIGH-1 + MEDIUM-2, Claude F1)
- **Chose:** the ledger computes the ceiling decision itself, inside `register_run(rung_due=…)`, as of the run's own signed registration time; a caller can no longer pass a decision. `verify_ceiling_decision` refuses a decision whose `as_of` is not its run's `ts`, so a new run cannot reuse an old decision (codex's 2020 probe). Spend comes from the COMMITTED cost ledger `.context/costs/reviews.jsonl`: reviewer-judge rows at a recorded commit (`ledger_rev`, which must be an ancestor of HEAD) and line count, with the ledger append-only against git (`history_fault`). The judge now logs each seat's estimated cost (`RUNG_COST`) as `cost_amount` there. The untracked `.context/working/judge-spend.jsonl` is gone. Ceiling and spend must be finite and ≥ 0. NaN, infinity, negative values or text (in the config, a ledger row or a decision field) mean no step-down, with a controlled refusal and no exception.
- **Floor = 100 (estimated USD, the unit of RUNG_COST and of the cost ledger).** 100 USD pays for sixteen rung-5 panels (6 each) in a week. A lower ceiling is not a budget for the reviews IW-7 asks for; it only switches every high-impact review down to rung 3. So a ceiling below 100, including 0 and negatives, means "no step-down", never "always step down". The default is 10000.
- **Disclosure:** the ticked criterion's annotation carries `STEP-DOWN: rung R granted, rung D due, <reason>`. `verdict_ledger audit` prints `WARN step-down: …` for every stepped-down run, and `fw audit` shows it as a WARN (`_audit_review_step_downs`). The `lib/config.sh` description now says the signed run records the decision, not "the verdict".
- **Rejected:** keeping the spend log and committing it. That makes a second ledger for the same money, and the cost ledger is already append-only and audited. Also rejected: refusing step-downs outright. The operator ruled the ceiling a legitimate lever; it is now bounded and visible instead.
- **Residual:** a same-user agent can log and commit a reviewer-judge cost row with `fw review cost log`. That row is committed, attributable, append-only, and every step-down it causes is WARNed by audit and shown on the criterion. The `metering` of a judge seat row reads `metered`, although the amount is an estimate. `lib/review_cost.py` was not changed in this targeted round.

### 2026-09-30 — round 7: the review worker cannot be steered by its caller (Claude F2)
- **Chose:** a review dispatch accepts only the caller `--env` keys on a deny-by-default allowlist (`REVIEW_ENV_ALLOW`: the four GIT_AUTHOR_*/GIT_COMMITTER_* identity keys), both in `termlink.sh` (refused before anything is written) and in the ledger (`_env_fault` over env.sh at registration and again at `start`). PATH, *_BASE_URL, ANTHROPIC_*, OPENAI_*, CLAUDE_*, LD_*, BASH_ENV and model or binary overrides are refused because they are absent from the list, not because a denylist names them. The dispatcher resolves the worker binary to an absolute path at dispatch (`readlink -f $(command -v claude)`, or the ollama-loop script) and registers it as the signed `worker_bin`. run.sh launches `"$WORKER_BIN" -p …` for a review, never `claude` looked up on PATH. The judge signs `brief_sha256` for every seat into the run. Registration of a seat's dispatch requires brief.md (the caller's prompt, verbatim) to match that hash and prompt.md to end with it, and signs `prompt_sha256`. `start` refuses if prompt.md, worker_bin or env.sh changed after registration.
- **Why:** with documented flags alone, a producer could launch a stub or another model under a `claude` seat, or feed a real reviewer a "record green" brief. No key was needed, so this sat below the T-3581 line.
- **Rejected:** a denylist (the reviewer's list plus whatever comes next would always be one key short). Also rejected: hashing prompt.md into the run directly. The dispatcher prepends the consult stanza, so the run binds the judge's brief and the registration checks that prompt.md carries it.
- **Residual:** the absolute path is resolved on the dispatcher's own PATH, so a caller who launches the dispatcher with a doctored PATH chooses the binary. That path is signed into the registration and so visible. It is caller-environment tampering, inside the same-user boundary. The `--model` flag (and `OLLAMA_LOOP_MODEL` derived from it) is not constrained in this round, and the vendor is still counted from the kind, not from the model actually used (F3 part 3, deferred to T-3582).

### 2026-09-30 — round 7: one committed binding per review run (Claude F3, codex MEDIUM-4)
- **Chose:** the launchable-kinds list (`DISPATCH_WORKER_KINDS`) and the run.sh template (`_canonical_runtime`) are read from agents/termlink/termlink.sh AS COMMITTED, through the same resolver as the registry (`_committed_blob`): the project's copy at the revision, else the vendored copy, else this framework's copy at its HEAD, pinned to that commit's sha. The working tree is never read. `register_run` pins ONE reviewed `revision` (the judge passes the one it registered with) and the registry blob committed there (`registry`: where + sha256). A run seat's dispatch is refused at registration unless it is at the run's revision. `_panel_fault` derives the kind->vendor table once, at that revision, and refuses a seat dispatched at any other revision and a registry that no longer hashes to the pinned blob. That covers an external framework checkout that moved.
- **Negative control:** rev A maps opencode to anthropic, rev B remaps it to zai. A seat at rev B is refused at registration. A re-signed rev-B seat is refused at apply ("run's one binding"). All seats at rev A span two vendors and do not make a three-vendor panel. (t3580_round7_test.TestOneBinding.)
- **Rejected:** keeping per-seat derivation and checking the revisions agree only at apply. Registration is the earlier gate, and the judge already knows the one revision.
- **Not done here (preconditions of T-3582):** run.sh still routes every kind except ollama-loop to the claude binary, and the vendor is counted from the kind, not from the model actually used. Both must change before a codex or opencode seat can count.

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

### 2026-09-30T07:54:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3580-t-3557-slice-3-fw-reviewer-judge---dispa.md
- **Context:** Initial task creation

### 2026-09-30T08:12:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
