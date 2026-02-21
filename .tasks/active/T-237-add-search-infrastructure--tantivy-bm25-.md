---
id: T-237
name: "Add search infrastructure — tantivy BM25 for Watchtower, plan embedding layer"
description: >
  Replace grep-based search in Watchtower with tantivy BM25 full-text search. Phase 1: pip install tantivy, index all YAML/Markdown files, wire into /search route. Phase 2 (future): Add sqlite-vec for embedding-based similarity when find-similar use case becomes real need. Phase 3 (future): Consider Qdrant MCP server for agent-queryable knowledge. Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md, /tmp/fw-agent-vector-db-options.md, /tmp/fw-agent-vector-db-research.md

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-02-21T21:48:32Z
last_update: 2026-02-21T21:48:32Z
date_finished: null
---

# T-237: Add search infrastructure — tantivy BM25 for Watchtower, plan embedding layer

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

### 2026-02-21T21:48:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-237-add-search-infrastructure--tantivy-bm25-.md
- **Context:** Initial task creation
