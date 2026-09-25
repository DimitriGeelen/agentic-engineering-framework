---
id: T-3450
name: "handover push timeout is a static 300s while the pre-push gate it must cover
  has grown to 268s — derive it from the measured structure seconds the way T-3421
  derives the audit lock wait"
description: >
  handover push timeout is a static 300s while the pre-push gate it must cover has
  grown to 268s — derive it from the measured structure seconds the way T-3421 derives
  the audit lock wait

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/audit/audit.sh, agents/handover/handover.sh, bin/fw, lib/config.sh, lib/prepush-lock-wait.sh, tests/unit/t3450_push_timeout_derivation.bats, web/blueprints/config.py]
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
created: 2026-09-24T20:09:16Z
last_update: 2026-09-25T21:06:12Z
date_finished: 2026-09-25T21:06:12Z
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
  - ts: '2026-09-24T20:10:19Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-09-24T22:14:13Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 3
      D4: 3
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=3
      (body:component-discoverability); D4=3 (body:portability-abstraction); 
      F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-09-24T20:15:12Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=316,acs=7)
    rubric_sha: e4a00f38e801
---

# T-3450: handover push timeout is a static 300s while the pre-push gate it must cover has grown to 268s — derive it from the measured structure seconds the way T-3421 derives the audit lock wait

## Context

`agents/handover/handover.sh:108` sets `_push_timeout="${FW_HANDOVER_PUSH_TIMEOUT:-300}"`.
That 300 is a **static** number covering a **moving** cost, and its own comment says so:

> "the number is not a network budget, it is `gate cost + network`, and it needs real
> headroom above the gate or this returns the moment some check grows."

It has returned. T-3062 set 300 when the gate measured ~59 s after splitting the whole-tree
scanners out (347 s before). The gate today, from `.context/audits/full-audit-timing.yaml`
written by the audit itself (T-3127):

| | structure section | push ceiling | headroom |
|---|---:|---:|---:|
| At T-3062 | ~59 s | 300 s | ~241 s |
| 2026-09-22 measurement | **268 s** | 300 s | **32 s** |

32 seconds of headroom for network on a gate that already ran 268. Observed live: three
consecutive handovers on 2026-09-24 (runs 5, 6, 7) hit `exit 124 — Push to origin was
KILLED at 300s`, each needing a manual `git push` afterwards; run 7 needed two attempts.
T-3063's work means these are *correctly reported* as killed rather than refused — the
diagnosis is right and the budget is wrong.

**The fix already has a precedent in this repo.** `lib/prepush-lock-wait.sh` (T-3421)
derives the pre-push audit *lock wait* from the same `full-audit-timing.yaml` measurement:
`ceil(1.25 × last measured structure seconds)`, clamped `[90, 600]`, 360 fallback when the
file is absent or has no numeric entry, and it ignores a timed-out run so a runaway
measurement cannot produce an indefinite hang. This task applies that same derivation to
the push timeout instead of adding a second, differently-shaped rule.

## Acceptance Criteria

### Agent
- [x] `FW_HANDOVER_PUSH_TIMEOUT` unset derives from the measured structure seconds rather
      than defaulting to 300: reuse `lib/prepush-lock-wait.sh`'s reader (do not write a
      second YAML parser — if the existing function is not reusable as-is, extract it so
      both callers share one, and say so in `## Decisions`). Budget = gate + network, so
      the derived value must exceed the lock wait, not equal it: state the multiplier and
      floor chosen and why, clamp it, and keep a fallback for a missing or timed-out
      timing file. An explicitly-set `FW_HANDOVER_PUSH_TIMEOUT` still wins.
      Evidence: `fw_handover_push_timeout_default` (lib/prepush-lock-wait.sh) reuses the
      extracted `fw_audit_timing_read_structure_seconds` reader; dominance over
      `fw_prepush_lock_wait_default` proven by construction (multiplier 1.5 > 1.25, floor
      180 > 90, cap 900 > 600, fallback 650 > lock's cap 600) and checked live across 8
      measured values + the timed-out edge (all `push > lock`, see ## Decisions).
      handover.sh:108-125 honours explicit `FW_HANDOVER_PUSH_TIMEOUT` first.
- [x] The value actually used is printed or logged when a push starts, so a future killed
      push shows what budget it had. Today the warning names the ceiling but nothing names
      where the ceiling came from.
      Evidence: handover.sh now echoes `Push timeout: ${_push_timeout}s
      (${_push_timeout_source})` before every push attempt, and the KILLED warning line
      also carries `${_push_timeout_source}`. Confirmed live in `/tmp/t3450-handover-proof.log:31,85`.
- [x] `tests/unit/t3062_push_timeout_budget.bats` (which pins the gate-cost relationship)
      stays green, and is extended — or a sibling added — asserting: a timing file with a
      large structure value yields a proportionally larger timeout; a missing file yields
      the fallback; a timed-out run is ignored rather than trusted; an explicit env var
      overrides all of it. `TEST_TEMP_DIR` set in setup; no bare `! grep -q`.
      Evidence: that exact filename does not exist in this repo (a stale reference already
      present in handover.sh's own comment, predating this task — see ## Decisions). Added
      `tests/unit/t3450_push_timeout_derivation.bats` as the sibling: 15/15 green, covering
      all four named cases plus the dominance property. `tests/unit/t3421_prepush_lock_wait.bats`
      (the actual analogous precedent file) stays 7/7 green — behaviour unchanged.
      `tests/unit/handover_push_timeout.bats` has 3 pre-existing failures unrelated to this
      task (stale literal-value assertions predating T-3062's bump to 300) — not touched,
      out of scope.
- [x] Live, recorded here: the derived value on this host with the current timing file, the
      current structure seconds it came from, and one real `fw handover --commit` whose
      push completes without exit 124. If the push is still killed, do not raise the
      number blindly — record the new measurement and stop, because that means the gate
      grew again and the answer is to trim the gate, not to widen the budget.
      **NOT satisfied — see ## Updates 2026-09-24T20:50Z.** Derived value on this host:
      402s (from ledger `structure: 268` seconds, dated 2026-09-22). A direct `git push`
      landed clean (audit fails=0, no exit 124). A subsequent real `fw handover --commit`
      WAS killed at exit 124 — but a freshly, cleanly measured `bin/fw audit --section
      structure` (no lock contention) just now took **325s wall-clock**, not 268s. The
      gate has grown since the ledger was last written, and the ledger itself is stale
      (only updated by a full unscoped audit, last run 2026-09-22). Stopping per this AC's
      own instruction rather than widening the multiplier/floor/cap to paper over it.
- [x] Vendored `agents/handover/handover.sh` and any touched `lib/` file synced;
      `bin/fw vendor self --check` clean. If a new config key is introduced, it goes in
      `lib/config.sh` `FW_CONFIG_REGISTRY` with a description (`tests/lint/
      config-registry-parity.bats` must stay green).
      Evidence: `bin/fw vendor self` run, committed (6016115f1); `bin/fw vendor self
      --check` → "vendored .agentic-framework/ in sync with source." No new config key
      introduced — `FW_HANDOVER_PUSH_TIMEOUT` already existed pre-task (unregistered
      before and after; out of scope to register it here). `tests/lint/config-registry-
      parity.bats` 3/3 green (unaffected).

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

out=$(timeout 60 bats tests/unit/t3450_push_timeout_derivation.bats 2>&1); echo "$out" | grep -q '^ok 15 ' && ! echo "$out" | grep -q '^not ok'
out=$(timeout 60 bats tests/unit/t3421_prepush_lock_wait.bats 2>&1); echo "$out" | grep -q '^ok 7 ' && ! echo "$out" | grep -q '^not ok'
out=$(bin/fw vendor self --check 2>&1); echo "$out" | grep -q "in sync with source"

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

## RCA

**Symptom:** Three consecutive handovers on 2026-09-24 hit `exit 124 — Push to origin was
KILLED at 300s`, each needing a manual `git push` afterwards. Live during this task, even
after the derived fix landed, a real `fw handover --commit` was *still* killed at the newly
derived 402s.

**Root cause:** `agents/handover/handover.sh:108` bounded `git push` at a static literal
(`${FW_HANDOVER_PUSH_TIMEOUT:-300}`) asserting a number for a cost (the pre-push structure
audit) that changes every time a check is added to that section. T-3062 set 300 with ~241s
of headroom over a ~59s gate; by 2026-09-22 the gate had grown to 268s, leaving 32s. This
task's fix replaces the literal with a derivation from the measured cost
(`fw_handover_push_timeout_default`, lib/prepush-lock-wait.sh) — but the live proof (AC4)
surfaced a *second*, deeper instance of the same root cause one layer down: the ledger the
derivation reads (`.context/audits/full-audit-timing.yaml`) is itself a static snapshot,
written only by a full unscoped `fw audit` run, not by the scoped `--section structure` run
the pre-push hook actually invokes on every push. A clean, uncontended, freshly-measured
`bin/fw audit --section structure` just now took 325s wall-clock — the ledger still said
268s, 2 days stale. The number moved again, one layer further down than this task reaches.

**Why structurally allowed:** Nothing re-measures or invalidates the ledger on a cadence
tied to how often it is actually relied on. It is written as a side effect of *full* audit
runs (cron, `fw audit` with no `--section` filter) and read by two different derivations
(`fw_prepush_lock_wait_default`, and now `fw_handover_push_timeout_default`) that both
implicitly assume "last full-audit measurement" tracks "current per-push gate cost" closely
enough. On a host where full audits run irregularly (and where concurrent workers sharing
this checkout contend for the audit lock — "Another audit is already running" appeared in 2
of 3 live push attempts today), that assumption silently degrades and nothing flags it.

**Prevention:** Not implemented in this task — see AC4's explicit instruction ("record the
new measurement and stop... the answer is to trim the gate, not widen the budget") and
§Execution Model's "dispatch the fix, never the search" for unlocalised debugging. Candidate
follow-ups, named but not filed as new tasks (out of scope — "Do not widen it"):
(1) have the pre-push hook itself update the ledger's `structure` entry after every scoped
run, not just full-audit runs, so the number the derivation reads tracks the number the gate
actually pays; (2) a doctor WARN when the ledger's timestamp is older than N days, sibling to
the existing `AUDIT_TIMEOUT_WARN_FRACTION` staleness check; (3) trim the `structure` section
itself (T-3062's original remedy) if 325s is confirmed as a real, sustained regression rather
than one contended sample.

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

### 2026-09-24 — extraction vs. wrapping fw_prepush_lock_wait_default
- **Chose:** extracted the ledger-parsing awk block out of `fw_prepush_lock_wait_default`
  into a new shared function `fw_audit_timing_read_structure_seconds` (plus a sibling
  `fw_audit_timing_last_run_timed_out`), and rewrote `fw_prepush_lock_wait_default` to call
  it. `fw_handover_push_timeout_default` calls the same reader independently, with its own
  multiplier/floor/cap/fallback.
- **Why:** the AC required reusing "the reader" without writing a second YAML parser. A
  simpler alternative (call `fw_prepush_lock_wait_default` directly and add a fixed buffer)
  was tried first and rejected — see below.
- **Rejected — `push_timeout = fw_prepush_lock_wait_default(root) + buffer`:** this
  guarantees dominance trivially (buffer > 0) in the *normal* path, but breaks the AC's
  explicit "a timed-out run is ignored rather than trusted" requirement, because
  `fw_prepush_lock_wait_default`'s own pinned tests (t3421) assert it *does* trust a
  timed-out ledger's measured value. Proxying through it would make the push-timeout
  inherit that same trust, which this task's AC explicitly asks it not to. Extracting the
  raw reader let each derivation apply its own trust policy over the same parsed value.

### 2026-09-24 — dominance by construction, not by runtime comparison
- **Chose:** push-timeout knobs are each strictly larger than lock-wait's: multiplier 1.5
  (vs 1.25), floor 180 (vs 90), cap 900 (vs 600), fallback 650 (vs 360). Verified by
  exhaustive check across 8 measured values (10, 100, 150, 268, 480, 600, 700, 1000) plus
  the timed-out edge — `push > lock` holds in every case, pinned in
  `tests/unit/t3450_push_timeout_derivation.bats`.
- **Why:** the fallback value (650) is deliberately *not* a naive scale-up of lock-wait's
  360 fallback (which would give ~468 following the 1.3x pattern of the other knobs).
  650 was chosen specifically to exceed `FW_PREPUSH_LOCK_WAIT_CAP` (600) — the worst case
  `fw_prepush_lock_wait_default` can ever return — because push's fallback fires on a
  timed-out ledger while lock-wait, on that exact same ledger, does NOT fall back (it
  trusts the measured value regardless, per its own pinned behaviour). Without this,
  a timed-out ledger with a large measured value would have push fall back to a *smaller*
  number than the lock wait it must exceed — reproducing the exact ordering bug this task
  exists to prevent, one level down.

### 2026-09-24 — the AC's own test-filename reference is stale
- **Chose:** treated `tests/unit/t3062_push_timeout_budget.bats` (named in both this task's
  AC text and in a pre-existing handover.sh comment) as a stale reference rather than a
  blocking discrepancy, added the coverage as a new sibling file
  (`tests/unit/t3450_push_timeout_derivation.bats`) instead.
- **Why:** the filename does not exist anywhere in this repo's history (`git log --all` on
  the path returns nothing) — it appears to be a copy-paste of a filename that was never
  actually created when the comment in handover.sh:106 was written. The real pinning file
  is `tests/unit/handover_push_timeout.bats`, which independently already carried 3
  pre-existing failures (stale literal-value assertions from T-1277/T-1341, predating
  T-3062's bump of the default to 300) that are unrelated to this task's change and were
  left untouched, per scope discipline ("Do not widen it").

### 2026-09-24 — stopped at AC4 rather than widening constants
- **Chose:** did not raise the multiplier/floor/cap after a real `fw handover --commit`
  was killed at the newly-derived 402s.
- **Why:** AC4 explicitly instructs this: a kill after the fix means the gate grew again,
  and the fix for that is trimming the gate (or the measurement pipeline that feeds the
  derivation), not widening the budget further. A freshly-measured, uncontended
  `bin/fw audit --section structure` took 325s — the ledger the derivation reads still
  said 268s (2 days stale, only updated by full unscoped audits). Recorded in ## RCA;
  candidate follow-ups named there but not implemented, per task scope.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-24T20:09:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3450-handover-push-timeout-is-a-static-300s-w.md
- **Context:** Initial task creation

### 2026-09-24T20:50Z — AC4 live proof: derived timeout works, but the gate has grown past what the ledger records [t3450-push-timeout]

**What was built (AC1/2/3/5, all verified green):**
- `lib/prepush-lock-wait.sh`: extracted `fw_audit_timing_read_structure_seconds` (shared
  ledger reader) and `fw_audit_timing_last_run_timed_out`; added
  `fw_handover_push_timeout_default` (1.5x / floor 180 / cap 900 / fallback 650 — each
  knob strictly larger than `fw_prepush_lock_wait_default`'s, proven to dominate it at
  every measured value including the timed-out edge). `fw_prepush_lock_wait_default`
  itself refactored to call the shared reader; behaviour unchanged, its own 7 pinned
  tests (t3421) still green.
- `agents/handover/handover.sh`: `_push_timeout` now resolves explicit env var → derived
  default → hardcoded 300 only if the lib is missing; logs
  `Push timeout: ${_push_timeout}s (${_push_timeout_source})` on every push attempt and in
  the KILLED warning.
- `tests/unit/t3450_push_timeout_derivation.bats`: new, 15/15 green — proportional scaling,
  floor/cap, missing/non-numeric/timed-out fallback, dominance across 8 values + the
  timed-out edge, explicit-env-var override, source logging.
- `tests/lint/prepush-gate-budget.bats`: the T-3062 "push timeout leaves headroom" test
  grepped a literal (`${FW_HANDOVER_PUSH_TIMEOUT:-300}`) this task's change removed —
  caught live when the pre-push audit REF-FAILed on our own push. Rewrote the assertion to
  check the derivation's floor constant instead. Full `tests/lint/` (110 tests) green after.
- Vendor sync: `bin/fw vendor self` + `bin/fw vendor self --check` clean.
- Commits on `bleeding-edge` (all landed on `origin/bleeding-edge`, confirmed via
  `git fetch` + `git rev-parse HEAD origin/bleeding-edge` matching): b287beaad..6ec65b8f6
  range includes b3ed1ca0d (derivation), 0ca68917b (tests), d2faa7061 (fabric card),
  6016115f1 (vendor sync), 6ec65b8f6 (lint fix).

**What was NOT achieved — AC4's live push proof:**
Live derivation on this host: `structure` ledger says 268s (dated 2026-09-22) →
`fw_handover_push_timeout_default` returns 402s. A direct `git push` (after fixing vendor
drift and the lint invariant) completed cleanly: audit ran to completion, fails=0, no exit
124. But a subsequent real `fw handover --commit` (the literal AC4 ask) WAS killed at exit
124 at the derived 402s — log: `WARNING: Push to origin was KILLED at 402s (derived
from .../full-audit-timing.yaml)`. That run hit lock contention first
("Another audit is already running — exiting", "Audit lock held — waiting up to 335s")
before its own structure audit could even start, consistent with another process (plausibly
the sibling T-3389 worker sharing this checkout, or host cron) also hitting the audit lock.

To separate "contention" from "the gate itself grew," ran a clean, uncontended
`bin/fw audit --section structure` immediately after (no lock-wait line in its output):
**325s wall-clock**, not 268s. The ledger the derivation reads is stale — it is written
only by full unscoped `fw audit` runs (last one 2026-09-22), not by the scoped
`--section structure` invocation the pre-push hook and this measurement both actually run.
So even without contention, the real current gate cost already eats most of the derived
402s budget, and any contention on top of that exceeds it.

**Per AC4's own instruction, did not widen the multiplier/floor/cap.** This is a second,
deeper instance of the same root-cause class the task fixes at the handover.sh layer: a
number derived from a measurement that goes stale. Filed the finding in ## RCA with
candidate follow-ups (ledger updated on every scoped run, staleness WARN in doctor, or
trimming `structure` itself) — none implemented here, per "Do not widen it."

**Status:** AC4 left unchecked. AC1/2/3/5 done and verified. Not calling
`--status work-completed`. Posting to agent-chat-arc and handing back per the operator's
standing order.

### 2026-09-24T20:57:05Z — status-update [task-update-agent]
- **Change:** status: started-work → issues

### 2026-09-25T00:20Z — AC 4 satisfied by T-3451 (parent session)

AC 4 was blocked, not wrong. The derivation this task shipped was correct the whole
time; its input was stale. T-3451 fixed the input — `agents/audit/audit.sh` now records
every completed section, on scoped runs as well as full ones, so the ledger this function
reads is refreshed by the very `--section structure` run the pre-push hook pays for.

**The three things this AC asked to be recorded here:**

| | value | source |
|---|---|---|
| structure seconds | **329 s**, `timed_out: false`, measured 2026-09-24T23:58:27+02:00 | `.context/audits/full-audit-timing.yaml` `section_runs[structure]`, written by a real `bin/fw audit --section structure` (337 s wall, rc=1 warnings-only, `fails=0`) |
| derived push timeout | **494 s** = ceil(1.5 x 329) | `fw_handover_push_timeout_default` |
| derived lock wait | **412 s** = ceil(1.25 x 329) | `fw_prepush_lock_wait_default` |

**The real push, `bin/fw handover --commit`, rc=0, 515 s wall, 8 unpushed commits -> 0:**

```
Push timeout: 494s (derived from .context/audits/full-audit-timing.yaml)
Another audit is already running - exiting (no verdict produced)
Audit lock held - waiting up to 412s for it to free (FW_PREPUSH_LOCK_WAIT=412, 0 disables)
Fail: 0
Pushed to origin OK
```

Zero occurrences of `124` in the run. Note what that log shows and an earlier attempt did
not: **lock contention actually happened on this run** - the very condition that killed
two of the three previous attempts - and the derived 412 s wait absorbed it rather than
the push dying under it. The previous derived value (402 s) came from a ledger reading
268 s dated two days earlier; before T-3451's fix landed, the last structure entry was a
watchdog-killed 322 s flagged `timed_out: true`, which made
`fw_handover_push_timeout_default` fall back to the 650 s constant rather than derive at
all. 494 s is the first value this function has ever computed from a measurement it
could trust.

No multiplier, floor or cap was widened. This AC's own instruction - *"do not raise the
number blindly"* - was not reached, because the gate did not grow; the reading of it was
simply wrong.

**This task is NOT closed by the agent that produced its evidence.** T-3451's AC 6 says
so explicitly, and producer-not-judge says it independently: the session that fixed the
input should not also certify that the fix satisfied a different task's bar. Every Agent
AC here is now ticked and the close is a single command for whoever picks it up.

### 2026-09-24T22:14:12Z — status-update [task-update-agent]
- **Change:** status: issues → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-24eb2c69
- **Timestamp:** 2026-09-25T21:06:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-25T21:06:12Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
