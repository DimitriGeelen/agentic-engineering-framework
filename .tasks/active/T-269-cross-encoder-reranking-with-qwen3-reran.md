---
id: T-269
name: "Cross-encoder reranking with Qwen3-Reranker"
description: >
  Add cross-encoder reranking stage to RAG pipeline. After initial hybrid retrieval (BM25+vector, top-30), rerank with Qwen3-Reranker 0.6B (Q4, ~0.5GB VRAM) and return top-10. Ollama now has native rerank endpoint — use ollama.rerank() or the API equivalent. Add ~30 lines to web/embeddings.py rag_retrieve(). On-demand loading: load reranker only during rerank, unload if VRAM pressure. Ref: docs/reports/T-261-rag-quality-techniques.md §1.1 (cross-encoder models, implementation approach). Prerequisite: ollama pull qwen3-reranker:0.6b. Predecessor: T-255 (RAG retrieval).

status: captured
workflow_type: build
owner: agent
horizon: next
tags: [qa, rag, reranking]
components: []
related_tasks: []
created: 2026-02-24T08:38:02Z
last_update: 2026-02-24T08:38:02Z
date_finished: null
---

# T-269: Cross-encoder reranking with Qwen3-Reranker

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
<!-- Criteria the agent can verify (code, tests, commands). P-010 gates on these. -->
- [ ] [First criterion]
- [ ] [Second criterion]

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking. -->
<!-- Remove this section if all criteria are agent-verifiable. -->

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-02-24T08:38:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-269-cross-encoder-reranking-with-qwen3-reran.md
- **Context:** Initial task creation
