---
id: T-775
name: "fw pickup send — consumer-side CLI for local and TermLink push"
description: >
  Consumer-side CLI command: serialize pickup envelope YAML, write to local inbox or push via termlink remote push. Supports --type, --summary, --detail, --priority, --remote flags.

status: work-completed
workflow_type: build
owner: claude-code
horizon: null
tags: []
components: []
related_tasks: [T-772, T-774]
created: 2026-03-30T13:21:40Z
last_update: 2026-03-30T14:11:45Z
date_finished: 2026-03-30T14:11:45Z
---

# T-775: fw pickup send — consumer-side CLI for local and TermLink push

## Context

Consumer-side CLI for the pickup pipeline (T-772 GO). Depends on T-774 (lib/pickup.sh). Design: `docs/reports/T-772-cross-project-pickup.md`

## Acceptance Criteria

### Agent
- [x] `fw pickup send` subcommand registered in `bin/fw`
- [x] Accepts flags: `--type`, `--summary`, `--detail`, `--priority`, `--source-project`, `--task-id`, `--tags`
- [x] Local mode: writes YAML envelope to `.context/pickup/inbox/P-NNN-type.yaml`
- [x] `--remote` flag: pushes via `termlink remote push` (requires TermLink)
- [x] Auto-generates pickup_id (P-NNN) and dedup_hash
- [x] Validates required fields before writing
- [x] `fw pickup send --help` shows usage — 9 new send tests, 37 total

## Verification

cd /opt/999-Agentic-Engineering-Framework && bin/fw pickup send --help

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

### 2026-03-30T13:21:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-775-fw-pickup-send--consumer-side-cli-for-lo.md
- **Context:** Initial task creation

### 2026-03-30T14:08:15Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-30T14:11:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
