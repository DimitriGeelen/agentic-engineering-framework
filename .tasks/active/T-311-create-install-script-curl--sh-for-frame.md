---
id: T-311
name: "Create install script (curl | sh) for framework"
description: >
  Every comparison tool (Cargo, Next.js, Claude Code) has package-manager or curl install. Framework requires git clone + PATH setup. One-liner install script would reduce friction. Source: T-294 DX comparison finding.

status: started-work
workflow_type: build
owner: agent
horizon: later
tags: []
components: []
related_tasks: [T-294]
created: 2026-03-04T17:28:41Z
last_update: 2026-03-04T22:21:19Z
date_finished: null
---

# T-311: Create install script (curl | sh) for framework

## Context

One-liner install reduces friction from "git clone + PATH setup" to `curl | sh`. Script goes in `install.sh` at repo root.

## Acceptance Criteria

### Agent
- [x] `install.sh` exists at repo root and is executable
- [x] Script checks prerequisites (bash 4.4+, git 2.20+, python3 with PyYAML)
- [x] Script clones repo to configurable install directory (default: `~/.agentic-framework`)
- [x] Script adds `fw` to PATH via symlink
- [x] Script runs `fw doctor` to verify installation
- [x] Script is idempotent (re-running updates instead of failing)
- [x] README.md updated with curl install option

## Verification

# Script exists and is executable
test -x install.sh
# Script checks prerequisites
grep -q "bash" install.sh
grep -q "git" install.sh
grep -q "python" install.sh
# Script has configurable install dir
grep -q "INSTALL_DIR" install.sh
# Script runs fw doctor
grep -q "fw doctor" install.sh
# README mentions the install script
grep -q "install.sh" README.md

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

### 2026-03-04T17:28:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-311-create-install-script-curl--sh-for-frame.md
- **Context:** Initial task creation

### 2026-03-04T22:21:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
