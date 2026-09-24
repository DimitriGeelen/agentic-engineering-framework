---
id: T-3451
name: "the audit timing ledger two derivations depend on is written only by full audits,
  never by the scoped --section structure run the pre-push hook actually pays — so
  both timeouts derive from a stale number"
description: >
  the audit timing ledger two derivations depend on is written only by full audits,
  never by the scoped --section structure run the pre-push hook actually pays — so
  both timeouts derive from a stale number

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
created: 2026-09-24T21:04:57Z
last_update: 2026-09-24T21:32:42Z
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
bvp_scores_proposed:
  - ts: '2026-09-24T21:05:59Z'
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
cost_estimate_proposed:
  - ts: '2026-09-24T21:15:13Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=322,acs=8)
    rubric_sha: e4a00f38e801
---

# T-3451: the audit timing ledger two derivations depend on is written only by full audits, never by the scoped --section structure run the pre-push hook actually pays — so both timeouts derive from a stale number

## Context

Found by T-3450's live proof, which is the only reason it is visible: T-3450 replaced a
static push timeout with a derivation from measured gate cost, and the derived value was
*still* too small, because the thing it derives from is stale.

`.context/audits/full-audit-timing.yaml` is written **only as a side effect of a full,
unscoped `fw audit` run**. It is read by two derivations that both bound the pre-push gate:

| Consumer | What it bounds | Derivation |
|---|---|---|
| `fw_prepush_lock_wait_default` (T-3421) | how long a push waits for the audit lock | `ceil(1.25 × structure)` clamped `[90,600]` |
| `fw_handover_push_timeout_default` (T-3450) | how long `git push` may run | derived to exceed the lock wait |

But the cost they are bounding is paid by the **scoped** `fw audit --section structure`
run that the pre-push hook invokes on every push — and that run never writes the ledger.
So both derivations assume "last full-audit measurement" tracks "current per-push gate
cost", and nothing checks that it does.

**Measured 2026-09-24 (T-3450's handback):** a clean, uncontended
`bin/fw audit --section structure` took **325 s** wall-clock. The ledger still read
**268 s**, written 2 days earlier. The derived push timeout was therefore 402 s against a
gate that now costs 325 s plus lock contention — and a real `fw handover --commit` was
still killed. Two of three live push attempts also hit "Another audit is already running",
so contention is part of the true cost and is invisible to a ledger written by a
single-threaded full run.

This is the same defect class as T-3450 one layer down: a number asserted about a moving
cost. T-3450 fixed the literal; this fixes its input.

## Acceptance Criteria

### Agent
- [x] The scoped run writes what it measures: `fw audit --section structure` (and any other
      single-section invocation) records that section's wall-clock into the ledger it
      already writes from full runs, without a full run being required. Shape stays
      backward-compatible — `fw_prepush_lock_wait_default` and
      `fw_handover_push_timeout_default` must read it unchanged, and a ledger written by an
      older version must still parse (state how in `## Decisions`).
- [x] Staleness is visible rather than silent: the ledger records when each section
      measurement was taken, and a reader can tell a fresh number from a two-day-old one.
      `fw doctor` WARNs when the structure measurement the gate depends on is older than a
      configurable window (default 7 days, key in `lib/config.sh` `FW_CONFIG_REGISTRY` with
      a description, `tests/lint/config-registry-parity.bats` green).
- [x] Lock contention is not silently excluded from the measurement, or it is explicitly
      excluded and the derivations account for it. Decide which, justify it in
      `## Decisions`, and make the choice visible in the recorded value — "Another audit is
      already running" appeared in 2 of 3 live attempts, so a measurement that never waits
      for a lock systematically under-reports what a real push pays.
- [x] Tests: a fixture ledger written by a scoped run is read identically by both
      derivations; an old-format ledger still parses; the doctor WARN fires on a stale
      measurement and is silent on a fresh one (pin both legs — a guard that never fires
      and one that fires correctly must be distinguishable). `TEST_TEMP_DIR` set in setup;
      no bare `! grep -q`.
- [x] Live, recorded here: the measured structure seconds before and after one scoped run,
      the derived lock wait and push timeout that result, and **one real
      `fw handover --commit` whose push completes without exit 124** — which is T-3450's
      AC 4, unblocked. If it still fails, record the new measurement and STOP: do not widen
      any multiplier, because a third instance of the same class means the gate itself is
      the thing to fix, not its budget.
- [x] Vendored copies synced for every touched file under `lib/ agents/`; `bin/fw vendor
      self --check` clean. T-3450 is updated from `issues` to reflect that its AC 4 is
      unblocked by this task (do not close T-3450 yourself — say so in the handback).

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
#
# Counts are deliberately NOT pinned below (T-3326): "0 failures" is the
# invariant, "23 tests" is a number that moves the next time anyone adds a leg.
# No `bin/fw audit` line here either (L-391) — the section this task measures is
# the one the pre-push gate already runs, so a verification line would run it twice.

timeout 300 bats tests/unit/t3451_audit_timing_ledger.bats > /tmp/.t3451-v1.out 2>&1 && grep -q "^ok 1 " /tmp/.t3451-v1.out
timeout 180 bats tests/lint/config-registry-parity.bats > /tmp/.t3451-v2.out 2>&1 && grep -q "^ok 1 " /tmp/.t3451-v2.out
bin/fw vendor self --check
bash -c 'set -eo pipefail; sed -n "/^section_mark \"\"\$/,/^fi\$/p" agents/audit/audit.sh | head -1 | grep -qx "section_mark \"\""'

## RCA

**Symptom:** Live proof (AC4/AC5 evidence-gathering) ran a real, clean, uncontended
`bin/fw audit --section structure` (325.6s wall-clock, confirmed via `time`). The ledger
(`.context/audits/full-audit-timing.yaml`) was **unchanged** afterward — no `section_runs:`
block appeared, `fw_audit_timing_read_structure_seconds` still returned the pre-existing
stale `268` from the 2026-09-22 full run, and `fw_audit_timing_is_stale` still reported
"not stale" (wrongly — it was reading the same 2-day-old number the whole task exists to
stop trusting).

**Root cause:** `section_mark()` (agents/audit/audit.sh) only records a section into
`_audit_record_section_run` when a NEW section starts (it records the section that just
*ended*). The LAST section in any run is only flushed by an explicit trailing call —
`section_mark ""` at what was line 7555-7557 — and that trailing flush is wrapped in
`if [ -z "$SECTIONS" ]; then # T-3127: full runs only`. A `--section structure` invocation
runs exactly one section, calls `section_mark "structure"` once at its start, and then
NEVER calls `section_mark` again (no next section to rotate into) — so structure's own
completion is never recorded, because the only flush path that would catch it is gated
to unscoped runs. The mid-run rotations (section_mark firing for section 2, 3, ... N)
work correctly for a multi-section scoped run (e.g. the cron line running
`--section structure,compliance,quality,discovery`); it is specifically the SINGLE- or
LAST-section case — which is exactly what the pre-push hook invokes every push
(`--section structure` alone) — that silently drops its own measurement.

**Why structurally allowed:** I added `_audit_record_section_run` calls at `section_mark()`
(mid-run rotation) and at the TERM trap (killed in-flight section), and verified both via
sed-extracted unit tests (tests/unit/t3451_audit_timing_ledger.bats, 19/19 green) — but
never ran the ACTUAL end-to-end scoped-run path before the live-proof step, because a real
`--section structure` run costs ~325s and I deferred it to the AC4/AC5 evidence step by
design (cheap unit tests first). The unit tests exercise `_audit_record_section_run`
directly (extracted function, fed synthetic args) — they prove the function itself is
correct, but none of them exercise the CALLER wiring for the single/last-section case,
because that wiring lives in the trailing flush block I did not touch. Classic gap between
"the unit works" and "the unit is reachable from the path that matters" — the exact
class T-3450's own AC4 flagged one layer up.

**Prevention:** Not implemented — this task stops here per the operator's standing order
("if a live step fails ... write the failure verbatim ... and stop with a HANDBACK").
The fix is understood and small (move `section_mark ""` out of the
`if [ -z "$SECTIONS" ]; then` guard so it runs unconditionally — the `_audit_write_timing_yaml`
full-run summary call stays gated, only the flush that feeds `_audit_record_section_run`
needs to run always) but is UNVERIFIED — applying it now, at critical context budget, with
Bash access restricted to commit/push/handover, would mean shipping an unrun guess as the
literal fix a whole task exists to get right. Left for the next worker.

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

### 2026-09-24 — canonical ledger shape: a second, independent `section_runs:` block
- **Chose:** added a NEW top-level `section_runs:` list, written by
  `_audit_record_section_run` (agents/audit/audit.sh) from every section any audit
  invocation (full OR `--section`-scoped) completes. `lib/prepush-lock-wait.sh`'s
  `fw_audit_timing_read_section_measurement` reads it FIRST, falling back to the
  pre-existing `last_run.sections` shape only when `section_runs:` has no entry for the
  wanted section. `_audit_write_timing_yaml` (full-run summary writer) and
  `_audit_record_section_run` each preserve the OTHER's block verbatim (re-read from disk
  immediately before writing) so neither write path clobbers the other.
- **Why:** the AC requires backward compatibility — old ledgers (no `section_runs:` at
  all) must still parse, and `last_run.total_seconds`/`ceiling_seconds`/`timed_out` are
  read elsewhere (lib/audit_timing.py, `fw doctor`'s AUDIT_TIMEOUT_WARN_FRACTION check) in
  a shape I must not disturb. A second, independent, continuously-updated block is
  additive rather than reshaping `last_run:` in place.
- **Rejected:** overwriting `last_run.sections` from a scoped run — would make `last_run:`
  mean "last run of EITHER kind", breaking `lib/audit_timing.py`'s full-run-ceiling-headroom
  semantics (it needs the last FULL run specifically, not the last anything).

### 2026-09-24 — lock contention explicitly excluded from the measurement (AC3)
- **Chose:** `_audit_record_section_run` writes `excludes_lock_wait: true` on every entry.
  The exclusion is structural, not a policy choice made in this function: `flock -n` above
  never blocks — a caller that cannot get the lock exits 75 before any `section_mark` ever
  runs, so bash's `SECONDS` builtin (used for all timing here) only ever counts time
  already holding the lock.
- **Why:** a caller who HAD to wait for a contended lock pays that cost separately, already
  budgeted by `fw_prepush_lock_wait_default` — folding it into the section's own seconds
  would conflate "cost of the check" with "how unlucky was the scheduling", making the
  number incomparable run to run.
- **Rejected (named, not implemented):** making the push-timeout derivation ADD the lock-wait
  budget on top of the section-seconds budget for a true worst-case bound. This is very
  likely the actual remaining gap behind the live push failures T-3450 saw (wait for
  someone else's audit, THEN pay your own) — but AC5 and the operator's standing order are
  explicit: a third instance of "the budget is still too small" means fixing the GATE, not
  widening any multiplier, and that is a different, Sovereign-scoped task.

### 2026-09-24 — HANDBACK before AC4/AC5/AC6: live proof surfaced a wiring gap this task did not fix
- **Chose:** stopped without applying the fix, per the operator's standing order (a live
  step failing means stop and report, not push through) and because context hit critical
  budget (Bash restricted to commit/push/handover) at the same moment the gap surfaced.
- **Why:** see `## RCA`. The scoped-run write path (`_audit_record_section_run` wired into
  `section_mark` and the TERM trap) is correct and unit-pinned (19/19 green,
  tests/unit/t3451_audit_timing_ledger.bats) but UNREACHABLE for a single/last-section run
  — which is exactly the shape the pre-push hook invokes on every push
  (`--section structure` alone) — because the trailing flush that would catch the run's
  only section (`section_mark ""` at the old line 7555-7557) is still gated to
  `[ -z "$SECTIONS" ]` (full runs only), a gate this task needed to loosen and did not.
  Confirmed live: a real, clean 325.6s `bin/fw audit --section structure` left the ledger
  completely unchanged (still 268s / 2026-09-22, still read as "not stale").
- **Rejected:** applying the one-line-looking fix (unconditionally call `section_mark ""`
  before the full-run-only `_audit_write_timing_yaml` call) without re-running the full
  ~325s live proof to confirm it actually closes the gap. Shipping an unverified guess as
  the literal deliverable of a task about trusting measurements would be the same failure
  class one level up.

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-24T21:04:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3451-the-audit-timing-ledger-two-derivations-.md
- **Context:** Initial task creation

### 2026-09-24T23:45Z — HANDBACK: live proof failed, wiring gap found, stopping [t3451-ledger-staleness]

**Built (unit-verified, 19/19 green in `tests/unit/t3451_audit_timing_ledger.bats`, plus all
41 pre-existing sibling tests in t3421/t3450/t3127/t3202/t3070 still green — zero
regressions):**
- `lib/prepush-lock-wait.sh`: new `fw_audit_timing_read_section_measurement` (generalizes
  the ledger reader to any section, resolving `section_runs:` first, `last_run.sections`
  as fallback); `fw_audit_timing_read_structure_seconds` and
  `fw_audit_timing_last_run_timed_out` rebuilt on top of it (same public signature/contract);
  new `fw_audit_timing_last_measured_at` and `fw_audit_timing_is_stale`.
- `agents/audit/audit.sh`: new `_audit_record_section_run` (writes/upserts a
  `section_runs:` entry, preserving `last_run:` verbatim); wired into `section_mark()`
  (mid-run rotation) and the TERM trap (killed in-flight section), for BOTH full and
  scoped runs; `_audit_write_timing_yaml` (full-run writer) now preserves `section_runs:`
  verbatim instead of dropping it.
- `bin/fw`: new `fw doctor` WARN block (marked `T-3451-STRUCTURE-STALENESS-{START,END}`
  for extraction) — WARN when the structure measurement is older than
  `AUDIT_STRUCTURE_TIMING_STALE_DAYS` (default 7), OK when fresh, INFO when unmeasured.
- `lib/config.sh` + `web/blueprints/config.py`: registered `AUDIT_STRUCTURE_TIMING_STALE_DAYS`
  (`tests/lint/config-registry-parity.bats` 3/3 green).

**Live proof (AC4/AC5) — FAILED, per the operator's standing order:**
Before: ledger said `structure: 268s` (2026-09-22, 2 days stale) → lock wait 335s, push
timeout 402s, `fw_audit_timing_is_stale` → not stale (wrongly).
Ran a real, clean, uncontended `bin/fw audit --section structure`: **325.6s wall-clock**
(`time` output: `real 5m25.626s`), confirming T-3450's own measurement was not a one-off.
**After: ledger completely unchanged** — no `section_runs:` block, still reads 268s, still
"not stale". Root cause in `## RCA`: the trailing flush that records a run's LAST section
is gated to full-runs-only, and a `--section structure` run's only section IS its last
section, so it is never flushed. The mid-run wiring is correct; this one caller path is
not. Did not attempt AC5's `fw handover --commit` push proof, since the ledger the push
timeout derives from was never actually refreshed by this run — there is nothing new to
prove yet.

**Stopping here, HANDBACK, per standing order + budget:** context hit critical
(~95%/800K) mid-investigation, which restricts further Bash to commit/push/handover and
blocks Write/Edit to source files. Posted to agent-chat-arc. Status → `issues`. Not
touching T-3450 (still `issues`, AC4 still blocked — this task does NOT unblock it yet).

**For the next worker:** the fix is understood, small, and UNVERIFIED — move
`section_mark ""` out of the `if [ -z "$SECTIONS" ]; then` guard (agents/audit/audit.sh,
was line ~7555) so the trailing flush always runs; keep `_audit_write_timing_yaml 0 "" "$SECONDS"`
itself gated to full runs only (unchanged). Then re-run the live proof
(`bin/fw audit --section structure`, ~5.5 min) and confirm `section_runs:` appears with a
fresh timestamp before touching AC4/AC5/AC6 or vendoring.

### 2026-09-24T23:40Z — push not yet successful; concurrent activity discovered on the shared checkout [t3451-ledger-staleness]

Two pushes attempted, both blocked (neither via bypass — no `--no-verify`/`--force`/
`FW_ALLOW_*` used):
1. First `git push origin bleeding-edge`: blocked by the self-vendor-drift gate (T-2240).
   Fixed with `bin/fw vendor self`, committed (`9a22d44cb`).
2. Second push: the pre-push hook's own `fw audit --section structure` run (another
   ~5.5 min) found 3 FAILs, 2 REF-scoped (in the commits being pushed): a dead-negation
   lint violation I introduced in the new test file (line 350, `! cmd` not last-statement —
   fixed and committed, `c24f5018a`), and an invariant-suite count that was almost
   certainly the same violation counted twice. Did not re-attempt the push after this fix —
   see below.

**While fixing #2, discovered `agents/audit/audit.sh` had a THIRD, uncommitted change in
the working tree that I did not author** — the exact fix I diagnosed above (moving
`section_mark ""` outside the full-runs-only guard), with its own new comment block, dated
after my critical-budget stop. `git log` also shows a `T-3090: Session handover` commit
(author: Dimitri Geelen) landing on `bleeding-edge` HEAD *after* my two commits, and a wide
spread of unrelated unstaged changes across `docs/generated/components/*`, `VERSION`,
other `.tasks/*` files, appearing while I worked. This contradicts the dispatch's stated
"no other worker is on this tree" — there is clearly a concurrent process (very likely the
operator's own interactive session / continuous-run wrapper, sharing this exact checkout)
active during this task.

**Left the mystery audit.sh edit uncommitted and untouched** — I did not write it, did not
verify it, and committing someone else's in-flight, unverified change under my own task
would be exactly the "shipping an unrun guess" failure this task already stopped once to
avoid. Did not attempt a third push given (a) critical context budget, (b) a shifting
working tree makes a clean push risky right now, (c) the real fix may already be in
progress by whoever made that edit. **Two of my three commits (`ba9b6348c`, `9a22d44cb`,
`c24f5018a`) are on local `bleeding-edge` but NOT YET PUSHED to origin.**

**Recommend the operator/next session:** `git status` and `git diff agents/audit/audit.sh`
before doing anything else, decide whether to keep, verify, or discard that uncommitted
edit, then retry `git push origin bleeding-edge` (which will run the ~5.5 min audit gate
again).

### 2026-09-24T21:29:55Z — status-update [task-update-agent]
- **Change:** status: started-work → issues

### 2026-09-24T21:32:42Z — status-update [task-update-agent]
- **Change:** status: issues → started-work

### 2026-09-24T22:05Z — live proof, AC 5 (parent session)

The worker's handback above is accurate for the tree it measured and **out of date for
this one**. It ran its clean scoped audit against the pre-fix script, saw the ledger not
move, and stopped — correctly. The one-line fix it diagnosed was already sitting
uncommitted in the same checkout (the parent authored it while the worker was still live;
the worker found it, declined to commit work it had not authored, and said so — see
OBS-510, *a handback commit is not a worker exit*). It is now committed as `eb4b49b60`.

**Leg 1 — a single-section scoped run records itself.** `bin/fw audit --section oe-fast`,
5.7 s, rc=0. `oe-fast` is the only section in that run, so the trailing flush is the only
thing that could close it:

| | `section_runs[oe-fast].timestamp` |
|---|---|
| before | `2026-09-24T23:45:09+02:00` |
| after | `2026-09-24T23:50:52+02:00` |

**Control leg.** The identical stub harness run against the pre-fix block from
`ba9b6348c` (`git show ba9b6348c:agents/audit/audit.sh`) with `SECTIONS=structure` fires
*nothing at all* — neither the flush nor the summary. So the guard being tested is
distinguishable from one that always fires, which is why the four new tests in
`tests/unit/t3451_audit_timing_ledger.bats` pin position and behaviour rather than
grepping for the call (the call existed before, on the wrong side of the `if`).

**Leg 2 — the number the gate actually depends on.** `bin/fw audit --section structure`,
337 s wall, rc=1 (warnings only, `fails=0`), ran to completion rather than being killed:

| | structure | `fw_prepush_lock_wait_default` | `fw_handover_push_timeout_default` |
|---|---|---|---|
| before | 322 s, `timed_out: true`, 23:43:58 | 403 | 650 |
| after | **329 s, `timed_out: false`, 23:58:27** | **412** = ⌈1.25×329⌉ | **494** = ⌈1.5×329⌉ |

Three things worth reading off that table rather than past it:

- The before-row's 650 was **not** a computation — it is `FW_PUSH_TIMEOUT_FALLBACK`,
  because the 322 s entry carried `timed_out: true` and
  `fw_handover_push_timeout_default` refuses to derive from a truncated run. That
  asymmetry (push-timeout distrusts `timed_out`, lock-wait trusts it) is deliberate and
  pinned by t3421; it is documented at `lib/prepush-lock-wait.sh:236`. It is not a defect,
  and the after-row is the first time this number has been a real derivation.
- 337 s wall vs 329 s recorded: the ~8 s difference is the audit's own startup and
  teardown, outside any `section_mark` window. The ledger measures the *section*, not the
  process, which is the right thing for a per-section budget and worth stating so nobody
  later "fixes" the discrepancy.
- 329 s against the worker's 325.6 s, measured ~25 minutes apart on the same corpus: the
  cost is not noise-free, which is the entire argument for deriving the timeout from a
  continuously-refreshed measurement instead of a literal.

**Staleness predicate, both legs, live:** `fw_audit_timing_is_stale $PWD structure 7` →
not stale; the same call at a 0-day window → stale. A predicate that can fire and
correctly does not.

**Note for whoever owns doctor's runtime:** `bin/fw doctor` exceeded a 180 s timeout on
this host and was killed before reaching its structure-timing line. That is not this
task's defect and the WARN/silent/INFO legs are pinned by tests 21-23, but a health
command that cannot finish inside three minutes is a surface nobody will run.

### 2026-09-25T00:25Z — AC 5 closed by a real push, AC 6 closed (parent session)

**AC 5's remaining leg.** `bin/fw handover --commit` — rc=0, 515 s wall, 8 unpushed
commits to 0, zero occurrences of `124` anywhere in the run:

```
Push timeout: 494s (derived from .context/audits/full-audit-timing.yaml)
Another audit is already running - exiting (no verdict produced)
Audit lock held - waiting up to 412s for it to free (FW_PREPUSH_LOCK_WAIT=412, 0 disables)
Fail: 0
Pushed to origin OK
```

The middle two lines are the part worth not skimming. **Lock contention actually
occurred on this run** — the condition present in two of the three failed attempts that
produced this task — and the derived 412 s wait absorbed it instead of the push dying
under it. So this is not a pass obtained by getting lucky on an uncontended run; it is a
pass on the contended path, which is the one the gate is for.

That also retires the open question AC 3 left standing. The recorded measurement carries
`excludes_lock_wait: true` — the section timer deliberately measures the audit's own
work, not the wait for someone else's — and the wait is accounted for *separately*, in
`fw_prepush_lock_wait_default`, from the same number. One measurement, two consumers,
neither of them silently folding the other's cost in. The 515 s total exceeding the
494 s push timeout is exactly that separation visible in the wall clock: the lock wait is
not spent inside the push budget.

**AC 6.** `bin/fw vendor self --check` → *"vendored .agentic-framework/ in sync with
source"*, rc=0. The only vendored-class file this task touched is
`agents/audit/audit.sh`, synced in `eb4b49b60` with `FW_VENDOR_ONLY` so no other
session's dirty files were swept in. `tests/unit/` is not a vendored class.

T-3450 is updated off `issues` and its AC 4 recorded and ticked against this run's
evidence. **It is deliberately NOT closed here** — this AC says so, and producer-not-judge
says it independently. Its close is one command for whoever takes it.

**What this task did not do, on purpose.** No multiplier, floor or cap was widened. The
standing instruction in AC 5 was that a third instance of this class means the gate is
the thing to fix rather than its budget — that branch was not taken, because the gate had
not grown. 268 -> 325 -> 329 s is a cost that drifts slowly; what failed was reading a
two-day-old number as if it were current. The fix was to make the reading track the cost,
and the numbers now move on their own.
