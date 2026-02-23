---
id: T-254
name: "LLM-assisted Q&A for Watchtower search"
description: >
  Inception: LLM-assisted Q&A for Watchtower search

status: work-completed
workflow_type: inception
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-02-23T20:29:07Z
last_update: 2026-02-23T20:37:57Z
date_finished: 2026-02-23T20:37:57Z
---

# T-254: LLM-assisted Q&A for Watchtower search

## Problem Statement

Watchtower search returns ranked document snippets but users must mentally synthesize answers across multiple results. Need LLM-assisted natural language Q&A that retrieves context via semantic search (T-245) and synthesizes coherent answers with citations. Local-only (ollama), extending `/search` page, covering knowledge files + source code.

## Assumptions

- A-001: Local qwen2.5-coder-32b (IQ2_M) produces useful answers at 4.8 tok/s — **VALIDATED** (direct measurement)
- A-002: Existing hybrid_search() provides sufficient retrieval quality for RAG — **VALIDATED** (agent RQ-2)
- A-003: htmx SSE extension enables streaming UX without custom JS — **VALIDATED** (agent RQ-3)
- A-004: RAM is sufficient for concurrent ollama + Watchtower + embeddings — **VALIDATED with risk** (386MB free, needs single-model loading)

## Exploration Plan

4 parallel research agents dispatched to investigate: RQ-1 (ollama API), RQ-2 (RAG architecture), RQ-3 (UX design), RQ-4 (performance). All completed. See `docs/reports/T-254-llm-assisted-qa-research.md`.

## Technical Constraints

- RTX 5060 Ti: 16GB VRAM, ~8GB free after desktop
- 32GB RAM, only 386MB free (18GB cached) — RAM is the bottleneck
- qwen2.5-coder-32b: 32K context, 4.8 tok/s, 4.6s TTFT
- dolphin-llama3:8b: 32K context, 30 tok/s, <0.1s TTFT (fallback)
- htmx SSE requires 2.0+ (version check needed)

## Scope Fence

**IN:** Single-shot Q&A, streaming answers, inline citations, source panel, model fallback
**OUT:** Multi-turn chat, answer caching, user feedback loop, reranking (all Phase 2)

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested
- [x] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:** All RQs answered, hardware fits, <500 lines new code, existing infra reusable
**NO-GO if:** Model doesn't fit VRAM, answer quality unacceptable, >1000 lines needed

## Verification

# Research doc exists
test -f docs/reports/T-254-llm-assisted-qa-research.md

## Decisions

### 2026-02-23 — GO decision
- **Chose:** GO — proceed to build
- **Why:** All 4 research questions answered positively. Existing infra covers 80%. ~300 lines new code. Hardware adequate. No external deps.
- **Rejected:** No-go — all blockers resolved; Defer — user wants this now

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-02-23T20:37:08Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All 4 research questions answered positively. Existing infra covers 80%. ~300 lines new code. Hardware adequate. No external deps.

### 2026-02-23T20:37:19Z — status-update [task-update-agent]
- **Change:** owner: human → agent

### 2026-02-23T20:37:19Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** All 4 research questions answered positively. Existing infra covers 80%. ~300 lines new code. Hardware adequate. No external deps.

### 2026-02-23T20:37:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
