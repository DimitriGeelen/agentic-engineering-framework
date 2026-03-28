---
id: T-043
name: "Adopt session key hierarchy for multi-agent state isolation"
description: >
  Inception: Evaluate OpenClaw's hierarchical session key pattern for isolating
  state across agents, subagents, and TermLink workers in the framework.

status: captured
workflow_type: inception
owner: human
horizon: later
tags: [framework-improvement, extracted-pattern, multi-agent]
components: []
related_tasks: [T-036, T-012]
created: 2026-03-27T18:55:29Z
last_update: 2026-03-27T18:55:29Z
date_finished: null
---

# T-043: Adopt session key hierarchy for multi-agent state isolation

## Problem Statement

The framework identifies sessions by flat conversation IDs (from Claude Code's JSONL transcript).
Working memory, handovers, and context are session-scoped but not agent-type-scoped. When multiple
agents (coder, auditor, healer) or TermLink workers run, their state intermingles — a worker's
tool counter affects the parent's budget gate, and subagent depth is untracked.

OpenClaw's session key pattern (`agent:<id>:<channel>:<scope>`) encodes routing context
hierarchically. Applied to the framework: `agent:coder:termlink:T-031:worker-1` enables
per-agent-type state isolation, subagent depth tracking, and thread parent resolution.

**For:** Multi-agent orchestration (future capability)
**Why now:** Pattern extracted via T-036; foundation for TermLink improvements.

## Key Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| Extracted pattern | `docs/extracted/session-key-utils.ts` | Zero-dep standalone, 110 LOC |
| OpenClaw original | `src/sessions/session-key-utils.ts` | Full 133 LOC |
| OpenClaw tests | `src/sessions/session-key-utils.test.ts` | Parsing + classification tests |
| OpenClaw session-id | `src/sessions/session-id-resolution.ts` | UUID resolution |
| Framework focus | `.context/working/focus.yaml` | Current single-focus model |
| Framework dispatch | `.agentic-framework/agents/context/check-agent-dispatch.sh` | Agent dispatch limiter |

## Proposed Key Format

```
agent:<type>:<scope>:<task>:<worker>

Examples:
  agent:main:cli:T-036              — main session working on T-036
  agent:main:termlink:T-031:worker-1 — TermLink worker for T-031
  agent:audit:cron:daily             — scheduled audit run
  agent:main:subagent:explore:1      — first-level Explore subagent
```

## Assumptions

- A-001: Multi-agent state isolation is a real need (not just theoretical)
- A-002: The key format can be adopted incrementally (backward compatible)
- A-003: Subagent depth tracking prevents infinite recursion in TermLink dispatch

## Exploration Plan

1. **Spike 1 (30min):** Inventory all state that's currently session-scoped
2. **Spike 2 (1h):** Prototype key generation/parsing in bash
3. **Spike 3 (30min):** Evaluate incremental adoption path — what breaks if we change session IDs?

## Technical Constraints

- Keys must be filesystem-safe (used in paths)
- Must be backward-compatible with existing flat session IDs
- Colon delimiter must not conflict with existing path conventions

## Scope Fence

**IN:** Key format design, parsing utilities, incremental adoption plan
**OUT:** Implementing full multi-agent isolation, changing handover format, TermLink changes

## Acceptance Criteria

- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Multi-agent state collision is a documented problem (evidence from sessions)
- Key format is backward-compatible with current session handling
- Incremental adoption is possible (no big-bang migration)

**NO-GO if:**
- Current flat session model is sufficient for planned use cases
- Key hierarchy adds complexity without near-term value
- TermLink workers don't need isolation (they use separate tmux sessions)

## Verification

## Decisions

## Decision

## Updates
