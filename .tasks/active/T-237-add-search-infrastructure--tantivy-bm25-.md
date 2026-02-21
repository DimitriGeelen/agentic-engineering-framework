---
id: T-237
name: "Add search infrastructure — tantivy BM25 for Watchtower, plan embedding layer"
description: >
  Replace grep-based search in Watchtower with tantivy BM25 full-text search. Phase 1: pip install tantivy, index all YAML/Markdown files, wire into /search route. Phase 2 (future): Add sqlite-vec for embedding-based similarity when find-similar use case becomes real need. Phase 3 (future): Consider Qdrant MCP server for agent-queryable knowledge. Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md, /tmp/fw-agent-vector-db-options.md, /tmp/fw-agent-vector-db-research.md

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [C-003, web/search.py, web/templates/base.html, web/templates/search.html]
related_tasks: []
created: 2026-02-21T21:48:32Z
last_update: 2026-02-21T22:39:30Z
date_finished: 2026-02-21T22:39:30Z
---

# T-237: Add search infrastructure — tantivy BM25 for Watchtower, plan embedding layer

## Context

Replace grep-based search in Watchtower with tantivy BM25 full-text search. Research: `docs/reports/T-235-agent-fabric-awareness-vector-db.md`. Root problem: terminology fragmentation causes 30-40% search misses with grep.

## Acceptance Criteria

### Agent
- [x] `tantivy` Python package installed and importable
- [x] `web/search.py` module indexes all YAML/Markdown files (tasks, episodic, project memory, handovers, fabric, specs, reports, agent docs)
- [x] Search returns BM25-ranked results with snippet highlighting
- [x] `/search` route uses tantivy instead of grep subprocess
- [x] Search results categorized by content type (Active Tasks, Completed Tasks, Episodic Memory, etc.)
- [x] Existing tests pass (`pytest web/test_app.py`) — 140 passed
- [x] Index auto-rebuilds when stale (>60s)

### Human
- [ ] Search result quality and relevance at :3000/search

## Verification

# tantivy importable
python3 -c "import tantivy; print('tantivy OK')"
# search module importable
python3 -c "from web.search import search, index_stats; print(f'indexed: {index_stats()[\"num_docs\"]} docs')"
# search returns results
python3 -c "from web.search import search; r = search('antifragility'); assert r['total_hits'] > 0, 'no results'; print(f'{r[\"total_hits\"]} hits')"
# web route works
curl -sf http://localhost:3000/search?q=healing
# tests pass
pytest web/test_app.py -x -q

## Decisions

### 2026-02-21 — Index storage location
- **Chose:** `/tmp/fw-search-index/` (ephemeral, rebuilt on demand)
- **Why:** Index is cheap to rebuild (<1s for 831 docs), no need to persist across reboots
- **Rejected:** `.context/search-index/` (adds git noise), in-memory only (lost on restart)

## Updates

### 2026-02-21T21:48:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-237-add-search-infrastructure--tantivy-bm25-.md
- **Context:** Initial task creation

### 2026-02-21T22:29:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-21T22:39:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
