---
id: T-263
name: "RAG quick wins — prompt, embeddings, chunking"
description: >
  Four stacking improvements to RAG quality: (1) Improve system prompt with anti-hallucination
  rules, structured citation format, 'I don't know' protocol — 15min, 15-25% fewer
  hallucinations (RQ-2 §4.2). (2) Upgrade embedding model from all-MiniLM-L6-v2 (384-dim,
  MTEB 56.3) to nomic-embed-text (768-dim, MTEB 62.4) via Ollama API — 1hr, 10-15%
  retrieval improvement (RQ-2 §3.2). (3) Add 150-200 char chunk overlap — 30min, 5-10%
  boundary fix (RQ-2 §2.2A). (4) Add query embedding cache (LRU) — 30min, 50-80% latency
  reduction (RQ-2 §6.1). Files: web/ask.py (prompt), web/embeddings.py (embed model
  + chunking + cache). Ref: docs/reports/T-261-rag-quality-techniques.md §1-§6. Predecessor:
  T-255 (RAG retrieval).

status: work-completed
workflow_type: build
owner: human
horizon:
tags: [qa, rag, embeddings]
components: [web/embeddings.py]
related_tasks: []
created: 2026-02-24T08:36:46Z
last_update: '2026-08-16T22:25:12Z'
date_finished: 2026-02-24T09:20:13Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 1
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=1 (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:12Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 1
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=1 (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
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
- [x] Q&A answer quality improved (fewer hallucinations, better citations)

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
python3 -c "assert 'sentence_transformers' not in open('web/embeddings.py').read(); print('OK')"
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

### 2026-02-24T09:20:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c60c3036
- **Timestamp:** 2026-06-02T15:01:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
