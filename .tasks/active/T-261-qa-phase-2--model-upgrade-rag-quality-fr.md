---
id: T-261
name: "Q&A Phase 2 — model upgrade, RAG quality, framework integration, saved answers"
description: >
  Inception: Investigate and plan improvements to the Q&A system shipped in Phase 1
  (T-254..T-259). Five research agents explored: model selection for 16GB VRAM,
  RAG quality techniques, thinking/reasoning models, framework self-enhancement
  via Q&A, and UX/architecture improvements. Research complete, GO decision pending.

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: [qa, llm, rag, search, watchtower]
components: [web/ask.py, web/embeddings.py, web/blueprints/discovery.py, web/templates/search.html]
related_tasks: [T-254, T-255, T-256, T-257, T-258, T-259]
created: 2026-02-24T08:33:55Z
last_update: 2026-02-24T08:33:55Z
date_finished: null
---

# T-261: Q&A Phase 2 — model upgrade, RAG quality, framework integration, saved answers

## Problem Statement

Phase 1 Q&A works but has known limitations:
1. **Model quality:** qwen2.5-coder-32b at IQ2_M (2-bit) is the worst trade-off — 4.8 tok/s AND degraded quality. A properly quantized smaller model would be both faster and better.
2. **RAG pipeline:** Weak embedding model (all-MiniLM-L6-v2, 2022), no reranking, no chunk overlap, basic system prompt.
3. **No framework integration:** Q&A is browser-only. Framework agents can't query the knowledge base programmatically.
4. **No knowledge capture:** Good answers are ephemeral — can't be saved and reused.
5. **Basic UX:** No markdown rendering, no code highlighting, no multi-turn, no feedback.

## Assumptions

1. Qwen3-14B Q4_K_M fits in 16GB VRAM with room for KV cache + embedding model (~9.3 + 0.3 + 3-4 = ~13GB)
2. Toggleable thinking mode (Qwen3-specific) provides both fast and deep paths with one model
3. Saved Q&A answers will be useful as retrieval sources (flywheel hypothesis)
4. `fw ask` CLI will be adopted by at least one agent workflow (healing or context briefing)

## Exploration Plan

Research phase (COMPLETE — 5 agents dispatched 2026-02-23):
- RQ-1: Model options for 16GB VRAM → [T-261-models-16gb-vram.md](../../docs/reports/T-261-models-16gb-vram.md)
- RQ-2: RAG quality techniques → [T-261-rag-quality-techniques.md](../../docs/reports/T-261-rag-quality-techniques.md)
- RQ-3: Thinking/reasoning models → [T-261-thinking-models.md](../../docs/reports/T-261-thinking-models.md)
- RQ-4: Framework enhancement via Q&A → [T-261-framework-enhancement.md](../../docs/reports/T-261-framework-enhancement.md)
- RQ-5: Architecture improvements → [T-261-arch-improvements.md](../../docs/reports/T-261-arch-improvements.md)
- Synthesis: [T-261-qa-phase2-research.md](../../docs/reports/T-261-qa-phase2-research.md)

## Technical Constraints

- **GPU:** RTX 5060 TI, 16GB GDDR7, 448 GB/s bandwidth
- **VRAM budget:** ~14GB usable (1-2GB system overhead), models must fit entirely in VRAM for acceptable speed
- **Ollama:** All models must be available via `ollama pull`
- **Thinking mode:** Only Qwen3 family supports toggleable thinking; DeepSeek R1 and Phi-4 are always-on
- **SSE + POST:** Multi-turn requires switching from EventSource (GET-only) to fetch + ReadableStream
- **Flask template caching:** Must restart server after template edits

## Scope Fence

**IN scope:**
- Model replacement (Qwen3-14B)
- RAG quick wins (prompt, embeddings, chunking, reranking)
- `fw ask` CLI wrapper
- Saved answers for retrieval
- Streaming UX improvements
- User feedback loop
- Multi-turn conversation
- Framework agent integration (healing, briefing)

**OUT of scope (Tier 4 / future):**
- Cross-project knowledge federation (RQ-4 §9)
- Fine-tuning embedding models (RQ-2 §Tier 4)
- Semantic chunking (rule-based gets 80% of benefit — RQ-2 §2.2D)
- Production WSGI deployment (Gunicorn — RQ-5 §7)

## Acceptance Criteria

- [x] Problem statement validated
- [x] Assumptions tested (via research agents)
- [ ] Go/No-Go decision made

## Go/No-Go Criteria

**GO if:**
- Model replacement demonstrably improves answer quality + speed
- `fw ask` CLI provides value to at least one agent workflow
- VRAM budget fits (Qwen3-14B + nomic-embed-text + reranker < 14GB)

**NO-GO if:**
- Qwen3-14B quality is worse than current setup (unlikely per RQ-1/RQ-3 evidence)
- VRAM budget doesn't fit

## Verification

test -f docs/reports/T-261-qa-phase2-research.md
test -f docs/reports/T-261-models-16gb-vram.md
test -f docs/reports/T-261-rag-quality-techniques.md
test -f docs/reports/T-261-thinking-models.md
test -f docs/reports/T-261-framework-enhancement.md
test -f docs/reports/T-261-arch-improvements.md

## Decisions

**Decision**: GO

**Rationale**: Research complete: 5 agents, 6 reports, 20 improvements identified. Model replacement alone (Qwen3-14B) delivers 7x speed + better quality. RAG quick wins stack for compound gains. fw ask CLI unlocks 8 framework integrations. Saved answers create knowledge flywheel. 9 build tasks created (T-262..T-270) with rich references to research. VRAM budget confirmed: 13-14GB of 16GB.

**Date**: 2026-02-24T08:38:39Z
## Decision

**Decision**: GO

**Rationale**: Research complete: 5 agents, 6 reports, 20 improvements identified. Model replacement alone (Qwen3-14B) delivers 7x speed + better quality. RAG quick wins stack for compound gains. fw ask CLI unlocks 8 framework integrations. Saved answers create knowledge flywheel. 9 build tasks created (T-262..T-270) with rich references to research. VRAM budget confirmed: 13-14GB of 16GB.

**Date**: 2026-02-24T08:38:39Z

## Updates

### 2026-02-23 — Research phase complete
- 5 parallel research agents dispatched and completed
- 6 reports saved to docs/reports/T-261-*
- 20 improvement opportunities identified, prioritized into 4 tiers
- 5 key decisions recorded with evidence
- Human Q&A discussion captured in dialogue log (see research doc)

### 2026-02-24T08:38:39Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Research complete: 5 agents, 6 reports, 20 improvements identified. Model replacement alone (Qwen3-14B) delivers 7x speed + better quality. RAG quick wins stack for compound gains. fw ask CLI unlocks 8 framework integrations. Saved answers create knowledge flywheel. 9 build tasks created (T-262..T-270) with rich references to research. VRAM budget confirmed: 13-14GB of 16GB.
