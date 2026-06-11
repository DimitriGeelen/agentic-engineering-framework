---
id: T-705
name: "KCP integration — knowledge.yaml generation from fabric/context + MCP bridge
  adoption"
description: >
  Evaluate adopting KCP (Knowledge Context Protocol) from Cantara. Generate knowledge.yaml
  from existing fabric cards + context data. Add kcp-mcp bridge to default MCP config.
  Stay on KCP upgrade path — become adopter, contribute upstream. Thor Henning Hetland
  actively developing. Source: T-697 deep-dive, T-487 spec research.

status: captured
workflow_type: inception
owner: human
horizon: next
tags: [kcp, integration, mcp]
components: []
related_tasks: []
created: 2026-03-29T08:58:11Z
last_update: '2026-06-11T16:00:04Z'
date_finished:
bvp_scores_proposed:
  - ts: '2026-05-19T18:27:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T20:15:02Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F1: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-28T22:54:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-05-29T23:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F1: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F1=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-01T08:15:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-02T08:30:03Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=0 (no-signal); D4=4
      (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-11T16:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F1=2 
      (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
cost_estimate_proposed:
  - ts: '2026-05-19T21:45:02Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 0
      tier: 4
      effort: 6
    rationale: blast_radius=0 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-06-05T18:00:04Z'
    estimator: bvp-estimator-v1-heuristic
    cost_estimate:
      blast_radius: 3
      tier: 4
      effort: 6
    rationale: blast_radius=3 (no-signal); tier=4 (no-signal); effort=6 
      (no-signal)
    rubric_sha: e4a00f38e801
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
---

# T-705: KCP integration — knowledge.yaml generation from fabric/context + MCP bridge adoption

## Problem Statement

Framework has rich structured data (fabric cards, context YAML, tasks, learnings, decisions) but no standard format for external AI agents to discover and navigate this knowledge. KCP provides `knowledge.yaml` — a navigable manifest for AI agents. Question: should we adopt KCP now?

**For whom:** External agents, multi-agent scenarios, cross-project discovery.
**Why now:** T-697 deep-dive validated KCP codebase, T-487 evaluated spec. KCP author (Thor Henning Hetland) actively developing.

## Assumptions

A-1: External agents need a different context delivery mechanism than CLAUDE.md — PARTIALLY TRUE: CLAUDE.md is Claude Code-specific, but no external agent scenario exists yet
A-2: KCP spec is stable enough to adopt — FALSE: v0.14 with 17 active RFCs, rapid iteration
A-3: kcp-mcp bridge is production-ready — UNTESTED: npm dependency, no production adopters
A-4: Generator maintenance is bounded — FALSE: same sync-burden as T-702 (every fabric/context change needs generator update)

## Scope Fence

**IN:** Evaluate whether to adopt KCP now, generate knowledge.yaml, add MCP bridge
**OUT:** Building the generator, modifying fabric cards, contributing upstream

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-705 defer --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- KCP spec is stable (v1.0+) AND current need for external agent context delivery exists
- kcp-mcp bridge works without npm core dependency

**NO-GO/DEFER if:**
- KCP is pre-1.0 with active RFCs (spec instability risk)
- No current external agent scenario needs this
- Existing mechanisms (CLAUDE.md, fabric, handovers) serve the primary agent well

## Verification

# Research artifact exists
test -f docs/reports/T-705-kcp-integration.md
# Contains recommendation
grep -q "Recommendation" docs/reports/T-705-kcp-integration.md

## Decisions

**Decision**: DEFER

**Rationale**: - Recommendation: DEFER
- Rationale: KCP is a good standard but too early to adopt. The framework already provides rich context to its primary agent via CLAUDE.md, handovers, and fabric cards. Know...

**Date**: 2026-03-29T13:32:37Z

## Recommendation

- **Recommendation:** DEFER
- **Rationale:** KCP is a good standard but too early to adopt. The framework already provides rich context to its primary agent via CLAUDE.md, handovers, and fabric cards. Knowledge.yaml would duplicate this in a different format for consumers that don't yet exist (external agents, multi-agent scenarios). KCP is v0.14 with 17 active RFCs — adopting now risks rebuilding when the spec stabilizes. The kcp-mcp bridge adds an npm dependency to a zero-npm-dependency framework.
- **Evidence:**
  - Research artifact: `docs/reports/T-705-kcp-integration.md`
  - T-487: spec evaluation (v0.10 at the time, now v0.14)
  - T-697: codebase deep-dive confirmed MCP bridge pattern and conformance testing
  - G-004 (multi-agent coordination untested) — the scenario where KCP adds value doesn't exist yet
  - Revisit triggers: KCP v1.0, multi-agent implementation, second AI agent needs context
- **Next steps after DEFER:**
  - Watch KCP development for v1.0 milestone
  - Reference KCP in launch content as "standard we're watching"
  - Revisit when G-004 is addressed or a second AI agent needs framework context

## Decision

**Decision**: DEFER

**Rationale**: - Recommendation: DEFER
- Rationale: KCP is a good standard but too early to adopt. The framework already provides rich context to its primary agent via CLAUDE.md, handovers, and fabric cards. Know...

**Date**: 2026-03-29T13:32:37Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-03-29T13:05:12Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-29T13:32:37Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** DEFER
- **Rationale:** - Recommendation: DEFER
- Rationale: KCP is a good standard but too early to adopt. The framework already provides rich context to its primary agent via CLAUDE.md, handovers, and fabric cards. Know...

### 2026-04-06T22:23:16Z — status-update [task-update-agent]
- **Change:** horizon: next → later

### 2026-04-23T16:46:50Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-04-28T16:09:26Z — status-update [task-update-agent]
- **Change:** horizon: next → next
