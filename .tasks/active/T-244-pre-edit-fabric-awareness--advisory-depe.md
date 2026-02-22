---
id: T-244
name: "Pre-edit fabric awareness — advisory dependency check on Write/Edit"
description: >
  Add lightweight PreToolUse advisory check: when agent edits a source file, look up the file in .fabric/components/ and inject dependency count + key dependents into context. Not blocking — just awareness. T-235 Gap #1: 'Fabric invisible to working agents — no agent checks deps before modifying files.' CLAUDE.md says 'Before modifying a file: fw fabric deps <path>' but this is guidance only. Research: docs/reports/T-235-agent-fabric-awareness-vector-db.md §Topic 1 Gap 1. Related: T-236 (blast-radius in post-commit — done), T-224 (component auto-populate on completion — done). This closes the pre-edit gap. Example: agent edits bin/fw (15 dependents) and sees 'NOTE: bin/fw has 15 downstream dependents — consider fw fabric blast-radius after commit.'

status: started-work
workflow_type: build
owner: agent
horizon: later
tags: [fabric, enforcement, awareness]
components: []
related_tasks: []
created: 2026-02-22T09:29:28Z
last_update: 2026-02-22T15:00:57Z
date_finished: null
---

# T-244: Pre-edit fabric awareness — advisory dependency check on Write/Edit

## Context

Closes T-235 Gap #1: "Fabric invisible to working agents." Added advisory to existing `check-active-task.sh` PreToolUse hook. When editing a registered component with dependents, prints: `FABRIC: path has N downstream dependent(s). Consider: fw fabric blast-radius after commit.`

## Acceptance Criteria

### Agent
- [x] Fabric advisory added to `check-active-task.sh` (not a separate hook)
- [x] Shows dependent count for registered files with >0 dependents
- [x] Silent for unregistered files (no noise)
- [x] Silent for exempt paths (.context/, .tasks/, .claude/)
- [x] Advisory only — exit code remains 0 (never blocks)
- [x] Hook latency under 200ms with advisory

## Verification

# Advisory present in check-active-task.sh
grep -q "FABRIC:" agents/context/check-active-task.sh
grep -q "blast-radius" agents/context/check-active-task.sh
# Hook still exits 0 for normal files
echo '{"tool_name":"Edit","tool_input":{"file_path":"/opt/999-Agentic-Engineering-Framework/bin/fw"}}' | agents/context/check-active-task.sh >/dev/null 2>&1

## Updates

### 2026-02-22T09:29:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-244-pre-edit-fabric-awareness--advisory-depe.md
- **Context:** Initial task creation

### 2026-02-22T15:00:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
