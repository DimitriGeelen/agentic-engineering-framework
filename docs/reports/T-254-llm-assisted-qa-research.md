---
title: "T-254: LLM-Assisted Q&A for Watchtower Search — Research"
task: T-254
type: inception
created: 2026-02-23
---

# T-254: LLM-Assisted Q&A for Watchtower Search

## Problem Statement

Watchtower search returns ranked document snippets but users must mentally synthesize answers from multiple results. An LLM-assisted mode would take the user's natural language question, retrieve relevant context via semantic search (T-245), and synthesize a coherent answer with citations.

## Known Constraints

- **Local-only LLM** — ollama is installed with qwen2.5-coder-32b (IQ2_M, 11GB) and dolphin-llama3:8b (4.7GB)
- **Hardware** — RTX 5060 Ti (16GB VRAM, ~8GB free), 32GB RAM
- **Existing infrastructure** — semantic search (T-245) already indexes 885 docs / 11.7K chunks
- **Scope** — extend `/search` page, include both knowledge files AND source code

## Research Questions

### RQ-1: Ollama API integration patterns
- How to call ollama from Python (streaming vs blocking)?
- What's the context window of qwen2.5-coder-32b?
- Token throughput on this hardware?

### RQ-2: RAG architecture for our stack
- How many chunks to retrieve? What's the sweet spot for context vs quality?
- How to format retrieved chunks as LLM context?
- Should we use the existing sqlite-vec search or add a dedicated retriever?

### RQ-3: UX design for Q&A mode
- Streaming responses vs wait-for-complete?
- How to display citations/sources alongside the answer?
- How does this integrate with existing search modes (keyword/semantic/hybrid)?

### RQ-4: Performance and resource management
- Can we run ollama + Watchtower + embedding model concurrently?
- What's acceptable latency for a Q&A response?
- Should ollama model be pre-loaded or loaded on demand?

## Agent Research Findings

### RQ-1: Ollama API Integration (direct measurement + agent research)

**Python API**: `ollama` pip package (v0.6.1) supports streaming chat:
```python
import ollama
response = ollama.chat(
    model='krith/qwen2.5-coder-32b-instruct:IQ2_M',
    messages=[
        {'role': 'system', 'content': 'You are a helpful assistant...'},
        {'role': 'user', 'content': 'Question here'}
    ],
    stream=True
)
for chunk in response:
    token = chunk['message']['content']  # yields token by token
    if chunk.get('done'):
        break
```

**Context window**: qwen2.5-coder-32b — **32,768 tokens** (confirmed via `ollama show`)

**Throughput on this hardware** (RTX 5060 Ti):
| Model | TTFT | Generation | Total (short answer) |
|-------|------|-----------|---------------------|
| qwen2.5-coder-32b (IQ2_M) | 4.6s | 4.8 tok/s | ~14s for 43 tokens |
| dolphin-llama3:8b (Q4_0) | <0.1s (warm) | 30 tok/s | <1s for 9 tokens |

**Implication**: For a ~300-token answer, qwen takes ~60s generation + 5s TTFT = **~65s total**. Dolphin takes ~10s. Streaming masks the wait — first tokens appear in 5s (qwen) or instantly (dolphin).

### RQ-2: RAG Architecture (agent: `/tmp/fw-agent-rq2.md`, 219 lines)

**Reuse existing search**: YES — `hybrid_search()` returns path, title, category, task_id, score, snippet. Production-ready for RAG with minor extensions.

**Chunk budget for 32K context**:
- System prompt + instruction: ~1,500 tokens
- Answer generation buffer: ~2,500 tokens
- Available for chunks: ~28,000 tokens
- Each chunk: ~1,150 tokens (1,500 chars)
- **Sweet spot: 8-12 chunks** (9,200-13,800 tokens) with 14-18K margin

**Context format**: Numbered Markdown with metadata (recommended over XML):
```
## Sources

[1] **Title** (Category | Score: 0.89)
Path: .tasks/completed/T-118.md
Content: ...chunk text...

[2] **Title** ...
```

**New code**: ~30-50 lines wrapper `rag_retrieve()` adding category filtering, score thresholding, deduplication. Main extension: return `chunk_text` field (currently snippet-only in results).

### RQ-3: UX Design (agent: `/tmp/fw-agent-rq3.md`, 220 lines)

**Integration approach**: **Separate "Ask" section** on search page (NOT a 4th dropdown mode). Reasoning: Q&A generates content vs retrieves it — fundamentally different UX affordance.

**Streaming**: Flask native SSE (no extra deps):
```python
@bp.route('/search/ask')
def ask():
    def generate():
        for token in ollama_stream(query, chunks):
            yield f"data: {json.dumps({'token': token})}\n\n"
    return Response(generate(), mimetype='text/event-stream')
```

**Frontend**: htmx 2.0+ SSE extension (`hx-ext="sse"`, `sse-connect="/search/ask?q=..."`). Tokens stream word-by-word into answer div. No custom JavaScript needed.

**Citations**: Inline [1][2] in answer text + collapsible "Sources" panel below with:
- File name + path
- Relevance score
- Snippet excerpt
- Clickable link to Watchtower page (reuses T-253 URL mapping)

**htmx version check needed**: Current `htmx.min.js` may be 1.x — SSE extension requires 2.0+.

### RQ-4: Performance (agent task notification + direct measurement)

**Concurrent operation**: YES — ollama, sentence-transformers, and Watchtower coexist. GPU has headroom. **RAM is the constraint** (386MB free, 18GB cached).

**Model loading**: Neither model pre-loaded. Cold start adds ~20s. **Recommendation**: Pre-load default model via cron or Watchtower startup hook.

**Latency for full RAG query** (retrieve 10 chunks + generate ~300-token answer):
| Model | Retrieval | TTFT | Generation | Total |
|-------|-----------|------|-----------|-------|
| qwen2.5-coder-32b | <1s | ~5s | ~60s (300 tok @ 4.8/s) | ~66s |
| dolphin-llama3:8b | <1s | <1s | ~10s (300 tok @ 30/s) | ~12s |

**Streaming UX**: With streaming, user sees first tokens in 5s (qwen) or <1s (dolphin). Perceived latency much lower than total.

**Fallback**: Use qwen by default for quality; fall back to dolphin if GPU memory < 2GB or queue depth > 3.

## Considerations

1. **Quality vs speed tradeoff**: Qwen produces better, more detailed answers but takes ~65s. Dolphin is 5x faster but less capable. Streaming UX makes qwen acceptable (first token in 5s).

2. **RAM risk**: System has only 386MB free RAM. Loading both models simultaneously may trigger OOM. Mitigation: only one model loaded at a time, with `ollama unload` between switches.

3. **htmx version**: SSE extension requires htmx 2.0+. Need to verify current version and potentially upgrade — this could affect other htmx interactions on the site.

4. **Answer quality**: With IQ2_M quantization, qwen2.5-coder may hallucinate more than full-precision. Need to test with real framework questions and verify citations match sources.

5. **Chunk text availability**: Current `search()` returns snippets (200 chars), not full chunk text. Need to extend to return `chunk_text` for RAG context — minor change to embeddings.py.

6. **No follow-up conversation**: This is single-shot Q&A, not a chat. Each question is independent. Follow-up support would require session state — defer to Phase 2.

7. **Caching opportunity**: Identical questions could be cached (query hash → answer). Useful if multiple users ask similar questions.

## Decisions

### 2026-02-23 — LLM model selection
- **Chose:** qwen2.5-coder-32b (IQ2_M) as primary, dolphin-llama3:8b as fallback
- **Why:** Best available quality for code + natural language understanding; IQ2_M fits in 16GB VRAM; dolphin provides fast fallback
- **Rejected:** External API (Claude/OpenAI) — user specified local-only; gpt-oss:20b — 13GB, tight on VRAM, no clear quality advantage

### 2026-02-23 — UX integration approach
- **Chose:** Separate "Ask" section on /search page with SSE streaming
- **Why:** Q&A (generation) is fundamentally different from search (retrieval); separate section sets correct user expectations; streaming masks latency
- **Rejected:** 4th mode in dropdown — conflates generation with retrieval; separate /ask page — fragments navigation

### 2026-02-23 — RAG retrieval strategy
- **Chose:** Reuse existing hybrid_search() with rag_retrieve() wrapper, 10 chunks, numbered Markdown context
- **Why:** Existing infrastructure proven (T-245), minimal new code (~50 lines), RRF fusion gives best retrieval quality
- **Rejected:** New dedicated retriever — unnecessary duplication; raw semantic-only — misses keyword matches; XML format — less natural for LLM reasoning

### 2026-02-23 — Citation display
- **Chose:** Inline [1][2] numbered citations + collapsible source panel
- **Why:** Industry standard (Perplexity, Google AI), clean UX, reuses T-253 URL mapping for source links
- **Rejected:** Hover tooltips only — requires interaction; full source panel always visible — too noisy

## Build Tasks (if GO)

| Task | Description | Estimate |
|------|-------------|----------|
| T-next-1 | Add `rag_retrieve()` wrapper + return chunk_text from embeddings.py | Small (30-50 lines) |
| T-next-2 | `/search/ask` Flask endpoint with ollama streaming + SSE | Medium (~100 lines) |
| T-next-3 | Frontend: Ask section in search.html with htmx SSE, answer div, source panel | Medium (~80 lines) |
| T-next-4 | Model pre-loading + fallback logic | Small (~30 lines) |
| T-next-5 | htmx 2.0+ upgrade (if needed) + SSE extension | Small (dependency) |

## Go/No-Go

**Recommendation: GO**

**Evidence:**
- All 4 research questions answered positively
- Existing infrastructure covers 80% of needs (semantic search, URL mapping, htmx)
- New code estimated at ~300 lines across 5 small tasks
- Hardware adequate (GPU fits model, streaming masks latency)
- No external dependencies required (local ollama, existing pip packages)

**Risks:**
- RAM contention (mitigated by single-model loading)
- qwen2.5 answer quality at IQ2_M quantization (mitigated by dolphin fallback + testing)
- htmx upgrade may have side effects (mitigated by version pinning + testing)

**Pending: Human approval required.**
