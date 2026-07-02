---
id: T-269
name: "Cross-encoder reranking with Qwen3-Reranker"
description: >
  Add cross-encoder reranking stage to RAG pipeline. After initial hybrid retrieval
  (BM25+vector, top-30), rerank with Qwen3-Reranker 0.6B (Q4, ~0.5GB VRAM) and return
  top-10. Ollama now has native rerank endpoint — use ollama.rerank() or the API equivalent.
  Add ~30 lines to web/embeddings.py rag_retrieve(). On-demand loading: load reranker
  only during rerank, unload if VRAM pressure. Ref: docs/reports/T-261-rag-quality-techniques.md
  §1.1 (cross-encoder models, implementation approach). Prerequisite: ollama pull
  qwen3-reranker:0.6b. Predecessor: T-255 (RAG retrieval).

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [agents/context/lib/focus.sh, web/embeddings.py]
related_tasks: []
created: 2026-02-24T08:38:02Z
last_update: '2026-06-11T22:24:17Z'
date_finished: 2026-02-24T10:54:23Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:17Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 1
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=1 
      (body/components:prompt-incidental); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-269: Cross-encoder reranking with Qwen3-Reranker

## Context

Cross-encoder reranking stage for RAG pipeline. Ref: T-261 research §1.1. Reranker model not currently available in Ollama registry — infrastructure ready with graceful fallback.

## Acceptance Criteria

### Agent
- [x] rerank() function in embeddings.py with cross-encoder scoring
- [x] _rerank_available() checks if model is installed before attempting reranking
- [x] rag_retrieve() passes candidates through rerank() before returning
- [x] Graceful fallback to original order when reranker unavailable
- [x] RERANKER_MODEL config constant defined
- [x] Qwen3-Reranker prompt format (Instruct/Query/Document) implemented

### Human
- [x] When reranker model is installed, verify answer quality improves

## Verification

# rerank function exists
grep -q "def rerank" web/embeddings.py
# _rerank_available function exists
grep -q "def _rerank_available" web/embeddings.py
# rag_retrieve calls rerank
grep -q "rerank(query" web/embeddings.py
# RERANKER_MODEL defined
grep -q "RERANKER_MODEL" web/embeddings.py
# Module still imports correctly
python3 -c "from web.embeddings import rerank, rag_retrieve; print('OK')"

## Decisions

### 2026-02-24 — Reranker model availability
- **Chose:** Build infrastructure with graceful fallback, ship without model
- **Why:** Qwen3-Reranker 0.6B not available in Ollama registry (tried qwen3-reranker:0.6b, dengcao/Qwen3-Reranker-0.6B, sam860/qwen3-reranker:0.6b — all fail). Code auto-activates when model becomes available.
- **Rejected:** Using Qwen3-14B as reranker (too slow: 14B model x30 calls), blocking on model availability

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-02-24T08:38:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-269-cross-encoder-reranking-with-qwen3-reran.md
- **Context:** Initial task creation

### 2026-02-24T10:46:11Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-24T10:54:23Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3dce7a08
- **Timestamp:** 2026-06-02T15:01:49Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
