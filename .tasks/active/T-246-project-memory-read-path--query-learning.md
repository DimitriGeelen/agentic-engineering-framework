---
id: T-246
name: "Project memory read-path — query learnings/patterns/decisions at task start"
description: >
  When fw context focus T-XXX is set or a new task is created, query project memory (learnings.yaml, patterns.yaml, decisions.yaml) for relevant prior knowledge and inject a 2-3 line summary into working memory. Currently the context fabric scores 7/10 on write-path but 2/10 on read-path — the framework captures knowledge it doesn't use. 58 learnings, 14 patterns, 30+ decisions accumulated but never consulted when starting new work. Depends on: T-245 (sqlite-vec) for semantic matching, or can start with BM25 keyword matching via Tantivy (T-237). Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md §Topic 1 Gap 2. Also: /tmp/fw-agent-fabric-status.md §3.2 'Project Memory Not Consulted'. Related: T-241 (discovery surfacing at session-start — done, pattern to follow).

status: captured
workflow_type: build
owner: agent
horizon: later
tags: [context-fabric, knowledge, read-path]
components: []
related_tasks: []
created: 2026-02-22T09:29:49Z
last_update: 2026-02-22T09:29:49Z
date_finished: null
---

# T-246: Project memory read-path — query learnings/patterns/decisions at task start

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

### 2026-02-22T09:29:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-246-project-memory-read-path--query-learning.md
- **Context:** Initial task creation
