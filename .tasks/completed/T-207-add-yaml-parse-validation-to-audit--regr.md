---
id: T-207
name: "Add YAML parse validation to audit — regression test for all project YAML files"
description: >
  Add YAML parse validation to audit — regression test for all project YAML files

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-19T22:59:03Z
last_update: 2026-02-19T23:01:50Z
date_finished: 2026-02-19T23:01:50Z
---

# T-207: Add YAML parse validation to audit — regression test for all project YAML files

## Context

T-206 fix revealed: learnings.yaml was broken for unknown time, Watchtower showed 0 entries silently. Root cause: no regression test validates project YAML files parse. L-047 and L-045 both called for this — now implementing structural enforcement.

## Acceptance Criteria

### Agent
- [x] Audit structure section validates all .context/project/*.yaml files parse with yaml.safe_load
- [x] Broken YAML produces FAIL (not WARN) — data loss is not a warning
- [x] Valid YAML produces single PASS with count
- [x] CTL-027 registered in controls.yaml

## Verification

# Audit structure section runs clean
bash -c 'fw audit --section structure 2>&1 | grep -c "project YAML files parse correctly" > /dev/null'
# CTL-027 registered
grep -q "CTL-027" .context/project/controls.yaml

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

### 2026-02-19T22:59:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-207-add-yaml-parse-validation-to-audit--regr.md
- **Context:** Initial task creation

### 2026-02-19T23:01:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
