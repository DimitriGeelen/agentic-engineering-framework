# T-261: Q&A Phase 2 Research — Model, RAG Quality, Framework Integration

**Date:** 2026-02-23
**Predecessor:** T-254 (Q&A Phase 1 — inception), T-255..T-259 (Phase 1 build tasks)
**Status:** Research complete, GO decision pending

## Background

Phase 1 (T-254 → T-259) shipped a working LLM Q&A feature on the Watchtower search page:
- RAG retrieval via hybrid BM25 + sqlite-vec vector search with RRF fusion
- SSE streaming endpoint (`/search/ask`) using Ollama
- Frontend with token-by-token rendering, citations, source panel
- Model fallback (qwen2.5-coder-32b IQ2_M primary, dolphin-llama3:8b fallback)
- htmx SSE extension installed

**Hardware:** RTX 5060 TI with 16GB GDDR7 VRAM.

## Research Methodology

5 parallel research agents dispatched, each investigating one dimension:

| Agent | Report | Focus |
|-------|--------|-------|
| RQ-1 | [T-261-models-16gb-vram.md](T-261-models-16gb-vram.md) | Best LLM models for 16GB VRAM |
| RQ-2 | [T-261-rag-quality-techniques.md](T-261-rag-quality-techniques.md) | RAG retrieval and answer quality |
| RQ-3 | [T-261-thinking-models.md](T-261-thinking-models.md) | Reasoning/thinking models comparison |
| RQ-4 | [T-261-framework-enhancement.md](T-261-framework-enhancement.md) | Using Q&A to enhance the framework |
| RQ-5 | [T-261-arch-improvements.md](T-261-arch-improvements.md) | UX and architecture improvements |

## Dialogue Log

### Q1: How to improve answer quality? (Human)

"What are the possibilities to further improve the capability or the quality of the search outcome?
We can download another model. We just used the models available on the video card — 5060TI with 16GB."

**Findings:** Three convergent recommendations from RQ-1, RQ-2, RQ-3:

1. **Model replacement is the #1 win.** Current qwen2.5-coder-32b at IQ2_M (2-bit quantization) sacrifices both speed AND quality. A 14B model at Q4_K_M (4-bit) delivers better output quality while being 7x faster. The aggressive quantization to fit 32B params in 16GB is the worst trade-off.

2. **Qwen3-14B is the consensus pick** across both model agents — it's the only model family with toggleable thinking mode (fast for simple queries, deep reasoning for complex ones), runs at ~33 tok/s, 9.3GB leaves room for KV cache.

3. **RAG pipeline improvements** (embedding model upgrade, better system prompt, reranking) stack with the model upgrade for compound quality gains.

### Q2: How to use Q&A to enhance the framework? (Human)

"How can we use this capability to enhance our AI engineering framework?"

**Findings:** The keystone is `fw ask` — a synchronous CLI wrapper around the existing RAG+LLM pipeline. This unlocks 9 integration points (see RQ-4 report §Priority Matrix). Most impactful:
- Healing agent: replace 126 lines of bash keyword matching with one semantic query
- Session briefing: 200-word synthesis on `fw context focus` instead of reading 5 files
- Decision precedent: "Have we tried X before?" before making choices

### Q3: Can we save answers for later retrieval? (Human)

"In the search we can now ask questions — can we save answers and also use them for later retrieval? Do you see value in that?"

**Analysis:** High value. Each Q&A answer is a *synthesis* that doesn't exist in the raw knowledge base. Saving creates a flywheel:
1. User asks complex question → gets synthesized answer
2. User saves it (one click) → stored as `.context/qa/*.md`
3. Saved answer gets indexed alongside other documents
4. Future similar queries find the curated answer as a high-quality chunk
5. LLM cites it, producing even better answers over time

**Key distinction from caching:** Cache is automatic/ephemeral/exact-match. Saved answers are curated/permanent/searchable-by-content. This builds an organic FAQ from actual usage patterns.

## Key Decisions

### D1: Replace qwen2.5-coder-32b IQ2_M with Qwen3-14B Q4_K_M

**Chose:** Qwen3-14B as primary model
**Why:** 7x faster (33 vs 4.8 tok/s), better quality (Q4 loses 2-5% vs FP16; IQ2_M loses far more), toggleable thinking mode, 9.3GB leaves headroom
**Rejected:**
- GPT-OSS 20B MoE: faster (80-140 tok/s) but 14GB is tight for KV cache; no thinking toggle
- DeepSeek R1 14B: best pure reasoning but always-on thinking adds latency to simple queries
- Keeping current setup: evidence is overwhelming that IQ2_M 32B is worst of both worlds
**Evidence:** RQ-1 §Performance Comparison, RQ-3 §Model Recommendations

### D2: Qwen3-14B as single model (not dual-model setup)

**Chose:** Single model with dynamic `think` toggle
**Why:** Thinking toggle eliminates need for separate fast/deep models. One model in VRAM, no swap latency, simpler infrastructure.
**Rejected:** Two-model router (can't fit both in 16GB simultaneously, 5-15s model swap penalty)
**Evidence:** RQ-3 §Hybrid Approach, Strategy 1

### D3: `fw ask` CLI as keystone integration

**Chose:** Build synchronous CLI wrapper before other framework integrations
**Why:** Every downstream integration (healing, briefing, precedent mining) depends on programmatic Q&A access. The existing `/search/ask` is HTTP+SSE (streaming), agents need synchronous Python/CLI.
**Rejected:** Direct HTTP calls from bash agents (fragile, slow, requires server running)
**Evidence:** RQ-4 §Priority Matrix — all 8 enhancements depend on #1

### D4: Saved answers as indexed markdown files

**Chose:** Save to `.context/qa/*.md`, indexed by existing search infrastructure
**Why:** Zero new infrastructure — files get picked up by the existing BM25+vector indexer. Markdown is human-readable, git-trackable, grep-able.
**Rejected:** SQLite storage (not indexable by current search), Redis (new dependency), in-memory only (ephemeral)
**Evidence:** Conversation Q3 analysis + RQ-5 §Answer Caching (adapted)

### D5: Phased implementation — model first, then RAG, then UX

**Chose:** Model replacement → RAG quick wins → fw ask CLI → saved answers → UX improvements
**Why:** Model replacement has highest impact-to-effort ratio and unblocks thinking mode. RAG improvements compound with better model. `fw ask` enables framework integration. Saved answers build on working Q&A.
**Rejected:** Starting with UX (high effort, doesn't improve answer quality); starting with fw ask (model quality is the bottleneck)
**Evidence:** Synthesis of all 5 reports

## Improvement Inventory

### Tier 1: High Impact, Low Effort (do first)

| ID | Improvement | Effort | Impact | Report Reference |
|----|-------------|--------|--------|-----------------|
| IMP-1 | Replace model with Qwen3-14B | 2h | Massive | RQ-1 §Tier 1 #1, RQ-3 §7 |
| IMP-2 | Improve system prompt (anti-hallucination) | 15min | High | RQ-2 §4.2 |
| IMP-3 | Upgrade embedding model (nomic-embed-text) | 1h | High | RQ-2 §3.2 |
| IMP-4 | Add chunk overlap (150-200 chars) | 30min | Medium | RQ-2 §2.2A |

### Tier 2: High Impact, Medium Effort

| ID | Improvement | Effort | Impact | Report Reference |
|----|-------------|--------|--------|-----------------|
| IMP-5 | `fw ask` CLI wrapper | 4h | High | RQ-4 §1, §Architectural Notes |
| IMP-6 | Saved answers (curated Q&A) | 2h | High | Conversation Q3 |
| IMP-7 | Cross-encoder reranking (Qwen3-Reranker) | 3h | High | RQ-2 §1.1 |
| IMP-8 | Streaming UX (marked.js, highlight, copy) | 2d | High | RQ-5 §4 |
| IMP-9 | User feedback (thumbs up/down) | 1.5d | High | RQ-5 §3 |

### Tier 3: Medium Impact, Higher Effort

| ID | Improvement | Effort | Impact | Report Reference |
|----|-------------|--------|--------|-----------------|
| IMP-10 | Multi-turn conversation | 3d | High | RQ-5 §1 |
| IMP-11 | Query understanding + intent classification | 3d | Medium-High | RQ-5 §5 |
| IMP-12 | Healing agent integration (replace bash matching) | 4h | High | RQ-4 §4 |
| IMP-13 | Session briefing on focus | 2h | High | RQ-4 §6 |
| IMP-14 | Answer quality metrics | 2.5d | Medium | RQ-5 §6 |

### Tier 4: Future / Evaluate Later

| ID | Improvement | Effort | Impact | Report Reference |
|----|-------------|--------|--------|-----------------|
| IMP-15 | Incremental indexing | 3h | Medium | RQ-2 §6.2 |
| IMP-16 | HyDE (hypothetical document embeddings) | 3h | Medium | RQ-2 §1.3 |
| IMP-17 | Query expansion / multi-query | 4h | Medium | RQ-2 §1.2 |
| IMP-18 | Cross-project knowledge federation | High | Medium | RQ-4 §9 |
| IMP-19 | Concurrent request handling | 2d | Medium | RQ-5 §7 |
| IMP-20 | Retrospective analysis automation | Medium | Medium | RQ-4 §7 |

## VRAM Budget (Post-Upgrade)

| Component | VRAM | Notes |
|-----------|------|-------|
| Qwen3-14B Q4_K_M | 9.3 GB | Primary LLM |
| nomic-embed-text | ~270 MB | Embedding model (upgrade from MiniLM) |
| Qwen3-Reranker 0.6B | ~500 MB | Cross-encoder reranking (on-demand) |
| KV cache (32K ctx) | ~3-4 GB | Depends on context length |
| **Total** | **~13-14 GB** | Fits 16GB with margin |

## Go/No-Go Criteria

- **GO if:** Model replacement demonstrably improves answer quality + speed
- **GO if:** fw ask CLI provides value to at least one agent workflow
- **NO-GO if:** Qwen3-14B quality is worse than current setup (unlikely given evidence)
- **NO-GO if:** VRAM budget doesn't fit (calculate before pulling model)
