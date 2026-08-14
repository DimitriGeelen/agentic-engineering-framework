# T-1713 — Task-pair §ACD gate: detect substrate-vs-deliverable conflation at work-completed

> **Inception research artifact** (backfilled by T-2515 from the `T-1713` task body — the research was captured in-task at decision time; this extracts it verbatim to the canonical `docs/reports/` home per C-001). Source: `.tasks/completed/T-1713-task-pair-acd-gate-detect-substrate-vs-d.md`. **Decision recorded: GO.**

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

## Go/No-Go Criteria

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

## Recommendation

**Recommendation:** GO

**Rationale:**

Three convergent reasons:

1. **G-066 evidence is hard.** T-1442 (inception, GO) + T-1443 (build,
   work-completed) closed clean while two of three GO-promised
   deliverables silently dropped (auto-tick + TermLink-dispatch reviewer
   halves never wired). The §ACD substrate-vs-deliverable conflation
   that defined the orchestrator-rethink arc fires at task-pair level,
   not just arc level. Mitigation today is recovery-only (T-1709 wires
   one of the missing halves months later); prevention belongs in the
   gate per G-019 doctrine.

2. **The fix mirrors existing structural-gate patterns.** T-1668 added
   `--headline-mechanic` at `fw arc create`; T-1671 refused
   `fw arc close` under `$CLAUDECODE=1`; T-1259/T-1260 added agent
   refusal at `fw inception decide`. T-1713's gate at
   `update-task.sh --status work-completed` for build tasks whose
   `related_tasks` reference an inception-with-GO is the missing
   per-task counterpart of T-1671's per-arc gate. Symmetric.

3. **Cost is bounded; spike thresholds are falsifiable.** Three time-boxed
   spikes (parser, comparison, insertion-point) with hard pass/fail
   bars (≥80% parser agreement, ≤1 false positive across 5 cleanly-
   shipped tasks, no P-010/P-011 contract break). Each spike is
   approximately one session. NO-GO criteria honest — if parser cannot
   reach 80% on free-text Recommendation blocks, this inception itself
   becomes evidence that Recommendation-format structural enforcement
   (T-1715) must ship first.

**Evidence:**

- G-066 documented in `.context/project/concerns.yaml` with T-1442/
  T-1443 as origin pair.
- T-1709 (one prong of G-066 fix) currently captured awaiting GO —
  recovery-only path, does not prevent recurrence of the broader
  pattern.
- `lib/update-task.sh` already runs P-010 (AC checkbox check) + P-011
  (verification block) before `work-completed` transition. Insertion
  point exists with established gate-shape contract.
- Existing Tier-2 bypass pattern (`--scope-reduction-acknowledged`
  flag → `.context/working/.gate-bypass-log.yaml`) reuses
  `log_gate_bypass` machinery already used by `--skip-sovereignty` and
  similar. Zero new bypass plumbing.

**Risk acknowledged:**

- **False-positive harm > false-negative harm.** If gate trips on
  legitimate-as-designed scope reductions, operators will reflexively
  use `--force` and the gate becomes worse than nothing. Spike 2's
  ≤1-false-positive threshold is the load-bearing test.
- **Parser dependency on free-text Recommendation format.** If
  Recommendation blocks are unstructured prose, mechanical extraction
  fails. T-1715 (filing-time format gate) is the dependency — if T-1715
  ships first, T-1713's parser becomes trivial. Sequencing matters.
- **Coupling to inception/build pair convention.** Tasks that ship
  deliverables outside the inception→build pair shape (e.g. refactor +
  test pair) won't be covered. Scope fence accepts this; OUT-of-scope
  generalisation tracked separately if recurrence demands it.

**Sequencing note (added during T-1715 sweep):** T-1715 should ship
before T-1713 — Recommendation structure normalisation makes T-1713's
parser spike straightforward instead of NLP-heavy.

## Decision

**Decision**: GO

**Rationale**: Three convergent reasons:

1. **G-066 evidence is hard.** T-1442 (inception, GO) + T-1443 (build,
   work-completed) closed clean while two of three GO-promised
   deliverables silently dropped (auto-tick + TermLink-dispatch reviewer
   halves never wired). The §ACD substrate-vs-deliverable conflation
   that defined the orchestrator-rethink arc fires at task-pair level,
   not just arc level. Mitigation today is recovery-only (T-1709 wires
   one of the missing halves months later); prevention belongs in the
   gate per G-019 doctrine.

2. **The fix mirrors existing structural-gate patterns.** T-1668 added
   `--headline-mechanic` at `fw arc create`; T-1671 refused
   `fw arc close` under `$CLAUDECODE=1`; T-1259/T-1260 added agent
   refusal at `fw inception decide`. T-1713's gate at
   `update-task.sh --status work-completed` for build tasks whose
   `related_tasks` reference an inception-with-GO is the missing
   per-task counterpart of T-1671's per-arc gate. Symmetric.

3. **Cost is bounded; spike thresholds are falsifiable.** Three time-boxed
   spikes (parser, comparison, insertion-point) with hard pass/fail
   bars (≥80% parser agreement, ≤1 false positive across 5 cleanly-
   shipped tasks, no P-010/P-011 contract break). Each spike is
   approximately one session. NO-GO criteria honest — if parser cannot
   reach 80% on free-text Recommendation blocks, this inception itself
   becomes evidence that Recommendation-format structural enforcement
   (T-1715) must ship first.

**Date**: 2026-05-04T12:04:22Z

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d3f33edc
- **Timestamp:** 2026-06-02T14:59:16Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-04T12:04:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
