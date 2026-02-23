---
id: T-255
name: "RAG retrieval wrapper — rag_retrieve() in embeddings.py"
description: >
  Add rag_retrieve() wrapper to web/embeddings.py that extends hybrid_search() with: full chunk_text return, category filtering, score thresholding (>0.4), path deduplication. ~30-50 lines. See docs/reports/T-254-llm-assisted-qa-research.md RQ-2 section. Predecessor: T-254 (inception GO). Related: T-245 (semantic search).

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-254]
created: 2026-02-23T20:38:08Z
last_update: 2026-02-23T20:50:40Z
date_finished: 2026-02-23T20:50:40Z
---

# T-255: RAG retrieval wrapper — rag_retrieve() in embeddings.py

## Context

Extends T-245 semantic search for RAG pipeline. See `docs/reports/T-254-llm-assisted-qa-research.md` RQ-2.

## Acceptance Criteria

### Agent
- [x] `rag_retrieve(query, limit=10)` function exists in `web/embeddings.py`
- [x] Returns list of dicts with: path, title, category, task_id, score, chunk_text
- [x] Uses hybrid_search internally for RRF fusion quality
- [x] Returns full chunk_text (not truncated snippets)
- [x] Deduplicates by path (best chunk per file)
- [x] Python import works: `from web.embeddings import rag_retrieve`

## Verification

python3 -c "from web.embeddings import rag_retrieve; r = rag_retrieve('error handling'); assert len(r) > 0; assert 'chunk_text' in r[0]; assert len(r[0]['chunk_text']) > 200; print(f'OK: {len(r)} chunks, first has {len(r[0][\"chunk_text\"])} chars')"

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

### 2026-02-23T20:38:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-255-rag-retrieval-wrapper--ragretrieve-in-em.md
- **Context:** Initial task creation

### 2026-02-23T20:50:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
