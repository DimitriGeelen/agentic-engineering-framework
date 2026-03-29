---
id: T-044
name: "Evaluate DM access policy pattern for framework API access controls"
description: >
  Inception: Evaluate whether OpenClaw's multi-source ACL merge + policy evaluation
  pattern is applicable to framework access controls (Tier 0/1/2 enforcement,
  agent authority model).

status: captured
workflow_type: inception
owner: human
horizon: later
tags: [framework-improvement, extracted-pattern, access-control]
components: []
related_tasks: [T-036]
created: 2026-03-27T18:55:29Z
last_update: 2026-03-27T18:55:29Z
date_finished: null
---

# T-044: Evaluate DM access policy pattern for framework API access controls

## Problem Statement

The framework's authority model (Human=SOVEREIGNTY, Framework=AUTHORITY, Agent=INITIATIVE)
is enforced structurally via Tier 0/1/2/3 gates. Currently, access decisions are hardcoded
in bash scripts (check-tier0.sh, check-active-task.sh). There's no generalized access
policy engine that can merge rules from multiple sources (CLAUDE.md, project config,
runtime overrides).

OpenClaw's DM access policy pattern demonstrates multi-source ACL merge (config allowlist +
runtime pairing store + group overrides) with policy modes (open, disabled, allowlist, pairing).
The pattern generalizes to any system where access rules come from multiple sources.

**For:** Framework governance extensibility
**Why now:** Pattern extracted via T-036; lowest priority — evaluate for future applicability.

## Key Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| Extracted pattern | `docs/extracted/dm-access-policy.ts` | Zero-dep standalone, 160 LOC |
| OpenClaw original | `src/security/dm-policy-shared.ts` | Full 333 LOC |
| OpenClaw tests | `src/security/dm-policy-shared.test.ts` | Policy evaluation tests |
| Framework Tier 0 | `.agentic-framework/agents/context/check-tier0.sh` | Destructive action gate |
| Framework Tier 1 | `.agentic-framework/agents/context/check-active-task.sh` | Task-first gate |
| Authority model | `CLAUDE.md` (Authority Model section) | Human > Framework > Agent |

## Potential Application

The multi-source merge pattern could unify:
- Tier enforcement (currently separate bash scripts)
- Agent capability restrictions (per-agent-type tool allowlists)
- Project-specific overrides (`.framework.yaml` config)
- Runtime approvals (`fw tier0 approve` — time-limited, logged)

Into a single policy evaluation: `evaluateAccess({ agent, tool, context, rules })`.

## Assumptions

- A-001: The current bash-script enforcement model has scaling limitations
- A-002: Multi-source policy merge adds value beyond what hardcoded checks provide
- A-003: The complexity of a policy engine is justified for the framework's current scale

## Exploration Plan

1. **Spike 1 (30min):** Inventory all current access checks — how many, where, what logic?
2. **Spike 2 (30min):** Map OpenClaw's policy modes to framework tiers
3. **Spike 3 (30min):** Evaluate: is this solving a real problem or adding abstraction?

## Technical Constraints

- Current enforcement is bash (PreToolUse hooks)
- Policy engine would need to be callable from bash
- Must not slow down the hot path (<100ms per tool call)

## Scope Fence

**IN:** Evaluation of applicability, mapping to framework concepts
**OUT:** Building a policy engine, changing enforcement architecture

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Current access checks have >3 duplicated decision patterns
- Multi-source merge solves a real config management problem
- Pattern can be adopted incrementally

**NO-GO if:**
- Framework's scale doesn't justify a policy engine
- Bash scripts are adequate and maintainable
- The abstraction adds complexity without reducing code

## Verification

## Decisions

## Decision

## Updates
