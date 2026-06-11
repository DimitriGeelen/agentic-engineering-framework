---
id: T-1311
name: "Pickup: Codify RPC resilience-tier taxonomy + version skew enforcement (Tier-A
  opaque vs Tier-B typed) (from termlink)"
description: >
  Auto-created from pickup envelope. Source: termlink, task T-1071. Type: feature-proposal.

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: [pickup, feature-proposal]
components: []
related_tasks: []
created: 2026-04-18T20:22:51Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-18T22:47:41Z
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
---

# T-1311: Pickup: Codify RPC resilience-tier taxonomy + version skew enforcement (Tier-A opaque vs Tier-B typed) (from termlink)

## Problem Statement

Termlink T-1071 proposes the framework formally codify a two-tier RPC taxonomy (Tier-A "opaque pass-through" vs Tier-B "typed envelope") and add version-skew enforcement at MCP/TermLink boundaries. Today the framework has no documented RPC taxonomy and no skew checks at boundaries — but also no recurring incidents pointing to skew as the cause of failures.

## Assumptions

<!-- Key assumptions to test. Register with: fw assumption add "Statement" --task T-XXX -->

## Exploration Plan

<!-- How will we validate assumptions? Spikes, prototypes, research? Time-box each. -->

## Technical Constraints

<!-- What platform, browser, network, or hardware constraints apply?
     For web apps: HTTPS requirements, browser API restrictions, CORS, device support.
     For hardware APIs (mic, camera, GPS, Bluetooth): access requirements, permissions model.
     For infrastructure: network topology, firewall rules, latency bounds.
     Fill this BEFORE building. Discovering constraints after implementation wastes sessions. -->

## Scope Fence

<!-- What's IN scope for this exploration? What's explicitly OUT? -->

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested (no current incident; no consumer asking)
- [x] Recommendation written with rationale (DEFER pending concrete need)

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

## Recommendation

**Recommendation:** DEFER

**Rationale:** Real proposal but premature. Codifying an RPC taxonomy is high-cost (touches MCP, TermLink, fw bus, dispatch protocol) and the framework has no recurring skew incidents to anchor the design against. Premature taxonomies become wrong taxonomies. Ack the proposal, capture for revisit if a concrete skew incident occurs.

**Evidence:**
- No concrete incidents in episodic memory pointing to RPC version skew as a failure cause
- Existing dispatch protocols (Task vs TermLink, fw bus, dispatch.send) are documented in CLAUDE.md without needing tier nomenclature
- Codification cost (touching 3+ subsystems) outweighs current evidence
- Termlink can promote to GO if a concrete skew incident appears

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

Rationale: Real proposal but premature. Codifying an RPC taxonomy is high-cost (touches MCP, TermLink, fw bus, dispatch protocol) and the framework has no recurring skew incidents to anchor the design against. Premature taxonomies become wrong taxonomies. Ack the proposal, capture for revisit if a concrete skew incident occurs.

Evidence:
- No concrete incidents in episodic memory pointing to RPC version skew as a failure cause
- Existing dispatch protocols (Task vs TermLink, fw bus, dispatch.send) are documented in CLAUDE.md without needing tier nomenclature
- Codification cost (touching 3+ subsystems) outweighs current evidence
- Termlink can promote to GO if a concrete skew incident appears

**Date**: 2026-04-18T22:48:09Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-18T21:04:53Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-18T22:47:41Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: DEFER

Rationale: Real proposal but premature. Codifying an RPC taxonomy is high-cost (touches MCP, TermLink, fw bus, dispatch protocol) and the framework has no recurring skew incidents to anchor the design against. Premature taxonomies become wrong taxonomies. Ack the proposal, capture for revisit if a concrete skew incident occurs.

Evidence:
- No concrete incidents in episodic memory pointing to RPC version skew as a failure cause
- Existing dispatch protocols (Task vs TermLink, fw bus, dispatch.send) are documented in CLAUDE.md without needing tier nomenclature
- Codification cost (touching 3+ subsystems) outweighs current evidence
- Termlink can promote to GO if a concrete skew incident appears

### 2026-04-18T22:47:41Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-18T22:48:09Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: DEFER

Rationale: Real proposal but premature. Codifying an RPC taxonomy is high-cost (touches MCP, TermLink, fw bus, dispatch protocol) and the framework has no recurring skew incidents to anchor the design against. Premature taxonomies become wrong taxonomies. Ack the proposal, capture for revisit if a concrete skew incident occurs.

Evidence:
- No concrete incidents in episodic memory pointing to RPC version skew as a failure cause
- Existing dispatch protocols (Task vs TermLink, fw bus, dispatch.send) are documented in CLAUDE.md without needing tier nomenclature
- Codification cost (touching 3+ subsystems) outweighs current evidence
- Termlink can promote to GO if a concrete skew incident appears

## Reviewer Verdict (v1.5)

- **Scan ID:** R-0302d493
- **Timestamp:** 2026-06-02T14:56:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
