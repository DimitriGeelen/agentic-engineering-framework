---
id: T-263
name: "RAG quick wins — prompt, embeddings, chunking"
description: >
  Four stacking improvements to RAG quality: (1) Improve system prompt with anti-hallucination rules, structured citation format, 'I don't know' protocol — 15min, 15-25% fewer hallucinations (RQ-2 §4.2). (2) Upgrade embedding model from all-MiniLM-L6-v2 (384-dim, MTEB 56.3) to nomic-embed-text (768-dim, MTEB 62.4) via Ollama API — 1hr, 10-15% retrieval improvement (RQ-2 §3.2). (3) Add 150-200 char chunk overlap — 30min, 5-10% boundary fix (RQ-2 §2.2A). (4) Add query embedding cache (LRU) — 30min, 50-80% latency reduction (RQ-2 §6.1). Files: web/ask.py (prompt), web/embeddings.py (embed model + chunking + cache). Ref: docs/reports/T-261-rag-quality-techniques.md §1-§6. Predecessor: T-255 (RAG retrieval).

status: captured
workflow_type: build
owner: agent
horizon: now
tags: [qa, rag, embeddings]
components: []
related_tasks: []
created: 2026-02-24T08:36:46Z
last_update: 2026-02-24T08:36:46Z
date_finished: null
---

# T-263: RAG quick wins — prompt, embeddings, chunking

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

### 2026-02-24T08:36:46Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-263-rag-quick-wins--prompt-embeddings-chunki.md
- **Context:** Initial task creation
