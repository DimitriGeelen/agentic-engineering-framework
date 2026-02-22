---
id: T-245
name: "sqlite-vec embedding layer — semantic search for project knowledge"
description: >
  Add sqlite-vec vector database for semantic/associative search across episodic memory (241 files), learnings (58), patterns (14), decisions (30+), and component cards (99). T-235 research found BM25 (Tantivy, T-237) covers 60-70% of queries; embeddings add 30-40% value for 'find similar' and 'what is related' queries. Root cause: terminology fragmentation — 'audit'/'gate'/'enforcement'/'verification' all mean similar things, causing 30-40% miss rate on keyword search. Recommended: sqlite-vec (~22MB model) paired with existing Tantivy for hybrid search. Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md §Topic 2. Related: T-237 (Tantivy BM25 — done, live at :3000/search). This is the foundation for project memory read-path (T-245) and episodic search.

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [search, embeddings, knowledge]
components: []
related_tasks: []
created: 2026-02-22T09:29:37Z
last_update: 2026-02-22T09:29:37Z
date_finished: null
---

# T-245: sqlite-vec embedding layer — semantic search for project knowledge

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

### 2026-02-22T09:29:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-245-sqlite-vec-embedding-layer--semantic-sea.md
- **Context:** Initial task creation
