---
id: T-499
name: "fw update for vendored projects — pull upstream into .agentic-framework/"
description: >
  Create/update fw update command to: fetch latest framework from upstream repo (GitHub/OneDev), diff against local .agentic-framework/, report changes (dry-run), apply update (overwrite plain copy), preserve VERSION file. Human-initiated only, agent can suggest. From T-482 GO.

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: [portability, isolation]
components: [bin/fw]
related_tasks: []
created: 2026-03-15T14:01:20Z
last_update: 2026-03-15T20:52:05Z
date_finished: 2026-03-15T20:52:05Z
---

# T-499: fw update for vendored projects — pull upstream into .agentic-framework/

## Context

Adapt `fw update` for vendored projects. When `.agentic-framework/` exists, clone upstream into temp dir, re-vendor from there. Uses `upstream_repo` from `.framework.yaml`. From T-482 GO (full isolation).

## Acceptance Criteria

### Agent
- [x] `fw update` in vendored project clones upstream, shows version diff, re-vendors
- [x] `fw update --check` shows available update without applying
- [x] `fw update --rollback` restores previous vendored version
- [x] Upstream URL auto-detected from `.framework.yaml` `upstream_repo` field
- [x] Falls back to existing git-based update when no `.agentic-framework/` present
- [x] Temp clone cleaned up on success and failure (trap)
- [x] `fw help` shows updated update command description

### Human
- [ ] [RUBBER-STAMP] Run `fw update --check` in a test vendored project and verify output
  **Steps:**
  1. Create a temp project: `fw init /tmp/test-update-499`
  2. Run `cd /tmp/test-update-499 && .agentic-framework/bin/fw update --check`
  **Expected:** Shows current version, checks upstream, reports if up to date or behind
  **If not:** Check `.framework.yaml` for `upstream_repo` field

## Verification

grep -q "vendored" lib/update.sh
grep -q "upstream_repo" lib/update.sh
grep -q "rollback" lib/update.sh

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

### 2026-03-15T14:01:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-499-fw-update-for-vendored-projects--pull-up.md
- **Context:** Initial task creation

### 2026-03-15T20:48:04Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-15T20:52:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
