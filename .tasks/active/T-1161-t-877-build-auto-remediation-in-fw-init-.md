---
id: T-1161
name: "T-877 build: Auto-remediation in fw init — git hooks, enforcement baseline, start guidance"
description: >
  T-877 build: Auto-remediation in fw init — git hooks, enforcement baseline, start guidance

status: captured
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-12T12:13:05Z
last_update: 2026-04-12T12:14:17Z
date_finished: null
---

# T-1161: T-877 build: Auto-remediation in fw init — git hooks, enforcement baseline, start guidance

## Context

Build from T-877 GO. Real user hit 6 failure modes during install. F3 (git hooks), F5 (enforcement baseline), and F6 (start guidance) are auto-remediation fixes in `do_init()`. See `docs/reports/T-877-install-pipeline.md`.

## Acceptance Criteria

### Agent
- [ ] `fw init` auto-installs git hooks when in a git repo
- [ ] `fw init` auto-creates enforcement baseline if missing
- [ ] `fw init` post-init message includes "start Claude Code" guidance

## Verification

bash -c 'grep -q "install-hooks\|install_hooks" lib/init.sh'
bash -c 'grep -q "enforcement.*baseline\|baseline" lib/init.sh'
bash -c 'grep -qi "claude\|agent" lib/init.sh | head -1'

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

### 2026-04-12T12:13:05Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1161-t-877-build-auto-remediation-in-fw-init-.md
- **Context:** Initial task creation

### 2026-04-12T12:14:17Z — status-update [task-update-agent]
- **Change:** status: started-work → captured
- **Reason:** Already implemented — git hooks (line 392), enforcement baseline (line 400), Claude Code guidance (line 490) all present in lib/init.sh
