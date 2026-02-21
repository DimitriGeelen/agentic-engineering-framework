---
id: T-235
name: "Agent fabric awareness + vector database for semantic search"
description: >
  Inception: Agent fabric awareness + vector database for semantic search

status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-02-21T21:03:25Z
last_update: 2026-02-21T21:48:07Z
date_finished: 2026-02-21T21:48:07Z
---

# T-235: Agent fabric awareness + vector database for semantic search

## Problem Statement

Two questions about scaling the framework's intelligence: (1) Do agents know about Context Fabric and Component Fabric? (2) Should we add a vector database for semantic search as the knowledge base grows?

## Assumptions

- A-001: Agents are largely unaware of each other's capabilities → **Validated** (cross-agent coordination: 0%)
- A-002: Text search is insufficient at current scale → **Partially validated** (BM25 covers 60-70%, terminology fragmentation is the real blocker)
- A-003: Vector DB adds significant value → **Validated for "find similar" queries only** (30-40% of use cases)

## Exploration Plan

3 parallel research agents: (1) audit all agent scripts for fabric references, (2) assess current search and data volume, (3) evaluate 7 vector DB technologies with web research. All completed.

## Scope Fence

**IN:** Agent awareness gaps, search technology evaluation, tiered recommendations
**OUT:** Implementation of fixes (separate build tasks)

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Agent awareness gaps are real and fixable — **YES** (5 gaps, 2 quick wins)
- Search infrastructure upgrade has clear ROI — **YES** (tantivy BM25 as starting point)

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decision

**Decision**: GO — Split into two independent build tasks.

**Rationale**: Both topics validated by 3 parallel research agents. Agent awareness is 5/10 with clear quick wins (fabric in git hooks, auto-capture learnings). BM25 text search (tantivy) is the right starting point for search, with embeddings (sqlite-vec) planned for later.

**Date**: 2026-02-21T21:47:28Z

**Successor tasks:**
- T-236: Wire agent fabric awareness (blast-radius in git, auto-capture learnings)
- T-237: Add search infrastructure (tantivy BM25, replace grep)

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-21T21:47:28Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision: GO
- **Rationale:** Both topics validated. Splitting into T-236 (agent awareness) and T-237 (search infrastructure).

### 2026-02-21T21:48:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
