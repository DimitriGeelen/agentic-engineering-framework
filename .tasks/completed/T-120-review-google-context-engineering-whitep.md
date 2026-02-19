---
id: T-120
name: Review Google Context Engineering whitepaper against framework
description: >
  Read Google's 'Context Engineering: Sessions & Memory' whitepaper (Milam & Gulli, Nov 2025) and reflect on alignment with our framework. Assess: (1) What concepts we already implement (sessions, memory tiers, context rot/compaction, memory provenance). (2) What ideas/philosophy/practices we could adapt. (3) Gaps or improvements suggested by the paper. Sources: https://www.kaggle.com/whitepaper-context-engineering-sessions-and-memory, https://developers.googleblog.com/architecting-efficient-context-aware-multi-agent-framework-for-production/, https://github.com/momo-personal-assistant/momo-research/blob/main/Context%20Engineering:%20Sessions,%20Memory.md. Key concepts to evaluate: push vs pull memory, context rot mitigation, memory consolidation, session containers, memory provenance tracking.

status: work-completed
horizon: later
workflow_type: inception
owner: human
tags: []
related_tasks: []
created: 2026-02-17T15:41:51Z
last_update: 2026-02-19T08:17:34Z
date_finished: 2026-02-19T08:17:34Z
---

# T-120: Review Google Context Engineering whitepaper against framework

## Problem Statement

Does Google's Context Engineering whitepaper (Milam & Gulli, Nov 2025) validate or challenge AEF's architecture? What concepts do we already implement, what should we adopt, and where do we diverge intentionally? The paper covers session management, memory tiers, context rot, consolidation, and provenance tracking for production multi-agent systems.

## Investigation Findings

### Alignment Map (Google → AEF)

| Google Concept | AEF Implementation | Alignment |
|---|---|---|
| **Session** (events + state) | `.context/working/session.yaml` + handover | Strong |
| **Memory** (long-term persistence) | `.context/project/` (decisions, learnings, patterns) + `.context/episodic/` | Strong |
| **Context** ("compiled view over richer state") | `LATEST.md` handover + `post-compact-resume.sh` injection | Strong |
| **Session ≠ Context** distinction | Session = full JSONL transcript; Context = injected handover summary | Strong |
| **Context rot** (attention degrades with length) | `budget-gate.sh` metered enforcement at 120K/150K/170K | Strong — AEF is stricter |
| **Memory tiers** (working / project / episodic) | Explicit 3-tier design in CLAUDE.md | Exact match |
| **Push memory** (proactive injection) | SessionStart hook injects handover context automatically | Strong |
| **Pull memory** (agent queries on demand) | `fw resume status`, `fw context status`, `fw healing patterns` | Strong |
| **Memory-as-a-tool** (LLM decides when to query) | `fw` commands available but not auto-triggered by LLM | Partial — AEF is explicit not autonomous |
| **Preserve failures** (keep failed turns for learning) | Healing loop + failure patterns in `patterns.yaml` | Strong |
| **Recitation pattern** (rewrite todos into recent context) | `focus.yaml` + task file as living document | Partial |
| **Restorable compression** (drop content, keep references) | Handover keeps file paths/task refs; full content in episodic | Partial |
| **Memory provenance** (source type, confidence, weight) | Learnings have task ref + source; no confidence/weight | Gap |
| **Memory consolidation** (merge, deduplicate, prune stale) | Manual via `fw promote`; no automated consolidation | Gap |
| **Strongly-typed events** (ADK Event records) | Markdown/YAML files (flexible but less structured) | Intentional divergence — portability |
| **Narrative casting** (prevent sub-agent role confusion) | Sub-Agent Dispatch Protocol defines scope/constraints | Partial |
| **Artifact externalization** (large payloads stored separately) | `fw bus` result ledger + `docs/reports/` | Strong |

### Concepts We Already Excel At (vs Google)

1. **Metered budget enforcement** — Google recommends "configurable thresholds" for compaction; AEF reads actual tokens from JSONL transcript and structurally blocks at critical. Google ADK's compaction is asynchronous; AEF's is synchronous gating.

2. **Failure as institutional learning** — Google says "preserve failures." AEF goes further: classify failures, match patterns, record resolutions, promote to practices. The healing loop is richer than simple preservation.

3. **Cross-session episodic memory** — Google describes memory managers but doesn't specify per-task episodic summaries. AEF's T-XXX.yaml episodics are more granular than typical memory systems.

4. **Authority model** — Google's ADK has no enforcement tiers. AEF's Tier 0-3 system with pre-tool-use hooks is unique.

### Gaps Identified (AEF could improve)

1. **Memory consolidation** — Google describes a 4-stage process: ingestion → extraction → consolidation → storage. The consolidation stage (merge duplicates, resolve conflicts, prune stale, apply TTL) is the most sophisticated. AEF's `fw promote` is manual and one-directional (learning → practice). No automated deduplication, staleness detection, or confidence decay.

2. **Memory provenance enrichment** — Google tracks source type (bootstrapped, user input, tool output), confidence weight, and reliance level per memory. AEF tracks task reference and source but no confidence/weight. This matters for consolidation quality.

3. **Trigger diversity** — Google identifies 4 trigger types for memory generation: session completion, turn cadence, real-time, explicit command. AEF only has session completion (episodic at `work-completed`) and explicit command (`fw context add-learning`). No turn-cadence or real-time triggers.

### Intentional Divergences (AEF ≠ Google by design)

1. **File-based vs database storage** — Google uses vector databases + knowledge graphs. AEF uses YAML/Markdown files. This is D4 (Portability) — no infrastructure dependencies.

2. **Explicit over autonomous memory** — Google's "memory-as-a-tool" lets the LLM decide when to store/retrieve. AEF keeps the agent explicit (`fw context add-learning`, `fw healing resolve`). This is D2 (Reliability) — deterministic over probabilistic.

3. **Synchronous vs asynchronous compaction** — Google ADK compacts asynchronously. AEF blocks tool calls at critical, forcing synchronous handover. This is D1 (Antifragility) — graceful degradation over silent loss.

## Assumptions

1. AEF's 3-tier memory already aligns with academic recommendations — **VALIDATED**: Exact match with Google's session/memory/context taxonomy.
2. Google's paper will reveal significant architectural gaps — **PARTIALLY VALIDATED**: Two concrete gaps found (consolidation, provenance), but AEF is ahead in enforcement, failure learning, and metered budget management.
3. Memory consolidation requires vector databases — **INVALIDATED**: Consolidation can be done with LLM-based comparison over YAML files. The algorithm (merge/deduplicate/prune) doesn't require embeddings.

## Scope Fence

**IN:** Compare paper recommendations to AEF, identify adoptable concepts
**OUT:** Implementing a full memory manager service, adding vector DB, changing storage from files

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Paper identifies concrete, bounded improvements to AEF's memory system
- Improvements align with D1-D4 directives

**NO-GO if:**
- All improvements require infrastructure dependencies (vector DB, knowledge graph)
- Improvements conflict with portability (D4) or reliability (D2)

## Decisions

**Decision**: GO

**Rationale**: 2 adoptable concepts: (1) memory consolidation protocol for automated dedup+pruning of project memory, (2) memory provenance enrichment with confidence levels. Both file-based, no infrastructure dependencies, align with D1-D4.

**Date**: 2026-02-19T08:17:34Z
## Decision

**Decision**: GO

**Rationale**: 2 adoptable concepts: (1) memory consolidation protocol for automated dedup+pruning of project memory, (2) memory provenance enrichment with confidence levels. Both file-based, no infrastructure dependencies, align with D1-D4.

**Date**: 2026-02-19T08:17:34Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-17T15:50:52Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-17T15:50:52Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-02-17T16:12:44Z — status-update [task-update-agent]
- **Change:** horizon: unset → later

### 2026-02-18T16:05:54Z — status-update [task-update-agent]
- **Change:** owner: agent → claude-code

### 2026-02-18T16:06:07Z — status-update [task-update-agent]
- **Change:** owner: claude-code → human

### 2026-02-19T08:15:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T08:17:34Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** 2 adoptable concepts: (1) memory consolidation protocol for automated dedup+pruning of project memory, (2) memory provenance enrichment with confidence levels. Both file-based, no infrastructure dependencies, align with D1-D4.

### 2026-02-19T08:17:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
