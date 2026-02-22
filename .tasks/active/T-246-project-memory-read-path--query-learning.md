---
id: T-246
name: "Project memory read-path — query learnings/patterns/decisions at task start"
description: >
  When fw context focus T-XXX is set or a new task is created, query project memory (learnings.yaml, patterns.yaml, decisions.yaml) for relevant prior knowledge and inject a 2-3 line summary into working memory. Currently the context fabric scores 7/10 on write-path but 2/10 on read-path — the framework captures knowledge it doesn't use. 58 learnings, 14 patterns, 30+ decisions accumulated but never consulted when starting new work. Depends on: T-245 (sqlite-vec) for semantic matching, or can start with BM25 keyword matching via Tantivy (T-237). Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md §Topic 1 Gap 2. Also: /tmp/fw-agent-fabric-status.md §3.2 'Project Memory Not Consulted'. Related: T-241 (discovery surfacing at session-start — done, pattern to follow).

status: started-work
workflow_type: build
owner: agent
horizon: later
tags: [context-fabric, knowledge, read-path]
components: []
related_tasks: []
created: 2026-02-22T09:29:49Z
last_update: 2026-02-22T15:33:54Z
date_finished: null
---

# T-246: Project memory read-path — query learnings/patterns/decisions at task start

## Context

Closes the read-path gap: framework captures knowledge (7/10) but never consults it (2/10). When `fw context focus` sets a task, query project memory for relevant prior learnings, patterns, and decisions. Uses T-245 hybrid search (BM25 + semantic). Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md §Topic 1 Gap 2.

## Acceptance Criteria

### Agent
- [ ] `agents/context/lib/memory-recall.py` queries learnings, patterns, decisions by task context
- [ ] `fw context focus T-XXX` prints relevant prior knowledge after setting focus
- [ ] `fw recall "query"` standalone CLI command returns relevant knowledge
- [ ] Output is concise (max 5 items, 1 line each) with source references
- [ ] Graceful degradation: works without sqlite-vec index (falls back to keyword)

## Verification

# memory-recall.py exists and is executable
test -f agents/context/lib/memory-recall.py
# fw recall command exists
grep -q "recall" bin/fw
# Recall returns output for a known term
python3 agents/context/lib/memory-recall.py --query "audit enforcement" 2>/dev/null | grep -q "L-\|P-\|D-"

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

### 2026-02-22T09:29:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-246-project-memory-read-path--query-learning.md
- **Context:** Initial task creation

### 2026-02-22T15:33:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
