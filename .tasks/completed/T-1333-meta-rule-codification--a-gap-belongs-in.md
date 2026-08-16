---
id: T-1333
name: "Meta-rule codification — a gap belongs in the register where the fix lives,
  not where it was hit"
description: >
  Inception: Meta-rule codification — a gap belongs in the register where the fix
  lives, not where it was hit

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-19T13:03:02Z
last_update: '2026-08-16T22:24:29Z'
date_finished: 2026-04-24T09:23:59Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:29Z'
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

# T-1333: Meta-rule codification — a gap belongs in the register where the fix lives, not where it was hit

## Problem Statement

050-email-archive proposed a governance meta-rule (2026-04-19): **"A gap belongs in the register where the FIX lives, not where it was HIT."** Their case: G-014 "agent-daemon-not-injectable" is filed in ring20-management's concerns.yaml, but the fix is a termlink-schema change (session caps + RPC method absence on data_plane+stream sessions). Any consumer that hits it will not discover the entry because they search their own register, not ring20-management's.

Question: **should this rule be codified in CLAUDE.md (and possibly enforced via a concerns.yaml cross-reference field), or is it a one-off situational judgement that doesn't generalize?**

## Assumptions

1. The homing ambiguity (fix-locus vs hit-locus) recurs across projects — UNTESTED (need to audit concerns.yaml entries across the fleet)
2. Codifying in CLAUDE.md would be followed — LIKELY TRUE (agents consult CLAUDE.md before filing new gaps)
3. Structural enforcement (e.g., required `fix-locus` field in concerns.yaml schema) would be tractable — UNTESTED

## Exploration Plan

- **A** (10m): Scan all concerns.yaml across known consumer projects — flag entries where hit-locus ≠ fix-locus (or ambiguous)
- **B** (5m): Draft the CLAUDE.md section (rule + one concrete example + when-to-apply)
- **C** (5m): Decide codification tier — CLAUDE.md prose (Tier 1) vs schema field (Tier 2) vs audit check (Tier 3)

## Technical Constraints

- CLAUDE.md changes propagate via framework upgrade to consumers (baseline CLAUDE.md lives in framework repo)
- A schema field change on concerns.yaml would require audit + migration for existing entries
- Not every gap has an obvious single "fix locus" — some have cross-cutting fixes

## Scope Fence

**IN:** decide whether to codify the meta-rule, and at what enforcement tier.
**OUT:** actually reviewing and re-homing existing concerns (that's follow-up work per-project, not framework-level).

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
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

## Research Artifact

See `docs/reports/T-1333-gap-homing-codification.md` for the persisted thinking trail and link to the codification destination (CLAUDE.md § Gap Homing). Per T-1441.

## Recommendation

**Recommendation:** GO — codify as Tier-1 CLAUDE.md prose, not schema enforcement

**Rationale:** Spike A (light version, executed inline this session) scanned the framework's own `concerns.yaml` (64 entries) for cross-project / upstream-fix signals. Result: 5 entries (G-031, G-045, G-048, G-049, G-050) textually signal "fix locus elsewhere". That's ~8% of the register — low enough that a required-field schema change (Assumption 3 / Tier 2) would be over-engineering for current volume, but high enough that a codified rule (Tier 1 CLAUDE.md prose + worked example) has genuine and recurring application. 050 e-agent's proposed rule ("a gap belongs in the register where the FIX lives") is sound as a directional heuristic. Recommend GO at the lightest tier: add a 2–3 sentence rule to CLAUDE.md §Error Escalation Ladder (or a new §Gap Homing subsection) referencing G-048/G-049/G-050 as canonical example; skip schema + audit (Tier 2/3) until evidence shows the prose is ignored. Scope-fence in this task is IN=codify-the-rule, OUT=re-home existing entries — honour that boundary.

**Evidence:**
- Concerns register audit (this session): 5/64 entries (~8%) show hit-locus-elsewhere signals — recurring, not rare.
- Examples with fix-locus elsewhere: G-031, G-045 (fleet cert co-rotation — fix is TermLink T-1054), G-048, G-049, G-050 (050 e-agent's flagged cross-project cases).
- Assumption 2 (agents consult CLAUDE.md before filing) is evidenced by §Autonomous Mode Boundaries and §Human Task Completion Rule codifications being observed in session behaviour.
- Assumption 3 (schema field would be tractable) is un-tested and NOT required by this recommendation — Tier-1 prose ships today; schema migration stays a future escalation if prose is ignored.
- Aligns with G-019 (agent self-escalation) philosophy: codify the minimum that changes behaviour, escalate to structure only if prose fails.

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

**Rationale**: Recommendation: GO — codify as Tier-1 CLAUDE.md prose, not schema enforcement

Rationale: Spike A (light version, executed inline this session) scanned the framework's own `concerns.yaml` (64 entries) for cross-project / upstream-fix signals. Result: 5 entries (G-031, G-045, G-048, G-049, G-050) textually signal "fix locus elsewhere". That's ~8% of the register — low enough that a required-field schema change (Assumption 3 / Tier 2) would be over-engineering for current volume, but high enough that a codified rule (Tier 1 CLAUDE.md prose + worked example) has genuine and recurring application. 050 e-agent's proposed rule ("a gap belongs in the register where the FIX lives") is sound as a directional heuristic. Recommend GO at the lightest tier: add a 2–3 sentence rule to CLAUDE.md §Error Escalation Ladder (or a new §Gap Homing subsection) referencing G-048/G-049/G-050 as canonical example; skip schema + audit (Tier 2/3) until evidence shows the prose is ignored. Scope-fence in this task is IN=codify-the-rule, OUT=re-home existing entries — honour that boundary.

Evidence:
- Concerns register audit (this session): 5/64 entries (~8%) show hit-locus-elsewhere signals — recurring, not rare.
- Examples with fix-locus elsewhere: G-031, G-045 (fleet cert co-rotation — fix is TermLink T-1054), G-048, G-049, G-050 (050 e-agent's flagged cross-project cases).
- Assumption 2 (agents consult CLAUDE.md before filing) is evidenced by §Autonomous Mode Boundaries and §Human Task Completion Rule codifications being observed in session behaviour.
- Assumption 3 (schema field would be tractable) is un-tested and NOT required by this recommendation — Tier-1 prose ships today; schema migration stays a future escalation if prose is ignored.
- Aligns with G-019 (agent self-escalation) philosophy: codify the minimum that changes behaviour, escalate to structure only if prose fails.

**Date**: 2026-04-24T09:23:59Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-24T09:23:59Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO — codify as Tier-1 CLAUDE.md prose, not schema enforcement

Rationale: Spike A (light version, executed inline this session) scanned the framework's own `concerns.yaml` (64 entries) for cross-project / upstream-fix signals. Result: 5 entries (G-031, G-045, G-048, G-049, G-050) textually signal "fix locus elsewhere". That's ~8% of the register — low enough that a required-field schema change (Assumption 3 / Tier 2) would be over-engineering for current volume, but high enough that a codified rule (Tier 1 CLAUDE.md prose + worked example) has genuine and recurring application. 050 e-agent's proposed rule ("a gap belongs in the register where the FIX lives") is sound as a directional heuristic. Recommend GO at the lightest tier: add a 2–3 sentence rule to CLAUDE.md §Error Escalation Ladder (or a new §Gap Homing subsection) referencing G-048/G-049/G-050 as canonical example; skip schema + audit (Tier 2/3) until evidence shows the prose is ignored. Scope-fence in this task is IN=codify-the-rule, OUT=re-home existing entries — honour that boundary.

Evidence:
- Concerns register audit (this session): 5/64 entries (~8%) show hit-locus-elsewhere signals — recurring, not rare.
- Examples with fix-locus elsewhere: G-031, G-045 (fleet cert co-rotation — fix is TermLink T-1054), G-048, G-049, G-050 (050 e-agent's flagged cross-project cases).
- Assumption 2 (agents consult CLAUDE.md before filing) is evidenced by §Autonomous Mode Boundaries and §Human Task Completion Rule codifications being observed in session behaviour.
- Assumption 3 (schema field would be tractable) is un-tested and NOT required by this recommendation — Tier-1 prose ships today; schema migration stays a future escalation if prose is ignored.
- Aligns with G-019 (agent self-escalation) philosophy: codify the minimum that changes behaviour, escalate to structure only if prose fails.

### 2026-04-24T09:23:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Reason:** Inception decision in progress

### 2026-04-24T09:23:59Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bf430a7b
- **Timestamp:** 2026-06-02T14:56:46Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
