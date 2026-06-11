---
id: T-568
name: "OpenClaw deep-dive: architecture patterns — RPC registry, queue-based chat,
  plugin hooks, ACLs, ACP"
description: >
  Dispatch to OpenClaw eval agent: Investigate 5 architecture patterns not yet explored.
  (1) RPC method registry — 50+ methods, auth model, extensibility via hooks. (2)
  Queue-based chat — one LLM run per session, race condition prevention. (3) Plugin
  hook system — before/after hooks on methods. (4) Access control lists — compiled
  to O(1) sets, source types. (5) ACP (Agent Communication Protocol) — external agent
  runtime at acp/control-plane/manager.core.ts (1732 LOC). For each: relevance to
  our framework, adoption feasibility. Write findings. Review with human.

status: work-completed
workflow_type: inception
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-23T17:18:05Z
last_update: '2026-06-11T22:24:24Z'
date_finished: 2026-04-04T12:35:17Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:24Z'
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

# T-568: OpenClaw deep-dive: architecture patterns — RPC registry, queue-based chat, plugin hooks, ACLs, ACP

## Problem Statement

Superseded by parent evaluation T-549/T-678. Architecture patterns analyzed in `docs/upstream-patterns/openclaw/EVALUATION-SUMMARY.md` — RPC registry, ACLs, plugin system, config hot-reload all covered. Research artifact: see `docs/reports/T-549-openclaw-design-patterns.md`.

## Recommendation

- **Recommendation:** NO-GO (superseded)
- **Rationale:** Parent evaluation analyzed 154 components across 28 subsystems. RPC registry (Gateway subsystem, 22 cards), ACLs (`dm-access-policy.ts` extracted), plugin hooks (Plugin SDK pattern documented), queue-based chat (Agents subsystem). ACP not relevant to our framework.

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

- [x] Problem statement validated (superseded by parent T-549)
- [x] Assumptions tested (covered in evaluation summary)
- [x] Go/No-Go decision made (NO-GO — superseded)

## Go/No-Go Criteria

**GO if:**
- [Criterion 1]
- [Criterion 2]

**NO-GO if:**
- [Criterion 1]
- [Criterion 2]

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: NO-GO

**Rationale**: - Recommendation: NO-GO (superseded)
- Rationale: Parent evaluation analyzed 154 components across 28 subsystems. RPC registry (Gateway subsystem, 22 cards), ACLs (`dm-access-policy.ts` extracted),...

**Date**: 2026-03-29T20:27:45Z
## Decision

**Decision**: NO-GO

**Rationale**: - Recommendation: NO-GO (superseded)
- Rationale: Parent evaluation analyzed 154 components across 28 subsystems. RPC registry (Gateway subsystem, 22 cards), ACLs (`dm-access-policy.ts` extracted),...

**Date**: 2026-03-29T20:27:45Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-29T20:27:45Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** - Recommendation: NO-GO (superseded)
- Rationale: Parent evaluation analyzed 154 components across 28 subsystems. RPC registry (Gateway subsystem, 22 cards), ACLs (`dm-access-policy.ts` extracted),...

### 2026-04-04T12:35:16Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-04T12:35:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-580a3f55
- **Timestamp:** 2026-06-02T15:03:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
