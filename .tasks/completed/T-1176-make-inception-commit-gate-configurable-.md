---
id: T-1176
name: "Make inception commit gate configurable — FW_INCEPTION_COMMIT_LIMIT (R-032)"
description: >
  Make inception commit gate configurable — FW_INCEPTION_COMMIT_LIMIT (R-032)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T17:18:39Z
last_update: 2026-04-12T17:23:08Z
date_finished: 2026-04-12T17:23:01Z
---

# T-1176: Make inception commit gate configurable — FW_INCEPTION_COMMIT_LIMIT (R-032)

## Context

R-032: Inception gate hardcoded to 2 commits. Deep explorations (5-10 sessions) force `--no-verify`. Make configurable via `FW_INCEPTION_COMMIT_LIMIT` with default 2 (backward compatible). Add to lib/config.sh 4-tier resolution.

## Acceptance Criteria

### Agent
- [x] `agents/git/lib/hooks.sh` reads `FW_INCEPTION_COMMIT_LIMIT` (default 2)
- [x] `lib/config.sh` includes the new setting in its registry
- [x] CLAUDE.md config table updated
- [x] Watchtower config page updated
- [x] Vendored copy synced

## Verification

# Inception gate reads configurable limit
grep -q "INCEPTION_COMMIT_LIMIT" agents/git/lib/hooks.sh
# lib/config.sh has the setting in registry
grep -q "INCEPTION_COMMIT_LIMIT" lib/config.sh
# CLAUDE.md documents the setting
grep -q "INCEPTION_COMMIT_LIMIT" CLAUDE.md

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

### 2026-04-12T17:18:39Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1176-make-inception-commit-gate-configurable-.md
- **Context:** Initial task creation

### 2026-04-12T17:23:01Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
