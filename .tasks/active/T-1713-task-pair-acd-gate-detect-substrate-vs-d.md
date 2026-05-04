---
id: T-1713
name: "Task-pair §ACD gate: detect substrate-vs-deliverable conflation at work-completed time (G-066 prong 2)"
description: >
  Inception: Task-pair §ACD gate: detect substrate-vs-deliverable conflation at work-completed time (G-066 prong 2)

status: captured
workflow_type: inception
owner: human
horizon: now
tags: [arc:orchestrator-rethink, ACD, G-062-family, governance-gate]
components: []
related_tasks: [T-1442, T-1443, T-1668, T-1671, T-1709, T-1711]
created: 2026-05-04T06:43:45Z
last_update: 2026-05-04T06:43:45Z
date_finished: null
---

# T-1713: Task-pair §ACD gate: detect substrate-vs-deliverable conflation at work-completed time (G-066 prong 2)

## Problem Statement

§ACD gates currently exist only at arc closure (G-062 family, T-1668/T-1671):
`fw arc close` requires `--demo` evidence + a captured `--headline-mechanic`,
and refuses under `$CLAUDECODE=1` (default-to-OPEN). Per-task closures via
`fw task update --status work-completed` have NO equivalent gate.

Effect (verified 2026-05-04, see G-066): T-1442 (inception, GO) +
T-1443 (build, work-completed) closed clean while two of three GO-promised
deliverables silently dropped (auto-tick + TermLink-dispatch reviewer
halves never wired). The §ACD substrate-vs-deliverable conflation pattern
that defined the orchestrator-rethink arc happens at the per-task level
too — not just at arc level.

For whom: framework agents proposing/closing inception/build pairs; human
reviewer who currently has to discover the gap manually months later.
Why now: G-066 pattern documented; T-1709 (one fix path) is awaiting GO;
prevention belongs in the gate, not the recovery (G-019 doctrine).

## Assumptions

A1. Inception tasks producing GO with multi-deliverable Recommendation
    blocks are mechanically parseable — the deliverables are listed
    (numbered or bulleted) under `## Recommendation` or in a discoverable
    structure.
A2. The build task or task-pair shipping the implementation can be
    cross-referenced via `related_tasks` frontmatter or `git log
    --grep=T-XXX` traceability.
A3. A "deliverable promised vs deliverable shipped" comparison can be
    evaluated mechanically (text presence in implementation files, fabric
    cards, bats tests) without LLM judgment in the common case — and where
    it can't, the gate should refuse rather than guess.
A4. Adding the gate at `fw task update --status work-completed` (mirror of
    T-1259/T-1671 inception/arc gate pattern) is the right insertion point.

## Exploration Plan

Three spikes to test the assumptions, time-boxed at 1 session each:

1. **Parser spike** — Take 5 work-completed inception tasks with
   multi-deliverable GO Recommendations (T-1442/T-1443 + 4 others mined
   from `.tasks/completed/`). Extract the deliverable lists mechanically.
   Test A1: do the parsers agree with a human-graded list ≥80% of the time?

2. **Comparison spike** — For each parsed deliverable, define a
   verification predicate (file exists, function exists, test exists, etc).
   Run against the actual repo state at the build-task work-completed
   commit. Did the gate would-have caught T-1442/T-1443's missing halves?
   Did it produce false positives on cleanly-shipped tasks?

3. **Insertion-point spike** — Implement the gate as a hook called from
   `update-task.sh` when `--status work-completed` is requested AND the
   task's `related_tasks` (or `## Context`) reference an inception task
   with `Recommendation: GO`. Verify it can be bypassed only with explicit
   `--scope-reduction-acknowledged "rationale"` (logged to
   `.context/working/.gate-bypass-log.yaml` like Tier 2).

## Technical Constraints

- The gate must NOT block any build task whose inception parent had a
  single-deliverable Recommendation (most tasks). False positive cost is
  high — operators will start using `--force` reflexively, eroding the
  gate.
- The gate must work without LLM dependency for the common case — relying
  on LLM judgment at the gate would inject the orchestrator's own
  uncertainty into framework governance (anti-pattern per ADR-0002).
- Bypass must be present and logged: `--scope-reduction-acknowledged`
  flag follows existing Tier 2 pattern.
- Insertion point already exists: `lib/update-task.sh` already runs P-010
  (AC checkbox check) + P-011 (verification block) before transitioning to
  `work-completed`. Add a P-012 §ACD-pair check.

## Scope Fence

IN scope:
- Mechanical parser for `## Recommendation` deliverable lists in inception
  task files.
- Comparison predicate against fabric cards / file existence / bats test
  presence — no LLM, no semantic understanding.
- Hook integration into `lib/update-task.sh` work-completed transition.
- Bypass flag + log entry.

OUT of scope:
- Closing G-066. The gate is prong 2 of G-066's recommendation; closing
  G-066 also requires prong 1 (T-1709 wiring). They're independent and
  this inception only addresses prong 2.
- Backfilling the gate against historical work-completed tasks (would
  surface dozens of legitimate as-designed scope reductions). Forward-only.
- Generalising to non-inception/build pairs (e.g. refactor + test pairs).
  Start with the most-evidenced pattern.

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

<!-- Fill these BEFORE writing the recommendation. The placeholder detector will block review/decide if left empty. -->
**GO if:**
- Parser spike achieves ≥80% agreement with human-graded deliverable lists
  on the 5-task sample.
- Comparison spike would-have-caught T-1442/T-1443 AND produced ≤1 false
  positive across 5 cleanly-shipped tasks (G-066 baseline).
- Insertion-point spike confirms `update-task.sh` is the correct hook
  point with bypass shape compatible with existing Tier 2 logging.

**NO-GO if:**
- Parser cannot reach 80% on free-text Recommendation blocks → either the
  Recommendation format needs structural enforcement first (separate
  inception), or LLM-judgment dependence makes the gate unreliable.
- False positive rate >20% → operators will paper over with `--force`,
  gate is worse than nothing.
- Insertion in `update-task.sh` requires breaking the existing P-010/P-011
  contract → re-design needed.

**DEFER if:**
- Spike data is mixed and the value vs cost is unclear; check back after
  T-1709 ships and we see whether prong 1 alone closes G-066 in practice.

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

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
