---
id: T-097
name: Deep reflection: Type A multi-agent optimization and specialized sub-agents
description: >
  Deep reflection: Type A multi-agent optimization and specialized sub-agents

status: started-work
workflow_type: inception
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T07:40:40Z
last_update: 2026-02-17T07:40:40Z
date_finished: null
---

# T-097: Deep reflection: Type A multi-agent optimization and specialized sub-agents

## Problem Statement

The framework uses Type A multi-agent (orchestrator + ephemeral specialists) extensively
and it works well. But it's ad-hoc — the orchestrator manually formulates prompts, picks
agent types (Explore, Plan, Code), and integrates results. Questions to explore:

1. How can we optimize the orchestrator → sub-agent → result integration loop?
2. Should we build specialized sub-agents (framework-aware, not just generic Explore/Code)?
3. What would specialized agents look like? (e.g., "enrichment agent", "audit agent", "research agent")
4. What's the token/context cost model and how do we manage it?
5. What patterns from our 96-task history should inform the design?

## Key Questions From User

- Do we need / benefit from specialized sub-agents for sub-agent tasks?
- What would those specialists know that generic agents don't?
- How do we avoid over-engineering (building agents nobody calls)?

## Evidence To Gather

1. Catalog all sub-agent dispatches across 96 tasks — what was asked, what was returned, what worked/failed
2. Identify repeated dispatch patterns (same kind of question asked multiple times)
3. Analyze token cost of sub-agent result ingestion (from T-073, T-078 learnings)
4. Survey Claude Code's built-in agent types and their limitations
5. Look at framework-specific knowledge that would benefit from specialization

## Scope Fence

**IN scope:**
- Type A optimization (orchestrator + ephemeral specialists)
- Specialized sub-agent design (if warranted by evidence)
- Token management for sub-agent results
- Sub-agent observability and logging

**OUT of scope:**
- Type B (autonomous parallel peers) — explicitly deferred
- Building agents for other providers (Cursor, GPT) — portability later
- Changing the authority model

## Go/No-Go Criteria

**GO (build specialized sub-agents) if:**
- 3+ repeated dispatch patterns found that would benefit from specialization
- Specialization would save >20% tokens on common operations
- Framework-specific context (task system, context fabric, enforcement) is needed in sub-agent

**NO-GO if:**
- Generic agents (Explore, Plan, Code) cover all patterns adequately
- Specialization adds complexity without measurable benefit
- Framework context can be passed via prompt without specialization

## Decision

<!-- Filled at completion via: fw inception decide T-097 go|no-go --rationale "..." -->

## Updates

### 2026-02-17T07:40:40Z — task-created [task-create-agent]
- **Action:** Created inception task
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-097-deep-reflection-type-a-multi-agent-optim.md
- **Context:** Initial task creation

[Chronological log — every action, every output, every decision]
