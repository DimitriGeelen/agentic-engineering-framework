---
id: T-2857
name: "convention + gate: a task touching bin/fw or bin/fw-router must run fw test
  unit in Verification"
description: >
  Inception: convention + gate: a task touching bin/fw or bin/fw-router must run fw
  test unit in Verification

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: [bin/fw-router, tests/unit/fw_vendor_completeness.bats]
related_tasks: []
created: 2026-08-07T12:51:17Z
last_update: 2026-08-07T16:54:20Z
date_finished: 2026-08-07T16:54:20Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
# ── Inception scoring exception (T-2186 Slice 2 / T-2188). See 050-Inceptions.md §Scoring Exception. ──
target_blast_radius: 3            # int 0..9. Anticipated component count of the build work this inception would authorise on GO.
                                  # Substitutes for the absent components: list in the F8 cost formula (040). Required.
                                  # Guide: 0=docs only, 1=single file, 3=small subsystem (S), 5=cross-subsystem (M), 7=multi-arc (L), 9=framework-wide (XL).
voi_score: 0.5                    # float 0..1. Value of Information — expected value of resolving this question,
                                  # independent of build cost. Higher when answer affects many tasks or unblocks a strategic decision. Required.
cost_estimate_proposed:
  - ts: '2026-08-07T13:00:08Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
bvp_scores_proposed:
  - ts: '2026-08-07T13:00:14Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-AUTONOMY: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-AUTONOMY=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2857: convention + gate: a task touching bin/fw or bin/fw-router must run fw test unit in Verification

## Problem Statement

A change can delete a contract and leave that contract's tests asserting the old
one indefinitely, because **nothing requires the author to run the suite that
covers the file they just edited.**

Concrete origin (T-2856 RCA): T-2854 removed the router's global-install fallback
to complete D-377. Six tests across `tests/unit/fw_vendor_completeness.bats` (3/6)
and `tests/unit/fw_router.bats` (3/12) observed the property they protect
*through* that fallback — "did it hand over to the global?" stood in for "did it
decline to run the partial vendor?". Removing the mechanism removed the proxy.
All six went red **on that commit**, and the commit landed and was pushed. They
were found four commits later, incidentally, while running a neighbouring suite
for a different task.

The suites are **not orphaned** — `fw test unit` globs `tests/unit/`
(`bin/fw:7988`), so a runner exists and would have caught this. Nothing invoked
it. P-011 runs only what the author writes in `## Verification`, and T-2854's
Verification named neither suite.

Who this is for: any agent editing `bin/fw` or `bin/fw-router` — the two binaries
every consumer's onboarding path runs through. Why now: the same class shipped
twice in one week (T-2854 → T-2856), and `bin/fw` is the highest-traffic file in
the repo.

## Assumptions

- **A1** — The failure is *unrun tests*, not *missing tests*. If true, the remedy
  is a rail that invokes an existing runner, not new coverage.
- **A2** — This is the same shape as two rails CLAUDE.md already carries (cron
  registry→generated, tool-set→manifest): a documented convention that was
  violated repeatedly until it became a close-gate predicate.
- **A3** — The blast radius is small enough that a close-time gate is affordable:
  `fw test unit` over the router/vendor suites completes in seconds, not minutes.
- **A4** — Restricting the trigger to `bin/fw` + `bin/fw-router` covers the
  observed incidents without making every task pay the cost.

## Open Questions

- **IW-1: Which enforcement surface — close gate (P-011 predicate), pre-push hook, or `fw doctor` WARN?**
  confidence: 1
  disposition: deferred
  rationale: Close gate matches both prior-art rails (cron, tool-set) and is the earliest gate; but unlike those it must RUN a suite rather than compare two files, so cost and flakiness need measuring before committing. Spike S-2.

- **IW-2: What predicate defines "touches the CLI" — literal path match, or something broader?**
  confidence: 1
  disposition: deferred
  rationale: T-2854 edited `bin/fw-router` only, but the red tests were in a suite named after `fw`'s vendor path. A path-only trigger would have fired here; whether it generalises to `lib/*.sh` is unknown. Spike S-3.

- **IW-3: Should the gate require the suite in `## Verification` (declaration), or run it itself (execution)?**
  confidence: 2
  disposition: deferred
  rationale: Declaration is cheap and matches the existing rails' shape, but is satisfiable by writing a line that never runs green — the exact false-green class T-2732 was built to close. Execution is stronger and costs seconds. Leaning execution.

- **IW-4: How many past commits would this gate have caught, and how many would it have blocked spuriously?**
  confidence: 0
  disposition: deferred
  rationale: Unmeasured. This is the go/no-go evidence — a gate with a high false-positive rate on historical commits is a gate agents will learn to bypass. Spike S-1.

## Exploration Plan

- **S-1 (time-box 30 min) — Retrospective firing rate.** Walk the last N commits
  touching `bin/fw` or `bin/fw-router`. For each, check out the tree and run
  `fw test unit` over the router/vendor suites. Count: how many were red at that
  commit (true positives the gate would have caught), how many green (silent
  passes), how many red for *unrelated* pre-existing reasons (false positives
  that would have blocked an innocent author). **This is the decisive number.**
- **S-2 (time-box 20 min) — Cost.** Measure wall-clock of the candidate suite set
  cold. If a close gate adds >10s to every router task, prefer declaration.
- **S-3 (time-box 15 min) — Predicate breadth.** Grep which suites in
  `tests/unit/` actually exercise `bin/fw` / `bin/fw-router` behaviour, to see
  whether "the suites for this file" is even well-defined or needs a manual map.

## Technical Constraints

- `fw test unit` shells out to `bats`; availability is already a `fw doctor`
  concern, so the gate must degrade rather than hard-fail when bats is absent
  (same shape as the L-291 `command -v dotnet` guidance).
- Any close-gate predicate runs inside `update-task.sh`, which is itself invoked
  by hooks — a suite that spawns `fw` recursively risks re-entrancy. The reviewer
  dispatch guard (`FW_REVIEWER_IN_DISPATCH=1`) is prior art for the pattern.
- Historical replay in S-1 must pin the *suite* version, not check it out with
  the tree — otherwise it measures old tests against old code and answers a
  different question (the T-2849 wrong-object class, hit three sessions running).

## Scope Fence

**IN:** the trigger predicate, the enforcement surface, and the retrospective
firing-rate measurement for `bin/fw` and `bin/fw-router`.

**OUT:**
- Generalising to all of `lib/` — noted as a follow-on, deliberately not decided here.
- Fixing whatever S-1 turns up red. Each is its own task (one bug = one task).
- The two T-2849 design questions fenced out there and still open (whether
  `docs/reports`/`docs/screenshots` ship to consumers; whether `fw doctor` should
  size-check the per-project vendored copy rather than only `$HOME`).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Root cause identified with bounded fix path
- Fix is scoped, testable, and reversible

**NO-GO if:**
- Problem requires fundamental redesign or unbounded scope
- Fix cost exceeds benefit given current evidence

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

## Recommendation

**Recommendation:** GO

**Rationale:**

T-2856 RCA: T-2854 turned 6 tests red across 2 suites and it went unnoticed for 4 commits because P-011 runs only what the author writes. The runner exists (fw test unit globs tests/unit/); nothing invokes it on a router change. Same shape as the cron registry-to-generated and tool-set-to-manifest rails already in CLAUDE.md, both of which are enforced at close. Evidence is concrete and the remedy has two prior art examples, so this is GO on the convention; the open question is only enforcement surface (close gate vs pre-push vs doctor WARN).

**Evidence:**

<!-- Add evidence bullets as exploration progresses (file paths,
     commit hashes, test results). The filing-time recommendation
     can be revised before fw inception decide. -->

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

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale:

T-2856 RCA: T-2854 turned 6 tests red across 2 suites and it went unnoticed for 4 commits because P-011 runs only what the author writes. The runner exists (fw test unit globs tests/unit/); nothing invokes it on a router change. Same shape as the cron registry-to-generated and tool-set-to-manifest rails already in CLAUDE.md, both of which are enforced at close. Evidence is concrete and the remedy has two prior art examples, so this is GO on the convention; the open question is only enforcement surface (close gate vs pre-push vs doctor WARN).

Evidence:

**Date**: 2026-08-07T16:54:20Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-08-07T14:18:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-08-07T16:54:20Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale:

T-2856 RCA: T-2854 turned 6 tests red across 2 suites and it went unnoticed for 4 commits because P-011 runs only what the author writes. The runner exists (fw test unit globs tests/unit/); nothing invokes it on a router change. Same shape as the cron registry-to-generated and tool-set-to-manifest rails already in CLAUDE.md, both of which are enforced at close. Evidence is concrete and the remedy has two prior art examples, so this is GO on the convention; the open question is only enforcement surface (close gate vs pre-push vs doctor WARN).

Evidence:

## Reviewer Verdict (v1.5)

- **Scan ID:** R-eed40e28
- **Timestamp:** 2026-08-07T16:54:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

## Recommendation Verdict (v1.0)

- **Scan ID:** RC-dbe650ef
- **Timestamp:** 2026-08-07T16:54:21Z
- **Overall:** CONFIRMED
- **Claims:** 2

| Claim | Type | Status |
|-------|------|--------|
| `T-2856` | task | ✓ pass |
| `T-2854` | task | ✓ pass |

### 2026-08-07T16:54:20Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
