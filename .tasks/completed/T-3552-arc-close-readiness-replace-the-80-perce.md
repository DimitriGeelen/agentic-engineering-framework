---
id: T-3552
name: "arc close-readiness: replace the 80 percent ratio with L1 plus L2 quadrant
  exhaustion"
description: >
  arc close-readiness: replace the 80 percent ratio with L1 plus L2 quadrant exhaustion

status: work-completed
workflow_type: build
owner: agent
horizon: null
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
created: 2026-09-29T08:29:23Z
last_update: 2026-09-29T21:23:15Z
date_finished: 2026-09-29T08:40:00Z
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
  - ts: '2026-09-29T08:45:11Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius:
      tier: 2
      effort: 8
    rationale: blast_radius=? (no-components-UNMEASURED-not-zero); tier=2 
      (workflow:build); effort=8 (lines=418,acs=13)
    rubric_sha: e4a00f38e801
---

# T-3552: arc close-readiness: replace the 80 percent ratio with L1 plus L2 quadrant exhaustion

## Context

T-3548 Slice A. The operator's ruling, verbatim:

> *"the threshold for Arc should not be 80%, it should be no high value, low cost,
> no high cost items left anymore"* … *"no unestimated tasks, point. And then no
> high value, no Q1, Q1 and Q2, quadrant 1 and quadrant 2 tasks left. And then we
> also talked about validating if the R goals are achieved."*

Three legs:

| leg | predicate |
|---|---|
| **L1** | no unestimated open member — every one carries BOTH a value score and a cost |
| **L2** | no open member is high-value — neither `hv-lc` (Q1) nor `hv-hc` (Q2) remains |
| **L3** | the arc's goals are validated in the anchor's Recommendation + Rationale |

**What 80% actually measured.** `_load_close_ready_arcs(threshold=0.80)` is a
*completion ratio* — `completed / total` over constituents. It answers "how much of
the list is ticked", which is a statement about the list, not about the work. An arc
at 85% whose remaining 15% is the entire high-value core reads as close-ready; an arc
at 70% whose remainder is all low-value polish reads as not. Both backwards.

L1+L2 replace a proxy with the property: closure is about what is *left*, and value
is what makes leftovers matter.

**This is a surfacing heuristic, not the close gate.** `lib/arc.sh:arc_close()` has
no ratio check and gains none here — `fw arc close` stays agent-refused (T-1671) and
operator-owned. What changes is which arcs the operator is *shown*, and why.

**Precondition, now met (T-3551).** L1 was unevaluable until an hour ago: the cost
sweep excluded partial-complete tasks, which is exactly where `components:` lands, so
0 of 16 arcs could pass L1. After T-3551's sweep, 7 of 16 pass. A gate that refuses
everything carries no information — L1 only became worth wiring once it could
discriminate.

**One predicate, one reader.** The legs live in `lib/arc_close_readiness.py` so
`/approvals`, `/arcs/<slug>` and `fw review-queue` cannot drift apart. This repo has
already paid for the alternative: arc membership had five readers and three verdicts
(OBS-546). Quadrant classification is imported from `lib/bvp.sh`'s own python body
rather than re-derived, for the same reason.

### Result — measured against the live corpus

Corpus medians over OPEN tasks: value `0.2370` (n=491), cost `3.60` (n=261),
value axis **not** degenerate (so T-3485's `v-thin` withholding does not fire).

| | arcs surfaced |
|---|---|
| old `completion_ratio >= 0.80` | **8** |
| new L1+L2 | **2** — `onboarding-shape-detection`, `readme-first-run` |

The two the new predicate keeps are the two with **zero open members** — genuinely
finished. The six it drops are the point:

| arc | ratio | open | high-value open |
|---|---|---|---|
| `orchestrator-rethink` | 85% | 18 | **8** |
| `continuous-run` | 89% | 6 | 3 |
| `parallel-execution-aef` | 95% | 2 | 2 |
| `ewcr-arc0-contract-evidence` | 95% | 1 | 1 |
| `capability-overlay` | 80% | 3 | 1 (and L1 fails — unestimated) |
| `horizon-axis-hardening` | 80% | 1 | 1 |

Each read "close-ready" on the ratio while its remaining work was the high-value
part. That is the failure the ratio cannot see, because `completed / total` has no
term for what kind of thing is left.

Per-leg over all 16 in-progress arcs: **L1 passes 7**, **L2 passes 1**
(`project-shape-resilience`), **L1+L2 passes 2**. The legs disagree with each
other, which is what a predicate carrying information looks like.

## Acceptance Criteria

### Agent
- [x] `lib/arc_close_readiness.py` evaluates L1, L2 and L3 as separate, individually-reported legs
- [x] L1 fails when any OPEN member lacks a value score or a cost, and names the offending task IDs
- [x] L2 fails when any OPEN member classifies `hv-lc` or `hv-hc`, and names them
- [x] Quadrant classification is IMPORTED from `lib/bvp.sh`'s python body, never re-implemented
- [x] CONTROL: an arc whose open members are all low-value and fully estimated passes L1+L2
- [x] CONTROL: an arc with one unestimated open member fails L1 even when every other leg passes — so a pass cannot be reached by ignoring a leg
- [x] A CLOSED member never blocks a leg — closure is about what is left, not what was done
- [x] `_load_close_ready_arcs` surfaces on L1+L2 instead of `completion_ratio >= 0.80`, and the ratio is still reported as information
- [x] `fw arc close` remains agent-refused and gains no new gate — this task changes what is SURFACED, not what is permitted
- [x] Measured against the live corpus: which arcs the new predicate surfaces vs the old 80%, recorded in this task

- [x] [AGENT-REVIEWED] The Arc Closure section on `/approvals` reads correctly with the new, much shorter list
  **Steps:**
  1. `cd /opt/999-Agentic-Engineering-Framework && bin/fw watchtower url`
  2. Open the printed URL, go to `/approvals`, find the **Arc Closure** section.
  3. It should list **2 arcs** (`onboarding-shape-detection`, `readme-first-run`) where it previously listed 8.
  4. `onboarding-shape-detection` should render WITHOUT a verdict badge and WITH its blocked reason (its anchor has no `## Recommendation`); `readme-first-run` should show `GO`.

  **Expected:** the section still reads as a queue rather than an error — a
  near-empty list is the honest answer here (6 of the 8 arcs it used to show still
  have high-value work open), but you are the judge of whether it *reads* that way
  or reads as broken.

  **If not:** say which of the two it reads as, and whether the section needs a
  line explaining why arcs left it. The predicate itself is pinned by
  `tests/unit/test_t3552_arc_close_readiness.py`; this criterion is only about how
  the shortened list presents.

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

  **Reviewed 2026-09-29 by an independent agent reviewer (not the producer): GREEN on re-review after T-3571 fixed the first review's amber findings (invisible anchor link, stale ≥80% wording, raw backticks).** Report: `docs/reports/T-3557-render-review-2026-09-29.md`. Moved from `### Human` on the operator's ruling (T-3557 IW-1, 2026-09-29): "These are not things I need to decide on review… That's low risk stuff."


### Human


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
timeout 300 python3 -m pytest tests/unit/test_t3552_arc_close_readiness.py -q > /tmp/.t3552.out 2>&1 && grep -q "17 passed" /tmp/.t3552.out
test "$(grep -c 'failed\|error' /tmp/.t3552.out)" -eq 0
timeout 300 python3 -m pytest tests/web/test_approvals_blocked_arcs.py tests/unit/test_approvals_expand_overflow.py -q > /tmp/.t3552b.out 2>&1 && grep -q "passed" /tmp/.t3552b.out
test "$(grep -c 'failed\|error' /tmp/.t3552b.out)" -eq 0
python3 -c "import ast; ast.parse(open('web/blueprints/approvals.py').read()); ast.parse(open('lib/arc_close_readiness.py').read()); ast.parse(open('lib/bvp_py.py').read())"
# the quadrant classifier is IMPORTED, never re-implemented (OBS-546 class)
test "$(grep -c 'def quadrant' lib/arc_close_readiness.py)" -eq 0
grep -q 'bvp.quadrant(' lib/arc_close_readiness.py
# the ratio is no longer the predicate
grep -q '_arc_readiness_legs' web/blueprints/approvals.py
# fw arc close gains NO new gate — this task changes what is surfaced, not what is permitted
test "$(grep -c 'arc_close_readiness\|_arc_readiness_legs' lib/arc.sh)" -eq 0
bin/fw watchtower current
bin/fw vendor self --check

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

**Recommendation:** GO

**Rationale:** The predicate is built, pinned and measured, and the one thing left
is a judgement I cannot make for you: whether a two-row Arc Closure section *reads*
as a queue or as a breakage. The substance is settled — 6 of the 8 arcs the 80%
ratio called close-ready still have high-value work open, and the two that remain
are the two with zero open members. What I can't tell from here is whether the
operator opening `/approvals` tomorrow will read the short list as "good, almost
nothing is actually ready" or as "the page is broken". That is a render judgement,
which is why it stayed a `[REVIEW]` rather than being routed to the reviewer.

Nothing here permits a closure that was not permitted before: `fw arc close` is
still agent-refused (T-1671), still operator-owned, and gained no new gate —
verification line 9 asserts `lib/arc.sh` does not import the predicate at all.

**Evidence:**
- 17 tests, 0 skips, both controls present; the unmeasured-remainder guard verified
  RED against a deliberately broken build (L2 passing when nothing is classifiable).
- Old vs new on the live corpus: 8 arcs surfaced → 2; per-leg L1 passes 7, L2 passes
  1, so the legs disagree with each other rather than moving together.
- `orchestrator-rethink`: 85% complete, 18 open members, **8 of them Q1/Q2** — the
  clearest single instance of what the ratio could not see.
- Quadrant classification imported from `lib/bvp.sh` via the new `lib/bvp_py.py`,
  never re-derived; pinned by a test that fails if anyone writes a local `quadrant`.
- The population difference from `fw bvp` (this includes partial-complete, the
  ranking excludes it) is documented in the module docstring rather than left to be
  discovered — 134 of 152 open arc members are partial-complete, so on the ranking's
  population L2 would pass every arc by never looking.

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

### 2026-09-29T08:29:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-3552-arc-close-readiness-replace-the-80-perce.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ee640f77
- **Timestamp:** 2026-09-29T08:40:41Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-09-29T08:40:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
