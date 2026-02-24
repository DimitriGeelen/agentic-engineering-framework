# RAG Quality Improvement Research Report

**Date:** 2026-02-24
**Context:** Current system uses sqlite-vec (384-dim, all-MiniLM-L6-v2) + Tantivy BM25 with RRF (k=60), returning 10 chunks to LLM. Target: 16GB VRAM shared with LLM.

---

## 1. Retrieval Improvements

### 1.1 Reranking (Cross-Encoder)

**What:** After initial retrieval (BM25+vector), a cross-encoder model rescores query-document pairs for deeper semantic matching. Cross-encoders process the full query+document pair jointly, unlike bi-encoders that embed separately.

**Best Local Models (Ollama-compatible, 2025-2026):**
- **Qwen3-Reranker 0.6B** (Q4_K_M: ~0.5GB VRAM) -- excellent quality-to-size ratio, fits easily alongside LLM
- **Qwen3-Reranker 4B** (Q4_K_M: ~2.5GB VRAM) -- best balance for 16GB setup
- **bge-reranker-v2-m3** (~0.6B) -- BAAI model, good multilingual support
- Note: Ollama added native rerank endpoint support -- check `ollama pull qwen3-reranker:0.6b`

**Implementation in current system:**
After initial RRF fusion in rag_retrieve(), retrieve top-30 candidates via existing hybrid search, rerank with cross-encoder, return top-10 reranked results.

**Complexity:** Low-Medium (add ~30 lines to embeddings.py rag_retrieve())
**Expected gain:** 15-30% improvement in retrieval precision (MRR, NDCG)
**VRAM cost:** 0.5-2.5GB depending on model size
**Recommendation:** HIGH PRIORITY -- biggest bang-for-buck improvement

### 1.2 Query Expansion / Multi-Query

**What:** Generate 2-3 alternative phrasings of the user query using the LLM, then retrieve for each and merge results.

**Approach for this system:**
- Use the existing Ollama LLM to generate 2-3 query variants
- Run hybrid_search() for each variant
- Merge via RRF across all result sets
- Example: "How do I create a task?" -> ["task creation process", "fw task create command", "task lifecycle start"]

**Complexity:** Medium (new function, ~50 lines, adds latency from LLM call)
**Expected gain:** 20-40% recall improvement, especially for vague/conceptual queries
**VRAM cost:** 0 (reuses existing LLM)
**Latency cost:** +2-5 seconds for query expansion LLM call
**Recommendation:** MEDIUM PRIORITY -- good for conceptual questions but adds latency

### 1.3 HyDE (Hypothetical Document Embeddings)

**What:** Instead of embedding the query directly, use the LLM to generate a hypothetical answer, then embed THAT for vector search. The hypothesis captures the vocabulary and style of actual documents better than raw queries.

**Complexity:** Low (~20 lines)
**Expected gain:** 10-25% improvement in vector recall; up to 42% in some benchmarks
**VRAM cost:** 0 (reuses existing LLM)
**Latency cost:** +2-4 seconds for hypothesis generation
**Caveats:** Less effective for factual/specific queries (e.g., "What is T-042?") where the query IS already precise. Best for conceptual queries.
**Recommendation:** MEDIUM PRIORITY -- complement to query expansion, not a replacement

### 1.4 Parent-Child Chunk Retrieval

**What:** Index small chunks (100-300 chars) for precise matching, but return the parent chunk (1500-3000 chars) to the LLM for full context.

**Implementation changes:**
- Add parent_id column to documents table
- During indexing: create child chunks from each parent chunk
- During search: match on child embeddings, return parent text
- Alternatively: store chunk_index relationships and return adjacent chunks

**Complexity:** Medium-High (schema change, re-index, modify retrieval logic)
**Expected gain:** 10-20% improvement in answer completeness (LLM gets more context)
**Recommendation:** MEDIUM PRIORITY -- but overlaps with improving chunk size (see section 2)

---

## 2. Chunking Strategy Improvements

### 2.1 Current State Analysis

The current system uses:
- max_chars=1500 fixed-size chunking
- Splits on markdown headings (#{1,3}) first, then paragraph boundaries
- **No overlap** between chunks
- Title prepended to non-first chunks for context

**Issues identified:**
1. 1500 chars (~375 tokens) is reasonable for documentation but may be too large for precise retrieval
2. No overlap means context at chunk boundaries is lost
3. No awareness of YAML frontmatter structure (task files have frontmatter + body)

### 2.2 Recommended Improvements

**A. Add chunk overlap (10-15%)**
After splitting, create overlap by including last 150-200 chars of previous chunk as prefix.

**Complexity:** Very Low (~10 lines)
**Expected gain:** 5-10% retrieval improvement at chunk boundaries

**B. Optimize chunk sizes by document type**

| Document Type | Recommended Size | Rationale |
|---|---|---|
| Task files (.tasks/) | 800-1000 chars | ACs, context, decisions are distinct sections |
| Episodic summaries | 1500 chars (current) | Already structured summaries |
| CLAUDE.md / specs | 1000-1200 chars | Dense reference material benefits from smaller chunks |
| Handovers | 1000-1200 chars | Mixed state + action items |
| Component cards (YAML) | Whole file | Small files, embed as-is |

**Complexity:** Low (~30 lines to add category-aware chunking)
**Expected gain:** 5-15% improvement in retrieval relevance

**C. YAML-aware chunking for task files**
- Split frontmatter from body
- Frontmatter as one chunk (metadata-rich)
- Body sections (Context, ACs, Verification, Decisions) as separate chunks
- Each chunk gets the task ID and name prepended

**Complexity:** Medium (~50 lines)
**Expected gain:** 10-15% for task-related queries

**D. Semantic chunking (advanced)**
- Use the embedding model to detect semantic boundaries
- Compute embeddings for sliding windows, split where cosine similarity drops
- More expensive at index time but produces semantically coherent chunks

**Complexity:** High (new dependency or significant code)
**Expected gain:** 10-20% but expensive to implement
**Recommendation:** LOW PRIORITY -- rule-based improvements (A, B, C) give 80% of the benefit

---

## 3. Embedding Model Improvements

### 3.1 Current Model

- **all-MiniLM-L6-v2**: 384-dim, ~80MB, via sentence-transformers (NOT Ollama)
- Good general-purpose model but dated (2022)
- Runs on CPU (no GPU needed for this small model)

### 3.2 Better Alternatives via Ollama

| Model | Dimensions | Size | MTEB Score | Notes |
|---|---|---|---|---|
| **nomic-embed-text** | 768 | ~270MB | 62.4 | Good for long context (8192 tokens) |
| **mxbai-embed-large** | 1024 | ~670MB | 64.7 | Best quality in Ollama ecosystem |
| **bge-m3** | 1024 | ~670MB | 63.5 | Excellent multilingual, sparse+dense hybrid |
| **snowflake-arctic-embed:335m** | 1024 | ~670MB | 63.2 | Good code understanding |
| **Qwen3-Embedding:0.6B** | 1024 | ~0.5GB | 65.1 | NEWEST, #1 on MTEB multilingual at 0.6B size |
| all-MiniLM-L6-v2 (current) | 384 | ~80MB | 56.3 | Baseline |

**Migration path:**
1. Switch from sentence-transformers to Ollama embedding API (ollama.embed())
2. Unifies embedding infrastructure (one runtime: Ollama for both LLM + embeddings)
3. Change EMBEDDING_DIM and MODEL_NAME constants
4. Rebuild index (one-time cost)

**Recommended model: nomic-embed-text** (already mentioned in task description)
- 768-dim, good quality, runs fast on CPU/GPU
- 8192 token context window (vs 512 for MiniLM) -- critical for larger chunks
- ~270MB VRAM if GPU-loaded, or runs on CPU with minimal impact

**Alternative: Qwen3-Embedding:0.6B** -- newest, best quality, slightly larger

**Complexity:** Low (change 3 constants, switch embed function to use Ollama API)
**Expected gain:** 10-15% retrieval quality improvement (MiniLM->nomic ~6 MTEB points)
**VRAM cost:** ~270MB-500MB (minimal)
**Recommendation:** HIGH PRIORITY -- easy win, big quality improvement

### 3.3 Implementation Change

Replace sentence-transformers _embed() with Ollama API call:
- ollama.embed(model=MODEL_NAME, input=text) returns embeddings
- Ollama API may support batching via input=[list]
- struct.pack the float list to bytes for sqlite-vec

---

## 4. Prompt Engineering Improvements

### 4.1 Current System Prompt Analysis

Current prompt (from ask.py) is basic: "Answer using ONLY provided sources, cite with [N], say if insufficient."

**Issues:**
1. No explicit instruction about hallucination avoidance
2. No structured output guidance
3. No few-shot examples of good answers
4. No instruction to distinguish between direct quotes and inferences

### 4.2 Improved System Prompt

Key additions needed:
- Explicit anti-hallucination rules: "Never invent task IDs, file paths, command flags"
- Distinction between direct info, inference, and gaps
- Guidance for different query types (how-to vs why vs what)
- "I don't know" protocol with topic suggestions from available sources
- Multiple-citation format: [1][3] for multi-source claims

**Complexity:** Very Low (replace one string constant)
**Expected gain:** 15-25% reduction in hallucinations, better citation accuracy
**Recommendation:** HIGH PRIORITY -- zero cost, immediate improvement

### 4.3 Context Formatting Improvements

Use clear delimiters between sources:
- "--- SOURCE [1] ---" markers
- Separate metadata (Title, Type, Path) from content
- Helps LLM identify source boundaries and cite accurately

---

## 5. Answer Quality Improvements

### 5.1 Self-Consistency (Multi-Sample)

Generate 2-3 answers independently, select the most consistent one.
**Recommendation:** LOW PRIORITY -- 3x latency too expensive for interactive use

### 5.2 Chain-of-Verification (CoVe)

After generating an answer, ask the LLM to verify each claim against the sources.
**Complexity:** Medium (~40 lines, 2x latency)
**Expected gain:** 15-30% reduction in hallucinated claims
**Recommendation:** MEDIUM PRIORITY -- could be optional "verify" button

### 5.3 Citation Grounding Check

Post-process the answer to verify each [N] citation actually supports the claim.
Lightweight approach: parse [N] references, check key term overlap with cited source.
**Complexity:** Low-Medium (~40 lines, no extra LLM call)
**Recommendation:** MEDIUM PRIORITY

---

## 6. Caching and Performance

### 6.1 Query Result Caching

**Current:** No caching. Every search rebuilds if index >120s stale.

**Improvement:** LRU cache at embedding level (query text -> embedding bytes).

**Complexity:** Very Low
**Expected gain:** 50-80% latency reduction on repeated/similar queries
**Recommendation:** HIGH PRIORITY -- trivial to implement

### 6.2 Incremental Indexing

**Current:** Full rebuild every 120 seconds (all files re-embedded).

**Improvement:**
- Store file modification timestamps in the DB
- On rebuild: only re-embed files that changed since last build
- Use os.path.getmtime() comparison

**Complexity:** Medium (schema change, partial rebuild logic)
**Expected gain:** 80-95% reduction in rebuild time (typically only 1-5 files change)
**Recommendation:** HIGH PRIORITY -- especially as knowledge base grows

### 6.3 Persistent Index

**Current:** Index in /tmp/ -- lost on reboot.
**Improvement:** Store in .context/cache/vec-index.db (persistent, gitignored).
**Complexity:** Very Low (change DB_PATH)
**Expected gain:** Eliminates cold-start rebuild (~5-30 seconds)
**Recommendation:** MEDIUM PRIORITY

---

## 7. Priority-Ranked Implementation Roadmap

### Tier 1: Quick Wins (1-2 hours each, high impact)

| # | Technique | Effort | Quality Gain | VRAM Cost |
|---|-----------|--------|-------------|-----------|
| 1 | **Improved system prompt** | 15 min | 15-25% fewer hallucinations | 0 |
| 2 | **Upgrade embedding model** (MiniLM -> nomic-embed-text) | 1 hour | 10-15% retrieval quality | +270MB |
| 3 | **Query result caching** | 30 min | 50-80% latency reduction | 0 |
| 4 | **Chunk overlap** | 30 min | 5-10% at boundaries | 0 |

### Tier 2: Moderate Investment (2-4 hours each, significant impact)

| # | Technique | Effort | Quality Gain | VRAM Cost |
|---|-----------|--------|-------------|-----------|
| 5 | **Cross-encoder reranking** (Qwen3-Reranker 0.6B) | 3 hours | 15-30% precision | +500MB |
| 6 | **Incremental indexing** | 3 hours | 80-95% faster rebuilds | 0 |
| 7 | **Category-aware chunk sizes** | 2 hours | 5-15% relevance | 0 |
| 8 | **YAML-aware task chunking** | 2 hours | 10-15% for task queries | 0 |

### Tier 3: Advanced (4-8 hours each, specialized gains)

| # | Technique | Effort | Quality Gain | VRAM Cost |
|---|-----------|--------|-------------|-----------|
| 9 | **Query expansion (multi-query)** | 4 hours | 20-40% recall | 0 |
| 10 | **HyDE** | 3 hours | 10-25% vector recall | 0 |
| 11 | **Chain-of-Verification** | 4 hours | 15-30% fewer hallucinations | 0 |
| 12 | **Parent-child retrieval** | 6 hours | 10-20% completeness | 0 |
| 13 | **Citation grounding check** | 3 hours | Better citation accuracy | 0 |

### Tier 4: Defer / Evaluate Later

| # | Technique | Reason to defer |
|---|-----------|----------------|
| 14 | Semantic chunking | Rule-based chunking gets 80% of benefit |
| 15 | Self-consistency (multi-sample) | 3x latency too expensive for interactive |
| 16 | Fine-tuning embedding model | Insufficient training data, complex setup |

---

## 8. VRAM Budget Analysis (16GB Total)

| Component | VRAM Usage |
|---|---|
| LLM (qwen2.5-coder-32b IQ2_M) | ~10-12GB |
| Embedding model (nomic-embed-text) | ~270MB |
| Reranker (Qwen3-Reranker 0.6B Q4) | ~500MB |
| System/overhead | ~1-2GB |
| **Total** | **~12-15GB** |

This fits within 16GB VRAM. The reranker can be loaded on-demand and unloaded after use if memory is tight.

---

## 9. Key Observations About Current Implementation

1. **Embedding model is the weakest link.** all-MiniLM-L6-v2 (384-dim, 2022) is significantly outperformed by modern models. Switching to nomic-embed-text is the single highest-ROI change.

2. **The system uses sentence-transformers, not Ollama, for embeddings.** This creates a split infrastructure (Ollama for LLM, sentence-transformers for embeddings). Unifying on Ollama simplifies deployment and enables GPU-accelerated embedding.

3. **No deduplication at chunk boundary.** Adjacent chunks from the same document can both appear in results, wasting context slots. The current seen_paths dedup helps but only keeps one chunk per file -- sometimes the SECOND chunk is better.

4. **RRF k=60 is standard.** No issue here; this is the recommended constant from the original RRF paper.

5. **10 chunks to LLM is reasonable.** With ~375 tokens per chunk, that's ~3750 tokens of context. Modern LLMs can handle 8K-128K, so there's room to increase to 15-20 chunks if retrieval quality improves.

6. **Index rebuild is expensive.** Full re-embedding on every stale check is wasteful. Incremental indexing would make the 120-second staleness threshold viable without performance concerns.

---

## Sources

- [Qwen3 Embedding and Reranker on Ollama](https://www.glukhov.org/post/2025/06/qwen3-embedding-qwen3-reranker-on-ollama/)
- [Ultimate Guide to Reranking Models 2026](https://www.zeroentropy.dev/articles/ultimate-guide-to-choosing-the-best-reranking-model-in-2025)
- [Best Chunking Strategies for RAG 2025](https://www.firecrawl.dev/blog/best-chunking-strategies-rag-2025)
- [Document Chunking: 9 Strategies Tested](https://langcopilot.com/posts/2025-10-11-document-chunking-for-rag-practical-guide)
- [HyDE: Hypothetical Document Embeddings](https://zilliz.com/learn/improve-rag-and-information-retrieval-with-hyde-hypothetical-document-embeddings)
- [Improving LLM Reliability: CoT, RAG, Self-Consistency](https://arxiv.org/abs/2505.09031)
- [Chain-of-Verification for RAG](https://arxiv.org/abs/2410.05801)
- [Ollama Embedded Models Guide 2025](https://collabnix.com/ollama-embedded-models-the-complete-technical-guide-to-local-ai-embeddings-in-2025/)
- [RAG Comprehensive Survey 2025](https://arxiv.org/html/2506.00054v1)
- [Parent-Child Retrieval in Dify](https://dify.ai/blog/introducing-parent-child-retrieval-for-enhanced-knowledge)
- [Advanced RAG: Query Expansion (Haystack)](https://haystack.deepset.ai/blog/query-expansion)
- [Building RAG on SQLite](https://blog.sqlite.ai/building-a-rag-on-sqlite)
