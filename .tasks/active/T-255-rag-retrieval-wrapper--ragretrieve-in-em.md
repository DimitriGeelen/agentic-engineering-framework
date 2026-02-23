---
id: T-255
name: "RAG retrieval wrapper — rag_retrieve() in embeddings.py"
description: >
  Add rag_retrieve() wrapper to web/embeddings.py that extends hybrid_search() with: full chunk_text return, category filtering, score thresholding (>0.4), path deduplication. ~30-50 lines. See docs/reports/T-254-llm-assisted-qa-research.md RQ-2 section. Predecessor: T-254 (inception GO). Related: T-245 (semantic search).

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: [T-254]
created: 2026-02-23T20:38:08Z
last_update: 2026-02-23T20:38:08Z
date_finished: null
---

# T-255: RAG retrieval wrapper — rag_retrieve() in embeddings.py

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

### 2026-02-23T20:38:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-255-rag-retrieval-wrapper--ragretrieve-in-em.md
- **Context:** Initial task creation
