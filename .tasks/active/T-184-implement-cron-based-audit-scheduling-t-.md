---
id: T-184
name: "Implement cron-based audit scheduling (T-151 GO)"
description: >
  Implement the cron-based audit scheduling system from T-151's GO decision. Four deliverables: (1) Add --section and --output flags to audit.sh, (2) Create fw audit schedule command to install/manage cron entries, (3) Modify fw context init to read cron audit findings, (4) Add cron results to Watchtower quality page.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-19T07:01:37Z
last_update: 2026-02-19T07:01:37Z
date_finished: null
---

# T-184: Implement cron-based audit scheduling (T-151 GO)

## Context

Implements the cron-based audit scheduling system designed in T-151. The framework's audit system is comprehensive (9 sections) but runs unreliably because it depends on agent discipline. Cron scheduling is a mechanical fix: stateless quality checks run on a timer, producing reports that sessions consume at startup.

Related: T-151 (investigation, GO decision)

## Acceptance Criteria

- [x] `fw audit --section structure,quality` runs only specified sections
- [x] `fw audit --output /path/to/dir` writes YAML report to custom directory
- [x] `fw audit --quiet` suppresses terminal output (cron-friendly)
- [x] `fw audit schedule install` installs cron entries to `/etc/cron.d/agentic-audit`
- [x] `fw audit schedule remove` removes cron entries
- [x] `fw audit schedule status` shows current schedule
- [x] `fw context init` reads and displays latest cron audit findings when available
- [x] Retention policy: cron audit files older than 7 days are auto-pruned

## Verification

# Section filtering works (only structure section, should have fewer findings than full audit)
rm -rf /tmp/t184-verify && fw audit --section structure --quiet --output /tmp/t184-verify && ls /tmp/t184-verify/*.yaml >/dev/null 2>&1
# Schedule subcommand exists and shows help
fw audit schedule status 2>&1 | grep -qiE "schedule|cron|not installed|INSTALLED"
# YAML output is valid (audit may exit 1 for warnings, that's OK)
rm -rf /tmp/t184-verify2; fw audit --quiet --output /tmp/t184-verify2; python3 -c "import yaml; yaml.safe_load(open(next(iter(sorted(__import__('glob').glob('/tmp/t184-verify2/2026*.yaml'))))))"

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

### 2026-02-19T07:01:37Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-184-implement-cron-based-audit-scheduling-t-.md
- **Context:** Initial task creation
