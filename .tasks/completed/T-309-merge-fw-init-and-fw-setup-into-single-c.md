---
id: T-309
name: "Merge fw init and fw setup into single command"
description: >
  DX comparison top finding: two entry points (fw init vs fw setup) confuses new users. Every other tool has ONE command. Auto-detect TTY for interactive vs non-interactive, --yes flag for defaults. Source: T-294 DX comparison finding.

status: work-completed
workflow_type: build
owner: agent
horizon: later
tags: []
components: [bin/fw]
related_tasks: [T-294]
created: 2026-03-04T17:28:40Z
last_update: 2026-03-04T21:59:08Z
date_finished: 2026-03-04T21:59:08Z
---

# T-309: Merge fw init and fw setup into single command

## Context

From T-294 DX comparison: two entry points confuse users. `fw init` already auto-detects TTY and has first-run walkthrough.

## Acceptance Criteria

### Agent
- [x] `fw setup` prints deprecation notice and delegates to `fw init`
- [x] `fw help` shows setup as deprecated alias
- [x] `fw init` help text updated to "auto-detects interactive mode"
- [x] `fw test-onboarding` still passes

## Verification

# setup delegates to init (grep source code to avoid SIGPIPE)
grep -q "deprecated" bin/fw
grep -q "Deprecated" bin/fw
fw test-onboarding 2>&1 | grep -q "ONBOARDING CLEAN"

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

### 2026-03-04T17:28:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-309-merge-fw-init-and-fw-setup-into-single-c.md
- **Context:** Initial task creation

### 2026-03-04T21:54:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T21:59:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
