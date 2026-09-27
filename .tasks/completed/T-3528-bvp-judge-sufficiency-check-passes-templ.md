---
id: T-3528
name: "BVP judge sufficiency check passes template placeholder ACs: reuse the G-020
  detector instead of a length threshold"
description: >
  OBS-560. 'fw bvp judge T-3471' returns GREEN because lib/bvp_judge.py:140 _is_substantive()
  is a pure length threshold (MIN_SUBSTANTIVE_CHARS=15) and '[First criterion]' is
  17 characters. T-3471's ACs are the literal template placeholders, so the judge's
  SUFFICIENCY criterion — 'are they good enough to justify the score claimed' — approves
  template text. FIX: reuse the placeholder detection the framework already has rather
  than adding a third variant. agents/context/check-active-task.sh:1053 (the G-020
  scope gate) already detects '[First criterion]' template ACs, and T-3428 already
  established the stronger general rule — strip template text BEFORE matching, measured
  there as 'template-only prose scored 4 unstripped, 0 stripped'. Prefer extracting
  the existing predicate to a shared helper over copying it, since copying is how
  arc membership reached five readers. TEST THAT MUST EXIST: a fixture task whose
  ACs are the actual template placeholders must NOT come back green — none of T-3526's
  34 tests used one, which is exactly why a fully green suite shipped a false green.
  The verdict for a placeholder-AC task should be RED with guidance naming what to
  write, or AMBER at the softest; never green.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [bvp, judge, false-green]
components: [lib/ac_placeholder.py, lib/bvp_judge.py, lib/resolver.py, tests/unit/test_bvp_judge.py]
related_tasks: [T-3526, T-3428, T-3525]
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
created: 2026-09-27T21:36:54Z
last_update: 2026-09-27T22:29:53Z
date_finished: 2026-09-27T22:29:53Z
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
  - ts: '2026-09-27T21:45:10Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=269,acs=4)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-09-27T21:45:26Z'
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

# T-3528: BVP judge sufficiency check passes template placeholder ACs: reuse the G-020 detector instead of a length threshold

## Context

The BVP score judge (T-3526) shipped with its SUFFICIENCY check implemented as a
length threshold, which approved unfilled template criteria. Fixed by making the
framework's existing template-stub predicate the primary leg and consolidating the
two Python readers of it into `lib/ac_placeholder.py`.

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [x] One shared placeholder predicate exists (`lib/ac_placeholder.py`) and is the ONLY Python decision point for "is this AC template text": both `lib/bvp_judge.py` and `lib/resolver.py` import it, and neither carries its own copy of the ordinal-criterion stub literal any more.
- [x] `_is_substantive()` no longer decides on length alone — a template stub of ANY length (the default template's first ordinal stub is 17 chars, above the 15-char floor) is non-substantive. The length floor survives only as a second, weaker leg.
- [x] A task whose every AC is a template placeholder comes back RED, not GREEN and not AMBER: textually-present-but-template is equivalent to absence, and the guidance names what to write. Demonstrated live on T-3471 (the OBS-560 reproducer).
- [x] Control leg: a task with real substantive ACs still reaches GREEN. The fix must not be "everything is red now" — verified against a committed fixture, not only by reasoning.
- [x] Cross-language parity is pinned, not asserted: a test reads the placeholder patterns out of `lib/task-audit.sh` (the bash reader, which a PreToolUse hook cannot replace with python3) and asserts the Python predicate agrees on every one, so the two readers cannot drift silently.
- [x] The test that was missing exists: a fixture task carrying the ACTUAL template placeholder ACs, asserted non-green. Demonstrated in both directions — red against the pre-fix predicate, green against the fixed one.
- [x] `bin/fw vendor self --check` is clean BEFORE `--status work-completed` (OBS-250).

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

# The OBS-560 reproducer, live: the task whose ACs are the template stubs must NOT be green.
out=$(bin/fw bvp judge T-3471 2>&1); echo "$out" | grep -q '^RED' && ! echo "$out" | grep -q '^GREEN'
# The stubs are NAMED in the evidence, not just counted (that is what made the original hard to spot).
bin/fw bvp judge T-3471 > /tmp/.t3528-judge 2>&1; grep -q 'UNFILLED TEMPLATE STUBS' /tmp/.t3528-judge
# Control leg: a real-AC open task still reaches a non-RED verdict — the fix is not "everything is red".
out=$(bin/fw bvp judge T-3528 2>&1); ! echo "$out" | grep -q 'UNFILLED TEMPLATE STUBS'
# Predicate + cross-language parity suite (includes its own control leg).
python3 -m pytest tests/unit/test_ac_placeholder.py -q > /tmp/.t3528-ap 2>&1 && grep -q passed /tmp/.t3528-ap
# Judge suite including the fixture that was missing and the length-only mutant kill.
python3 -m pytest tests/unit/test_bvp_judge.py tests/unit/test_bvp_judge_dispatch.py -q > /tmp/.t3528-bj 2>&1 && grep -q passed /tmp/.t3528-bj
# The T-3525 contract still holds (the judge's shared vocabulary is untouched).
python3 tests/check_t3525_contract.py
# Entrypoint bats — assert nothing failed AND nothing silently skipped (T-3217).
timeout 300 bats tests/unit/t3526_bvp_judge_entrypoint.bats > /tmp/.t3528-bats 2>&1 && ! grep -q '^not ok' /tmp/.t3528-bats
test "$(grep -c '# skip' /tmp/.t3528-bats)" -eq 0
# resolver.py delegates the stub leg without widening dispatch eligibility (all-ticked stays ineligible).
PYTHONPATH=lib python3 -c "import resolver as r; assert r._ac_is_placeholder('- [x] A real substantive criterion here') is True; assert r._ac_is_placeholder('- [ ] A real substantive criterion here') is False; print('resolver semantics preserved')"
# Vendored paths in sync BEFORE close (OBS-250).
bin/fw vendor self --check

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

**Symptom:** `bin/fw bvp judge T-3471` returned `GREEN  T-3471 (proceed; nothing owed)`
with the evidence line `2/2 AC item(s) substantive (>= 15 chars after stripping prefix
markers)`. T-3471's entire Acceptance Criteria section is the two ordinal template stubs
the default template ships. The judge's SUFFICIENCY criterion — D-662's "are the criteria
good enough to justify the score claimed?" — approved an untouched template, and the
verdict was indistinguishable from a real pass.

**Root cause:** `lib/bvp_judge.py:_is_substantive()` decided substantiveness by
`len(stripped) >= MIN_SUBSTANTIVE_CHARS` (15). The first ordinal stub is 17 characters.
The check measured a *proxy* for "is anything actually stated" — text volume — and the
proxy diverges from the thing it stands for exactly at the template stubs, because the
template authors wrote descriptive placeholder names rather than short ones. Same class
as T-1828: a gate measuring a proxy that diverged from reality.

**Why structurally allowed:** three defences already existed and none was reused.
`agents/context/check-active-task.sh` (G-020) detects these exact stubs; `lib/task-audit.sh:79`
carries the widest pattern set; `lib/resolver.py:_ac_is_placeholder` carried a two-literal
version. T-3526 wrote a fourth, weaker variant beside them. Nothing in the build made the
existing predicate visible at the moment the new one was written, and the dispatch prompt's
"do not write a second definition" warning was scoped to the *verdict vocabulary*
(green/amber/red), which the worker honoured — it imported `lib/judge_verdict.py` correctly.
The warning did not generalise to *predicates the judge needs*.

Second leg: **the suite could not see it.** T-3526 closed with 9/9 ACs and 34 green tests.
Its fixture named `PLACEHOLDER_ACS` contained `TBD` / `fix it` — short authored text, which
exercises only the length leg. No fixture used the literal template stubs, so a suite that
was green in every direction it looked was blind in the one direction that mattered. A
fixture named after the class it does not contain is worse than a missing fixture, because
the coverage gap reads as covered.

**Prevention** (distinct from the fix):
1. `tests/unit/test_bvp_judge.py:TEMPLATE_STUB_ACS` — the real stubs, with
   `test_template_stub_acs_are_not_green` asserting RED.
2. `test_length_only_substantiveness_is_the_mutant_this_fixture_kills` restores the pre-fix
   predicate and asserts the SAME fixture goes GREEN — so the fixture is pinned as the thing
   that distinguishes the two implementations, and it fails loudly if it ever stops
   reproducing OBS-560.
3. `tests/unit/test_ac_placeholder.py::test_bash_and_python_readers_agree` extracts the LIVE
   regex from `lib/task-audit.sh` and runs it through real `grep -qE` against every canonical
   sample, with a control leg proving the parity test can fail. The two bash readers stay
   separate by design (one runs in a PreToolUse hook on every Write/Edit; making it shell out
   to `python3` trades a false green for a latency and availability risk on the busiest gate
   in the framework), so this test is the only thing holding the languages together.
4. Consolidation itself: two Python readers became one, so the next judge that needs this
   predicate has one obvious place to import from.

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

## Decision

<!-- Filled at completion of inception tasks via:
     fw inception decide T-XXX go|no-go|defer --rationale "..."

     For non-inception tasks this section is ignored. Kept in template
     so `fw inception decide` (lib/inception.sh) finds the anchor heading
     without auto-creating; T-1832 added auto-create as fallback for
     legacy tasks lacking this section. -->

## Updates

### 2026-09-27T21:36:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3528-bvp-judge-sufficiency-check-passes-templ.md
- **Context:** Initial task creation

### 2026-09-27T22:08:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ed93fb0c
- **Timestamp:** 2026-09-27T22:30:00Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 6
     - evidence: `out=$(bin/fw bvp judge T-3528 2>&1); ! echo "$out" | grep -q 'UNFILLED TEMPLATE STUBS'`

### 2026-09-27T22:29:53Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
