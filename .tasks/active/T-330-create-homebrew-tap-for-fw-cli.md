---
id: T-330
name: "Create Homebrew Tap for fw CLI"
description: >
  Create homebrew-agentic-fw tap repo with Ruby formula pointing at release tarball. Enables: brew install DimitriGeelen/tap/fw. Requires v1.0.0 release tag first. Ref: docs/reports/T-327-visibility-strategy.md

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-05T01:12:33Z
last_update: 2026-03-05T01:34:13Z
date_finished: 2026-03-05T01:34:13Z
---

# T-330: Create Homebrew Tap for fw CLI

## Context

Homebrew tap for standard CLI distribution. Ref: `docs/reports/T-327-visibility-strategy.md`

## Acceptance Criteria

### Agent
- [x] GitHub repo DimitriGeelen/homebrew-agentic-fw created
- [x] Ruby formula (Formula/fw.rb) with correct SHA256 and tarball URL
- [x] README with install/usage/update/uninstall instructions

### Human
- [ ] `brew tap DimitriGeelen/agentic-fw && brew install fw` works on a macOS machine

## Verification

# Verify the tap repo exists on GitHub
gh repo view DimitriGeelen/homebrew-agentic-fw --json name -q .name

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

### 2026-03-05T01:12:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-330-create-homebrew-tap-for-fw-cli.md
- **Context:** Initial task creation

### 2026-03-05T01:31:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-05T01:34:13Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
