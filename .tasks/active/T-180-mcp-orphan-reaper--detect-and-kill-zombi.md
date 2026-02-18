---
id: T-180
name: "MCP orphan reaper — detect and kill zombie MCP processes"
description: >
  When Claude Code sessions crash or end, MCP server processes (playwright-mcp, context7-mcp) become orphaned (PPID=1), accumulating ~50-80MB each. Evidence: 12 orphans found consuming ~600MB (sprechloop session 2026-02-18). Research complete: docs/reports/experiment-zombie-mcp-orphan-reaper.md covers detection (PGID-leader-alive check), cleanup approaches, safety, implementation sketch. Source brief: /opt/001-sprechloop/.context/briefs/framework-zombie-mcp-cleanup.md. Deliverables: (1) reap script in framework repo, (2) fw doctor warns about orphans, (3) crontab integration via fw init.

status: captured
workflow_type: build
owner: claude-code
horizon: later
tags: []
related_tasks: []
created: 2026-02-18T20:06:33Z
last_update: 2026-02-18T20:06:33Z
date_finished: null
---

# T-180: MCP orphan reaper — detect and kill zombie MCP processes

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

- [ ] [First criterion]
- [ ] [Second criterion]

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

### 2026-02-18T20:06:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-180-mcp-orphan-reaper--detect-and-kill-zombi.md
- **Context:** Initial task creation
