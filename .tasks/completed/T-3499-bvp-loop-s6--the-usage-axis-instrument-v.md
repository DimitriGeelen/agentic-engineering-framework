---
id: T-3499
name: "BVP loop S6 — the usage axis: instrument verb invocation, because hook-telemetry
  counts hooks not verbs"
description: >
  BVP loop S6 — the usage axis: instrument verb invocation, because hook-telemetry
  counts hooks not verbs

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:value-prioritisation]
components: [bin/fw]
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
created: 2026-09-26T08:25:31Z
last_update: 2026-09-26T08:46:06Z
date_finished: 2026-09-26T08:46:06Z
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
  - ts: '2026-09-26T08:27:27Z'
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
  - ts: '2026-09-26T08:27:34Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=328,acs=12)
    rubric_sha: e4a00f38e801
---

# T-3499: BVP loop S6 — the usage axis: instrument verb invocation, because hook-telemetry counts hooks not verbs

## Context

Slice S6 of `docs/architecture/bvp-feedback-loop.md` (T-3484, GO 2026-09-26): the
**usage** leg of the VALUE axis. The operator asked for it directly — *"we should
measure if it's actually being used, and it's used effectively."*

**The design doc's premise for this slice is false, which is why the slice starts
with a writer rather than a reader.** §4.3(a) says usage comes from
*"verb-invocation counts, from `lib/hook-telemetry.sh` and the existing
counters."* Measured 2026-09-26: `lib/hook-telemetry.sh` counts **hooks, not
verbs** — `.context/working/.hook-counter` holds `check-active-task=793`,
`budget-gate=8970`, and no fw verb appears anywhere in it. `grep -rln
"verb-counter\|verb_counter" bin/ lib/ agents/` returns nothing, and `bin/fw` has
no invocation telemetry at all. So verb usage is **not** available; coverage is
zero, not thin.

That makes this the same shape as S5 (OBS-540: `revisit_at` exists in the
template, set on 1 task of 1,196) and the fourth instance of one pattern in the
loop's own design:

| signal | infrastructure | actually fed |
|---|---|---|
| COST — `dispatches.jsonl` | exists | yes, 7.67% |
| QUALITY — `feedback-stream.yaml` | exists | yes, 4.8% |
| VALUE/revisit — `revisit_at` + G-053 | exists | 1 of 1,196 |
| VALUE/usage — `hook-telemetry.sh` | exists | **counts the wrong thing: 0** |

The doc reads all four as available. Two are not. **Infrastructure existing is not
the same as infrastructure being fed** — the arc's recurring
"detection exists, routing does not" defect, this time inside the plan rather
than the code. Correcting §4.3(a) and §8 is part of this slice, because a GO'd
design with a false availability claim will cost the next implementer the same
discovery.

**Why usage must be paired with discoverability** (design §4.3(a), kept): a verb
nobody calls may be *unused* or merely *unknown*, and the correct response differs
— retire versus surface. An unpaired usage count would retire
discoverable-but-unknown features. That pairing is an acceptance criterion here,
not a later refinement.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] `bin/fw` increments a per-verb counter at its single dispatch point, before the
      `case` — required, because most branches `exec` and would never return.
      → `bin/fw:5655`ff, immediately after `cmd` is set and before `case "$cmd" in`.
      Confirmed live: `.verb-counter` accumulated `pickup`, `mirror`, `audit`, `bvp`,
      `sidecar` from background cron invocations nobody triggered by hand.
- [x] The `hook` verb is **excluded**, with the reason recorded: hook dispatch is
      already counted in `.hook-counter`, and it is the hot path, so excluding it
      avoids paying telemetry cost twice on the most frequent invocation.
      → `[ "$cmd" != "hook" ]` in the guard; reason in the block comment; classified
      `not-instrumented` (never `unused`) by the reader, pinned by
      `test_hook_is_reported_as_not_instrumented_not_as_unused`.
- [x] The increment reuses `_fw_telemetry_increment` from `lib/hook-telemetry.sh`
      (flock-serialised, degrade-to-allow) rather than a second hand-rolled
      read-modify-write. A naive RMW loses ~99% of increments under concurrency —
      measured in T-3371/OBS-417, 1600 expected vs 17 recorded.
- [x] Instrumentation is fail-open: a broken or unwritable counter must never change
      `bin/fw`'s exit code or emit output on any path. Proven by a test that makes the
      counter unwritable and asserts the verb still succeeds silently.
      → `test_instrumentation_is_fail_open_when_the_counter_cannot_be_written`
      (chmod 0o500 on the working dir; exit code compared against the opt-out run).
- [x] `FW_VERB_TELEMETRY=0` disables the increment; proven by a test.
      → `test_the_real_dispatcher_counts_a_verb_and_honours_the_opt_out`, asserted on
      byte-identical counter content before/after.
- [x] `lib/bvp_usage.py` reads the counter and classifies every verb into exactly one
      of **used / discoverable-but-unused / undiscoverable-and-unused**, pairing each
      count with discoverability (present in `fw help` output, named in CLAUDE.md).
      → The verb universe is **parsed from `bin/fw`'s own dispatch case**, not
      hand-listed: a hand-listed universe drifts on the next verb added, and a verb
      missing from the universe can never be reported unused however long it sits.
- [x] CONTROL LEG: a test proves a discoverable-but-unused verb is **not** reported as
      retirable, and that the three classes are distinguishable.
      → `test_a_discoverable_but_unused_verb_is_NOT_retirable` plus
      `test_the_two_unused_classes_are_not_collapsed`. `retirable()` returns only
      `undiscoverable-and-unused`.
- [x] An absent counter file reports `available: False`, not a corpus of zero-usage
      verbs — same rule S1/S4 apply to cost and quality (unmeasured ≠ zero).
      → `test_an_absent_counter_is_unavailable_not_a_corpus_of_zeros`, and
      `test_an_absent_counter_recommends_retiring_nothing` for the dangerous shape
      (no data read as "nothing is used, delete it all").
- [x] Added per-invocation latency is **measured and reported in the task body**, not
      asserted as negligible.
      → **+6.8 ms on a ~630 ms invocation, ≈1.1%.** A/B, 10 reps each, same verb:
      with telemetry 6.362 s total (636.2 ms/call), with `FW_VERB_TELEMETRY=0`
      6.294 s (629.4 ms/call). Isolated source+increment microbenchmark: 4.02 ms per
      rep over 50 reps, including subshell fork.
- [x] `docs/architecture/bvp-feedback-loop.md` §4.3(a) and §8 corrected with the
      measured feed state above, so the next reader is not told usage is available.
      → §4.3(a) carries an explicit CORRECTION block; new §4.3(a-bis) tabulates all
      four signals' feed state; §8 gains **the write-half rule** and re-prices S5,
      which the doc had described as "reuses an existing field and scan".

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

out=$(python3 -m pytest tests/unit/test_bvp_usage_axis.py -q 2>&1); echo "$out" | grep -q "14 passed" && ! echo "$out" | grep -q "failed"
# bin/fw is the entry point for every framework command: a syntax error here
# bricks the whole toolchain, so parse it explicitly rather than trusting tests.
bash -n bin/fw
# The instrumentation must be BEFORE the dispatch case (most branches exec).
grep -q "FW_VERB_TELEMETRY" bin/fw
# The negated-class guard, not the glob-as-regex one this task first shipped.
grep -q '\*\[!a-z0-9-\]\*' bin/fw
# Vendored copies of both files this task changed must match their sources.
cmp -s bin/fw .agentic-framework/bin/fw
cmp -s lib/bvp_usage.py .agentic-framework/lib/bvp_usage.py
# The design-doc correction is present, so the false availability claim is gone.
grep -q "counts \*\*hooks, not verbs\*\*" docs/architecture/bvp-feedback-loop.md

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

### 2026-09-26 — the key guard looked like a regex and was a glob; it corrupted the live counter

- **What changed:** The first guard was `case "$cmd" in [a-z][a-z0-9-]*)`, which
  reads as "lowercase letter followed by more of the same". It is not. **In a
  shell `case` glob, `*` matches any characters — it does not repeat the preceding
  bracket class the way a regex `*` would.** So `fw 'evil=injected'` matched (the
  `*` absorbed `=injected`) and wrote a corrupt line into the real
  `.context/working/.verb-counter`, which is a flat `key=count` file: an
  unguarded key rewrites the file's own grammar. Found by running the adversarial
  input rather than by reasoning about the pattern.
- **Plan impact:** Guard replaced with a **negated class** (`*[!a-z0-9-]*` →
  reject), which is the correct idiom. Both the working form and the broken form
  are now asserted by `test_a_key_with_a_shell_metacharacter_is_rejected` — the
  test fails if the glob-as-regex pattern ever returns.
- **Triggered:** Nothing filed. Recorded because "pattern that reads as a regex in
  a context where globs apply" is a live hazard in this repo's shell surfaces, and
  the failure mode is silent data corruption rather than an error.

### 2026-09-26 — the test suite wrote to the state it was measuring

- **What changed:** The end-to-end test passed `PROJECT_ROOT=<tmp>` and assumed
  isolation. `bin/fw` prefers an inherited `CLAUDE_PROJECT_DIR` over an explicit
  `PROJECT_ROOT` (the T-2390 hook/$HOME-poison branch), and the helper also ran
  with `cwd` inside the real repo, letting `find_project_root` re-anchor. So the
  suite's increments landed in the **live** counter: `decisions` went from 2 to
  **14**. The test then failed for the right reason — its fixture counter was
  empty — which is the only thing that surfaced it.
- **Plan impact:** `_run_fw` now strips `CLAUDE_PROJECT_DIR`, `TASKS_DIR`,
  `CONTEXT_DIR` and `_FW_PATHS_DERIVED_BY`, and runs with `cwd` at the throwaway
  root. Verified by comparing the live counter before and after a full suite run:
  `decisions=14` both times, i.e. the suite no longer writes live state. The
  contaminated first window was then reset, and the clean baseline starts
  **2026-09-26T08:41:19Z**.
- **Triggered:** Nothing filed — same family as T-3250, already on record, whose
  close-gate harness wrote 34 junk tasks into the live repo. Worth noting that
  the instrument's own first measurements were the ones corrupted: a usage counter
  is unusually easy to pollute from the tests that verify it.

### 2026-09-26 — the design doc's premise was false, and it is the second time

- **What changed:** §4.3(a) presented verb usage as available from
  `lib/hook-telemetry.sh`. That module counts **hooks**; no fw verb appears in
  `.hook-counter`, and no verb counter existed anywhere. Coverage was zero, not
  thin. This is the same shape as S5's `revisit_at` (OBS-540: present in the
  template, set on 1 task of 1,196) — two of the loop's four signals rested on
  infrastructure that existed but was **not fed**.
- **Plan impact:** S6 became writer-first instead of reader-first, which moved its
  cost from "read an existing counter" to "instrument the entry point of every
  framework command". §8 gains an explicit **write-half rule**, and S5 is
  re-priced: it is not "reuses an existing field and scan", it is "instrument the
  close path, then read".
- **Triggered:** No new task. The correction and the generalisation are both in
  `docs/architecture/bvp-feedback-loop.md` (§4.3(a) CORRECTION, new §4.3(a-bis),
  §8 write-half rule), because the defect is in the plan and that is where a
  future implementer will read it.

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

### 2026-09-26T08:25:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3499-bvp-loop-s6--the-usage-axis-instrument-v.md
- **Context:** Initial task creation

### 2026-09-26T08:44:32Z — status-update [task-update-agent]
- **Change:** tags: +arc:value-prioritisation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4f6da9d5
- **Timestamp:** 2026-09-26T08:46:17Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-26T08:46:06Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
