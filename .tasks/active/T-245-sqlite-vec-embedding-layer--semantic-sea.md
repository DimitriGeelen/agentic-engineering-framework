---
id: T-245
name: "sqlite-vec embedding layer — semantic search for project knowledge"
description: >
  Add sqlite-vec vector database for semantic/associative search across episodic memory (241 files), learnings (58), patterns (14), decisions (30+), and component cards (99). T-235 research found BM25 (Tantivy, T-237) covers 60-70% of queries; embeddings add 30-40% value for 'find similar' and 'what is related' queries. Root cause: terminology fragmentation — 'audit'/'gate'/'enforcement'/'verification' all mean similar things, causing 30-40% miss rate on keyword search. Recommended: sqlite-vec (~22MB model) paired with existing Tantivy for hybrid search. Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md §Topic 2. Related: T-237 (Tantivy BM25 — done, live at :3000/search). This is the foundation for project memory read-path (T-245) and episodic search.

status: work-completed
workflow_type: build
owner: human
horizon: later
tags: [search, embeddings, knowledge]
components: [bin/fw, C-003, web/embeddings.py, web/templates/search.html]
related_tasks: []
created: 2026-02-22T09:29:37Z
last_update: 2026-02-22T19:10:56Z
date_finished: 2026-02-22T15:33:04Z
---

# T-245: sqlite-vec embedding layer — semantic search for project knowledge

## Context

Adds sqlite-vec semantic search alongside existing Tantivy BM25 (T-237). Model: all-MiniLM-L6-v2 (384-dim, ~22MB). Addresses terminology fragmentation (30-40% miss rate on keyword search). Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md §Topic 2.

## Acceptance Criteria

### Agent
- [x] `web/embeddings.py` module: index, search, hybrid_search functions
- [x] Indexes episodic, learnings, patterns, decisions, component cards (~710 files)
- [x] Semantic search returns ranked results with scores and snippets
- [x] Hybrid search combines BM25 + vector scores (RRF fusion)
- [x] CLI: `fw search --semantic "query"` returns results
- [x] Watchtower /search page has semantic search toggle
- [x] Index builds in <30 seconds on full corpus

### Human
- [ ] Semantic search finds related content that keyword search misses

## Verification

# Module imports cleanly
python3 -c "from web.embeddings import build_index, search, hybrid_search"
# Index builds successfully
python3 -c "from web.embeddings import build_index; stats = build_index(); print(f'Indexed {stats[\"num_docs\"]} docs')"
# Semantic search returns results
python3 -c "from web.embeddings import search; r = search('audit gate enforcement'); assert len(r['results']) > 0, 'no results'"
# fw search command exists
grep -q "search" bin/fw

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

### 2026-02-22T15:24:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-22T15:33:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
