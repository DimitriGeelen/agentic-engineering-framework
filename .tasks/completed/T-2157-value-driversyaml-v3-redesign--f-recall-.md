---
id: T-2157
name: "value-drivers.yaml v3 redesign — F-RECALL + F-ORCH active, F-AUTONOMY carved,
  schema_version→version, per-driver rubric+guardrails+retire_when"
description: >
  Inception: value-drivers.yaml v3 redesign — F-RECALL + F-ORCH active, F-AUTONOMY
  carved, schema_version→version, per-driver rubric+guardrails+retire_when

status: work-completed
workflow_type: inception
owner: human
horizon: now
tags: [priority, arc-006, bvp, value-drivers]
components: []
related_tasks: []
created: 2026-06-01T09:20:09Z
last_update: 2026-06-01T09:51:23Z
date_finished: 2026-06-01T09:51:23Z
# revisit_at: YYYY-MM-DD          # T-1451: set on DEFER decisions to enable G-053 daily revisit scan
# revisit_evidence_needed:        # T-1451: one-line description of what evidence makes the revisit actionable
bvp_scores_proposed:
  - ts: '2026-06-01T09:20:59Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 2
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-06-01T09:30:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 7
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=7 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-2157: value-drivers.yaml v3 redesign — F-RECALL + F-ORCH active, F-AUTONOMY carved, schema_version→version, per-driver rubric+guardrails+retire_when

## Problem Statement

Human-filed wholesale rewrite proposal for `policy/value-drivers.yaml`. Current state: 78-line v1 with `schema_version: 1`, D1-D4 protected (weights 9/7/5/3), `free_drivers: []` (empty), auto_promote OFF. Proposal: v3 with two **active** free drivers (F-RECALL/Recall Leverage weight 6, F-ORCH/Orchestration Leverage weight 5), F-AUTONOMY as commented-out candidate carve, new per-driver fields (`rubric`, `guardrails`, `retire_when`, `polarity`), schema field rename `schema_version` → `version` (bump 1→3), and rewritten prose on D1-D4 `note:` strings.

The inception's job is **not** to rubber-stamp the proposal. It is to:
1. Walk the consumer-code blast radius (`lib/bvp.sh`, `web/blueprints/bvp.py`, `lib/arc.sh`, T-1921 rubric MD) the schema rename and new fields trigger
2. Critically restate F-RECALL vs D1+D2 + F-ORCH vs D3 against CLAUDE.md's **"new meaning, not louder D1-D4"** criterion
3. Evaluate the new field model (rubric/guardrails/retire_when source-of-truth interactions)
4. Hand the human GO / NO-GO / GO-with-refinements with each option's cost + risk

**Research artifact:** `docs/reports/T-2157-value-drivers-v3-redesign.md` — proposed YAML verbatim + structural diff + provisional semantic critique + 10 open questions. **Recommendation: DEFER pending evidence walk** (CLAUDE.md §Inception Discipline — research artifact first, build artifacts only after GO).

## Assumptions

- **A1:** All five consumers in the v1 docstring (`lib/bvp.sh`, `lib/bvp.sh auto-promote`, `lib/arc.sh approve-driver`, `web/blueprints/bvp.py`, `web/blueprints/arcs.py`) currently key on `schema_version`, not `version`. To validate via grep.
- **A2:** F-RECALL's rubric bands 0-2 ("capture-only, session-scoped") double-count with D2 (Reliability-through-not-forgetting). To validate by restating against D2's existing definition.
- **A3:** F-ORCH's guardrail ("score capability uplift, not ease-of-delegating-this-task") is critical and must be enforceable at estimator-time (T-1922) — otherwise the driver collapses to "we punted to TermLink, +5".
- **A4:** The proposal's `rubric:` per driver is **human-facing documentation only**, not consumed by the BVP compute code. To validate by checking T-1921's `policy/bvp-scoring-rubric.md` source-of-truth role.
- **A5:** `retire_when:` is free-text reminder (NOT auto-enforced) — proposal explicitly says so. Future enforcement (fw doctor advisory check) is out of scope for this inception.

## Exploration Plan

| Spike | Time-box | Output |
|-------|----------|--------|
| S1: Consumer-code walk | 30 min | Update artifact §"Consumer-code blast radius walk" with concrete findings per A1 |
| S2: Semantic critique formalisation | 20 min | Update artifact §"Semantic critique" — confirm/refute A2 + A3, propose F-RECALL band-floor refinement if A2 holds |
| S3: Estimator impact (T-1922) | 15 min | Sub-scope question — does new-driver addition require estimator re-rule? Is that in-scope for the build slice or a separate task? |
| S4: T-1915 prior-art read | 15 min | Confirm what was considered+rejected at first BVP inception; reuse vocabulary where possible |
| S5: Answer open questions 1-10 | 30 min | Each Q resolved with evidence cited |

All spikes are read-only research — no build artifact created until GO recorded.

## Technical Constraints

- **Schema migration risk:** `schema_version: 1` → `version: 3` is silent-fall-through for any reader that uses `.get('schema_version', 1)`. L-329 (don't human-gate propagation of authorised decisions) argues for backward-compat dual-key transition; this is open Q2 in the artifact.
- **Cross-file source-of-truth:** `policy/bvp-scoring-rubric.md` (T-1921) currently holds the rubric. Inline-rubric in v3 YAML creates two sources; need to decide which is canonical (open Q3).
- **Estimator coupling:** T-1922 BVP estimator scores tasks against D1-D4. Adding F-RECALL/F-ORCH requires new heuristics (or accepts zero scores until estimator catches up). Affects every task scored post-merge.
- **Existing scored tasks:** Tasks with `bvp_scores:` set before v3 have no F-RECALL/F-ORCH entries. Compute treats missing-key as 0 (verifiable via lib/bvp.sh).

## Scope Fence

**IN scope (this inception):**
- Read-only walk of all 5 named consumers
- Semantic critique of each new driver vs CLAUDE.md §Free Driver criterion
- Evaluation of new per-driver fields (rubric/guardrails/retire_when/polarity)
- Recommendation flip from DEFER → GO / NO-GO / GO-with-refinements
- Hand-off to human via `fw task review T-2157`

**OUT of scope (separate tasks if GO):**
- Implementing the rewrite (separate build slice; will be tagged `unlocks_inception_decision: T-2157:...`)
- Estimator re-rule / re-train for F-RECALL + F-ORCH (separate task)
- Watchtower /bvp display update for new free-driver axes (separate task)
- `retire_when:` audit-time staleness detector (separate inception)
- Migrating existing `bvp_scores:` on scored tasks (separate slice; may be no-op if missing-key handled as 0)
- F-AUTONOMY activation (stays carved; separate inception when broad gate-reduction becomes focus)

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

**GO if:**
- All 5 named consumers (lib/bvp.sh, lib/arc.sh, web/blueprints/bvp.py + arcs.py, T-1921 rubric MD) can be migrated in a bounded slice (≤1-2 build tasks)
- F-RECALL semantic carve survives the D2 double-count critique (or is refined — e.g. floor at band ≥3)
- F-ORCH guardrail is enforceable at estimator-time OR is acceptable as human-only-scored
- Schema rename strategy chosen (dual-key transition vs. hard cut)
- Estimator re-rule (T-1922) scoped as separate-but-tracked follow-up

**NO-GO if:**
- Consumer-code walk reveals a hidden coupling that turns the slice into a refactor cascade
- F-RECALL fundamentally duplicates D2 with no clear band-floor refinement
- The combined effect of two active free drivers destabilises existing BVP rankings (would need a re-score sweep on all scored tasks)

**GO-with-refinements if:**
- Proposal is structurally sound but specific bands / weights need tightening before implement
- Schema rename should be staged (dual-key in v2, hard-cut in v3) rather than jump 1→3

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

**Recommendation:** DEFER

**Rationale:**

Human-proposed wholesale rewrite filed as priority inception for review→refine→implement. Genuine evidence gap (T-2144 distinction): the proposal lands an opinionated structure but the agent has not yet walked the consumer-code blast radius (lib/bvp.sh, web/blueprints/bvp.py, lib/arc.sh — all read schema_version: 1; the rename to version: 3 needs verification across each call site), nor critically re-stated the F-RECALL vs D1 + F-ORCH vs D3 distinctions against CLAUDE.md's 'free driver only justified when current focus is an axis D1-D4 do not *mean*' criterion. Research artifact docs/reports/T-XXXX-value-drivers-v3-redesign.md will host: (a) the proposed YAML verbatim, (b) consumer-code call-site walk + concrete migration concerns, (c) semantic critique of each new field (rubric/guardrails/retire_when) + each new driver, (d) implementation plan if GO. DEFER expires when the artifact is complete and the human picks GO/NO-GO via Watchtower.

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

**Rationale**: Recommendation: DEFER

Rationale:

Human-proposed wholesale rewrite filed as priority inception for review→refine→implement. Genuine evidence gap (T-2144 distinction): the proposal lands an opinionated structure but the agent has not yet walked the consumer-code blast radius (lib/bvp.sh, web/blueprints/bvp.py, lib/arc.sh — all read schema_version: 1; the rename to version: 3 needs verification across each call site), nor critically re-stated the F-RECALL vs D1 + F-ORCH vs D3 distinctions against CLAUDE.md's 'free driver only justified when current focus is an axis D1-D4 do not mean' criterion. Research artifact docs/reports/T-XXXX-value-drivers-v3-redesign.md will host: (a) the proposed YAML verbatim, (b) consumer-code call-site walk + concrete migration concerns, (c) semantic critique of each new field (rubric/guardrails/retire_when) + each new driver, (d) implementation plan if GO. DEFER expires when the artifact is complete and the human picks GO/NO-GO via Watchtower.

Evidence:

**Date**: 2026-06-01T09:51:22Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-06-01T09:20:38Z — status-update [task-update-agent]
- **Change:** horizon: now → now
- **Change:** tags: +priority

### 2026-06-01T09:20:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-06-01T09:21:09Z — status-update [task-update-agent]
- **Change:** tags: +arc-006

### 2026-06-01T09:21:09Z — status-update [task-update-agent]
- **Change:** tags: +bvp

### 2026-06-01T09:21:09Z — status-update [task-update-agent]
- **Change:** tags: +value-drivers

## Reviewer Verdict (v1.5)

- **Scan ID:** R-88d741d0
- **Timestamp:** 2026-06-01T09:51:23Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-06-01T09:51:22Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: DEFER

Rationale:

Human-proposed wholesale rewrite filed as priority inception for review→refine→implement. Genuine evidence gap (T-2144 distinction): the proposal lands an opinionated structure but the agent has not yet walked the consumer-code blast radius (lib/bvp.sh, web/blueprints/bvp.py, lib/arc.sh — all read schema_version: 1; the rename to version: 3 needs verification across each call site), nor critically re-stated the F-RECALL vs D1 + F-ORCH vs D3 distinctions against CLAUDE.md's 'free driver only justified when current focus is an axis D1-D4 do not mean' criterion. Research artifact docs/reports/T-XXXX-value-drivers-v3-redesign.md will host: (a) the proposed YAML verbatim, (b) consumer-code call-site walk + concrete migration concerns, (c) semantic critique of each new field (rubric/guardrails/retire_when) + each new driver, (d) implementation plan if GO. DEFER expires when the artifact is complete and the human picks GO/NO-GO via Watchtower.

Evidence:

### 2026-06-01T09:51:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
