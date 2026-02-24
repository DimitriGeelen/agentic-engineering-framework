---
id: T-263
name: "RAG quick wins — prompt, embeddings, chunking"
description: >
  Four stacking improvements to RAG quality: (1) Improve system prompt with anti-hallucination rules, structured citation format, 'I don't know' protocol — 15min, 15-25% fewer hallucinations (RQ-2 §4.2). (2) Upgrade embedding model from all-MiniLM-L6-v2 (384-dim, MTEB 56.3) to nomic-embed-text (768-dim, MTEB 62.4) via Ollama API — 1hr, 10-15% retrieval improvement (RQ-2 §3.2). (3) Add 150-200 char chunk overlap — 30min, 5-10% boundary fix (RQ-2 §2.2A). (4) Add query embedding cache (LRU) — 30min, 50-80% latency reduction (RQ-2 §6.1). Files: web/ask.py (prompt), web/embeddings.py (embed model + chunking + cache). Ref: docs/reports/T-261-rag-quality-techniques.md §1-§6. Predecessor: T-255 (RAG retrieval).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: [qa, rag, embeddings]
components: []
related_tasks: []
created: 2026-02-24T08:36:46Z
last_update: 2026-02-24T08:58:05Z
date_finished: null
---

# T-263: RAG quick wins — prompt, embeddings, chunking

## Context

Four stacking RAG quality improvements. Ref: [T-261-rag-quality-techniques.md](../../docs/reports/T-261-rag-quality-techniques.md)

## Acceptance Criteria

### Agent
- [x] System prompt includes anti-hallucination rules, "I don't know" protocol, and structured citation guidance
- [x] Embedding model switched from sentence-transformers all-MiniLM-L6-v2 to Ollama nomic-embed-text-v2-moe (768-dim)
- [x] Chunk overlap of 150-200 chars added to _chunk_content()
- [x] Query embedding cache (LRU) reduces repeated query latency
- [x] EMBEDDING_DIM updated to 768
- [x] sentence-transformers import removed (Ollama handles embeddings)

### Human
- [ ] Q&A answer quality improved (fewer hallucinations, better citations)

## Verification

# System prompt has anti-hallucination rules
grep -q "Never invent" web/ask.py
# Embedding model switched to Ollama
grep -q "nomic-embed-text" web/embeddings.py
# Embedding dimension is 768
grep -q "EMBEDDING_DIM = 768" web/embeddings.py
# Chunk overlap implemented
grep -q "overlap" web/embeddings.py
# sentence-transformers no longer imported
grep -c "sentence_transformers" web/embeddings.py | grep -q "^0$"
# Server still loads
python3 -c "from web.ask import SYSTEM_PROMPT; print('OK')"
python3 -c "from web.embeddings import EMBEDDING_DIM; assert EMBEDDING_DIM == 768"

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-02-24T08:36:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-263-rag-quick-wins--prompt-embeddings-chunki.md
- **Context:** Initial task creation

### 2026-02-24T08:58:05Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
