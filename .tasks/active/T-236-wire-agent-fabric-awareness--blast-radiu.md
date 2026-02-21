---
id: T-236
name: "Wire agent fabric awareness — blast-radius in git hooks, auto-capture learnings on completion"
description: >
  Wire Component Fabric and Context Fabric into agent workflows. Priority 1: Add blast-radius check to git commit flow (warn when modifying files with many dependents). Priority 2: Auto-extract decisions/patterns from task file on work-completed. Priority 3: Update CLAUDE.md Working with Tasks section to include fabric/context checks. Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md, /tmp/fw-agent-fabric-awareness.md

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-02-21T21:48:24Z
last_update: 2026-02-21T22:06:26Z
date_finished: null
---

# T-236: Wire agent fabric awareness — blast-radius in git hooks, auto-capture learnings on completion

## Context

Research in T-235 found agent fabric awareness is 5/10 — Component Fabric 20% integrated, Context Fabric 60%. This task wires both into core workflows. See `docs/reports/T-235-agent-fabric-awareness-vector-db.md`.

## Acceptance Criteria

### Agent
- [ ] Post-commit hook shows blast-radius summary when registered components are modified
- [ ] `update-task.sh` work-completed flow auto-extracts decisions from task Decisions section
- [ ] CLAUDE.md "When completing" section includes fabric/context check guidance
- [ ] Existing hooks/scripts still pass (`fw doctor`)

## Verification

# Post-commit hook has blast-radius check
grep -q "blast.radius\|fabric" .git/hooks/post-commit
# Update-task.sh has decision extraction
grep -q "add-decision\|Decisions" agents/task-create/update-task.sh
# CLAUDE.md has fabric guidance in completing section
grep -q "fabric" CLAUDE.md
# Framework health
fw doctor

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

### 2026-02-21T21:48:24Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-236-wire-agent-fabric-awareness--blast-radiu.md
- **Context:** Initial task creation

### 2026-02-21T22:06:26Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
