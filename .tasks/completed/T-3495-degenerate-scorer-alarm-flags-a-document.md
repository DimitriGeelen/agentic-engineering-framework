---
id: T-3495
name: "degenerate-scorer alarm flags a documented scoring exception and misses the
  real flatness: teach it each family's actual axis"
description: >
  OBS-539. lib/bvp_degenerate.py fires on inception for flat D1-D4, but inceptions
  are scored on voi_score + target_blast_radius by ruling T-2186/T-2188 (estimator.py:2668,
  050-Inceptions.md Scoring Exception). So it flags a design decision (T-3453 inverted-alarm
  class, trains dismissal) while missing that voi_score variance is 0.0008 with 489
  of 496 at the 0.5 template default. Two halves: respect the exception, and measure
  the axis each family actually uses.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [arc:value-prioritisation]
components: []
related_tasks: []
arc_id: value-prioritisation
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
created: 2026-09-25T23:54:47Z
last_update: 2026-09-26T00:02:02Z
date_finished: 2026-09-26T00:02:02Z
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
  - ts: '2026-09-25T23:55:38Z'
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
  - ts: '2026-09-25T23:56:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      estimator-fidelity: 0
      D1: 4
      D2: 4
      D3: 3
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: estimator-fidelity=0 (no-signal); D1=4 (body:structural-gate); 
      D2=4 (body:fw-audit-or-doctor); D3=3 (body:component-discoverability); 
      D4=2 (body:env-class-handled); F-RECALL=2 (body:lightly-promoted); 
      F-AUTONOMY=0 (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-09-25T23:56:25Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=313,acs=10)
    rubric_sha: e4a00f38e801
---

# T-3495: degenerate-scorer alarm flags a documented scoring exception and misses the real flatness: teach it each family's actual axis

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Context

OBS-539. A defect in `lib/bvp_degenerate.py`, shipped under T-3489 earlier in
this same session. It has a false positive and a matching blind spot **on the
same family, at the same time.**

**False positive.** It flags `inception` for flat D1-D4. But inceptions are
deliberately not scored on D1-D4 — `estimator.py:2668` cites
`050-Inceptions.md §Scoring Exception`, and `voi_score` + `target_blast_radius`
are the inception axis by ruling T-2186/T-2188. 496 inceptions carry both fields.
**An alarm that fires on a documented design decision trains its reader to ignore
it**, which is worse than no alarm and is the T-3453 inverted-alarm class.

**Blind spot.** Measured across 496 inceptions:

| field | variance | distinct | modal |
|---|---:|---:|---|
| `voi_score` | **0.0008** | 5 | **0.5 on 489 of 496 (98.6 %)** |
| `target_blast_radius` | 0.05 | 4 | — |

`voi_score` is required by `agents/context/check-inception-schema.py` and consumed
by `lib/govd_envelope.py`'s `min_voi_score` breach check. **A validated,
load-bearing field is a constant, so the breach check it feeds cannot
discriminate either.** The alarm never looked, because it only reads D1-D4.

So the fix is one change with two effects: teach the detector **which axis each
family is actually scored on**. Inception flatness then stops being reported
against the wrong drivers and starts being reported against the right ones.

**Write-set fence.** `lib/bvp.sh` is still held uncommitted by the
`bvp-equality` worker (T-3485). This task touches `lib/bvp_degenerate.py` and its
test only.

## Acceptance Criteria

### Agent
- [x] The detector knows per-family which axis applies, and no longer reports the inception family as flat on drivers that family is not scored on
- [x] It measures `voi_score` variance for inceptions and **fires** on the real flatness — 0.0008 variance with 98.6 % at the template default must surface, naming the modal value
- [x] **Control leg retained:** a well-spread family on its own axis still does NOT fire, so the detector is proven to discriminate rather than to always fire
- [x] The exception is read from a declared mapping, not hardcoded per call site, so the next scoring exception is one table entry rather than a new branch
- [x] A family whose axis is unknown to the detector is reported as **unknown-axis, not as healthy** — an unrecognised family must never read as a pass (T-3099 class)
- [x] The live run distinguishes the two cases: inception no longer appears as flat-on-D1-D4, and DOES appear as flat-on-voi_score
- [x] Existing T-3489 tests still pass, or any that encoded the false positive are corrected with the reason recorded rather than deleted
- [x] `lib/bvp.sh` and `policy/value-drivers.yaml` untouched, verified by `git diff --name-only`

### Human
<!-- none: mechanical detector, no rendering surface -->

## Result

Live run, exit 1:

```
  [ok]    build          n=2558  axis=drivers  var={D1:2.86 D2:1.92 D3:1.83 D4:1.41}
  [FIRED] inception      n=496   axis=voi      var={voi_score: 0.0008}
          flat on ['voi_score'] (floor 0.01); modal 0.5 on 489 of 496 (98.6%)
                                              — value-of-information, float 0..1
  [FIRED] test           n=162   axis=drivers  flat on ['D2'] (floor 0.5)
  [ok]    refactor / specification / design
  [INSUFFICIENT] decommission n=3
  [FIRED] concentration  top-2 share=34.6% (ceiling 25%), 155 distinct patterns
```

**Both halves land in one change.** Inception stopped being judged on drivers it
is not scored on, and started being judged on the axis it is — where the real
flatness is far worse: `voi_score` variance **0.0008**, modal **0.5 on 489 of
496 (98.6 %)**, the template default.

**A second defect the fix exposed.** The old detector applied one global floor of
`0.5` to every family. Maximum possible variance on a 0..1 float is 0.25, so had
it ever looked at `voi_score` it would have reported flat **unconditionally** — a
check that can only ever fire. Each axis now carries a floor scaled to its own
range (`drivers` 0.5 on 0-5 integers, `voi` 0.01 on 0..1), and a test asserts the
relationship so the two cannot be collapsed back into one number.

**Concentration got more accurate as a side effect:** 34.6 %, up from the 29.7 %
reported before — inception rows had been diluting the driver-scored population.
A test now asserts they are excluded, because before the axis table an inception
row would either `KeyError` on `D1` or be zero-filled and counted as a pattern it
never had.

**Four fixtures had to move, and that is the new behaviour working.** Tests using
`"hygiene"`, `"mixed"` and `"rare"` now correctly report `unknown-axis` —
undeclared families are no longer silently measured on the directives, which is
precisely how the inception false positive arose. Moved to a declared family with
the reason recorded in the file rather than deleted.

Suites: `test_bvp_degenerate_alarm.py` (19) + `test_bvp_outcomes_ledger.py` (14)
= **33/33, 0 skips**.

**Write-set fence held.** Change set is `lib/bvp_degenerate.py` and its test.
`lib/bvp.sh` and `tests/unit/test_bvp_quadrant_value_axis.py` are the
`bvp-equality` worker's (T-3485), untouched.

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

timeout 300 python3 -m pytest tests/unit/test_bvp_degenerate_alarm.py tests/unit/test_bvp_outcomes_ledger.py -q > /tmp/.t3495v.out 2>&1 && grep -q "33 passed" /tmp/.t3495v.out
test "$(grep -c '# skip' /tmp/.t3495v.out)" -eq 0
# Inception is measured on voi, never on the directives it is exempt from.
python3 -c "import sys; sys.path.insert(0,'.'); from lib import bvp_degenerate as d; v=[f for f in d.report('.')['families'] if f['family']=='inception'][0]; assert v['axis']=='voi', v; assert 'D1' not in v.get('variance',{}), v"
# The detector still discriminates: at least one family passes.
python3 -c "import sys; sys.path.insert(0,'.'); from lib import bvp_degenerate as d; vs={f['verdict'] for f in d.report('.')['families']}; assert 'ok' in vs, 'fires on every family'; assert 'fired' in vs, 'fires on nothing'"
# Each axis floor is scaled to its own range — one global floor could only ever fire on a 0..1 field.
python3 -c "import sys; sys.path.insert(0,'.'); from lib import bvp_degenerate as d; assert d.AXES['voi']['floor'] < d.AXES['drivers']['floor']; assert d.AXES['voi']['floor'] <= 0.25"
# An undeclared family is never reported healthy.
python3 -c "import sys; sys.path.insert(0,'.'); from lib import bvp_degenerate as d; v=d.family_verdicts([('made-up',{k:4 for k in d.DRIVERS})]*9)[0]; assert v['verdict']=='unknown-axis', v"

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

### 2026-09-26 — the detector I shipped an hour earlier was wrong, and its own finding led me to the wrong fix first

- **What changed:** S2 (T-3489) reported the inception family as flat on D1-D4 and
  I believed it. Acting on that, I filed T-3494 to fix the estimator. Three
  hypotheses in, the premise collapsed: inceptions are scored on `voi_score` by
  ruling T-2186/T-2188, so the estimator was correct and **my detector was
  reporting a documented design decision as a defect.**
- **Plan impact:** the disproof was worth more than the task. T-3494 is parked
  with all three hypotheses recorded — including the two I got wrong (inception
  bodies are *not* thin, median 7,412 chars; build-shaped regexes are *not* the
  cause, since a uniform 2 across nine unrelated rubrics is a default, not a
  miss). The real defect was one level up, in my own week-old code, and fixing it
  surfaced the flatness that actually matters: `voi_score` at 0.0008 variance
  with 98.6 % on the template default. **A field that is validated by a schema
  check and consumed by a breach check, and is a constant.**
- **Triggered:** OBS-539 (this defect), OBS-538 (a gate whose block message names
  `--horizon later` as the escape and then refuses that exact command when piped
  — the T-3454 contract-collision class, hit live while parking T-3494), and a
  second defect found only by fixing the first: one global variance floor of 0.5
  applied to a 0..1 field could only ever report flat, so the voi axis would have
  been a permanently-firing check had it ever been wired.
- **The lesson worth keeping:** a detector shipped without knowing what its
  subject is *supposed* to look like will flag the design as the bug. S2's control
  leg proved it discriminated between spread and flat; nothing proved it was
  measuring the right thing. **Discrimination is not correctness.**

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

### 2026-09-25T23:54:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3495-degenerate-scorer-alarm-flags-a-document.md
- **Context:** Initial task creation

### 2026-09-25T23:55:38Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-09-25T23:56:24Z — status-update [task-update-agent]
- **Change:** tags: +arc:value-prioritisation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-15a982cd
- **Timestamp:** 2026-09-26T00:02:09Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#8 (Agent)** — `lib/bvp.sh` and `policy/value-drivers.yaml` untouched, verified by `git diff --name-only`
  - **AC-verify-mismatch** (narrow, heuristic) — `path=policy/value-drivers.yaml in: `lib/bvp.sh` and `policy/value-drivers.yaml` untouched, verified by `git diff --name-only``

### 2026-09-26T00:02:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
