---
id: T-097
name: "Deep reflection: Type A multi-agent optimization and specialized sub-agents"
description: >
  Deep reflection: Type A multi-agent optimization and specialized sub-agents

status: work-completed
workflow_type: inception
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T07:40:40Z
last_update: 2026-02-17T07:50:48Z
date_finished: 2026-02-17T07:50:48Z
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

## Evidence Gathered

### Sub-Agent Dispatch Catalog (8 of 96 tasks = 8.3%)

| Task | # Agents | Type | Purpose | Outcome |
|------|----------|------|---------|---------|
| T-014 | 1 Plan | Review | Critical review of audit | Found 8 findings |
| T-058 | Sequential | TDD | Fresh agent per impl task | Caught missing git_log |
| T-059 | 3 parallel | Investigation | Root cause analysis | Success |
| T-061 | 4 parallel | Investigation | Bypass vector scanning | Comprehensive |
| T-072 | 3 parallel | Audit | Full project audit | Thorough (3 domains) |
| T-073 | 9 parallel | Enrichment | Enrich episodic skeletons | **Context explosion (177K)** |
| T-086 | 5 parallel | Evaluation | Feature evaluation | Informed decision |
| T-054 | (problem) | Concurrent edits | 4 agents on same file | Caused blueprint refactor |

### Repeated Patterns (4 identified)

**P1 — Parallel Investigation** (T-059, T-061, T-086): 3-5 Explore agents scan different
aspects. Results synthesized by orchestrator. Works well as-is with generic agents.

**P2 — Parallel Audit** (T-072, T-014): Review artifacts for quality/compliance across
different slices. Benefits from knowing task/episodic format.

**P3 — Parallel Content Generation** (T-073): Produce files from templates. CAUSED THE
ONLY FAILURE — 9 agents returned full results, spiking 30K+ tokens.

**P4 — Sequential TDD Development** (T-058): Fresh agent per task with review between.
Already formalized in `superpowers:subagent-driven-development` skill.

### Token Cost Analysis

| Pattern | Agents | Tokens Ingested | Optimized | Savings |
|---------|--------|-----------------|-----------|---------|
| T-073 enrichment | 9 | ~27K (full YAML) | ~450 (summaries) | 96% |
| T-072 audit | 3 | ~15K | ~5K (structured) | 67% |
| T-061 investigation | 4 | ~10K | ~10K (need full) | 0% |
| T-086 evaluation | 5 | ~12K | ~12K (need full) | 0% |

**Key insight**: Investigation/evaluation patterns NEED results in-context for synthesis.
Enrichment/generation patterns do NOT — they should write to files and return summaries.

### Claude Code Agent Type Constraints

Cannot create new Claude Code agent types. Available: Explore, Plan, Code, general-purpose,
feature-dev:code-explorer, feature-dev:code-reviewer, feature-dev:code-architect,
superpowers:code-reviewer, code-simplifier:code-simplifier.

Specialization must be implemented as **structured prompts + conventions**, not new types.

## Go/No-Go Assessment

| Criterion | Evidence | Met? |
|-----------|----------|------|
| 3+ repeated patterns | 4 identified | YES |
| >20% token savings | 96% enrichment, 67% audit, 0% investigation | PARTIAL |
| Framework context needed | Enrichment needs templates, audit needs formats | PARTIAL |

No-Go counterpoints:
- Generic agents handle investigation/evaluation well (0% savings on most common pattern)
- Only enrichment genuinely broke (1 of 8 dispatches)
- Framework context CAN be passed ad-hoc in prompts

## Decision

**Decision**: GO

**Rationale**: MODIFIED GO: Build dispatch infrastructure (result protocol + prompt templates + CLAUDE.md guidelines). Evidence: 4 repeated patterns, 96% token savings on enrichment, but cannot create new Claude Code agent types. Pragmatic approach: standardize how we use existing agents rather than building new ones.

**Date**: 2026-02-17T07:50:48Z

## Updates

### 2026-02-17T07:40:40Z — task-created [task-create-agent]
- **Action:** Created inception task
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-097-deep-reflection-type-a-multi-agent-optim.md
- **Context:** Initial task creation

### 2026-02-17T07:50:00Z — deep-reflection-complete [orchestrator]
- **Action:** Completed deep reflection on Type A optimization
- **Output:** Full evidence catalog (8 dispatches across 96 tasks), 4 repeated patterns,
  token cost analysis, go/no-go assessment
- **Method:** 3 parallel sub-agents (catalog, agent-types, context-explosion) + manual synthesis
- **Decision:** MODIFIED GO — build dispatch infrastructure (protocol + templates + guidelines)
- **Context:** Evidence shows result management is the real problem, not agent specialization

### 2026-02-17T07:50:48Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** MODIFIED GO: Build dispatch infrastructure (result protocol + prompt templates + CLAUDE.md guidelines). Evidence: 4 repeated patterns, 96% token savings on enrichment, but cannot create new Claude Code agent types. Pragmatic approach: standardize how we use existing agents rather than building new ones.

### 2026-02-17T07:50:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
