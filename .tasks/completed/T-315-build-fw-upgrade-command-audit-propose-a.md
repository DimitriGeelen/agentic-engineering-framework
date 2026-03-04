---
id: T-315
name: "Build fw upgrade command (audit, propose, apply)"
description: >
  Rails-style interactive upgrade for frozen artifacts. Phase 1: audit (hash frozen files vs current framework). Phase 2: propose (diff report per file). Phase 3: apply (replace/keep/merge per file, backup originals). Covers: settings.json hooks, CLAUDE.md sections, task templates, seed YAML merge by ID, git hooks reinstall, version marker update. Source: T-306 investigation, Agents 2+6+8+9 findings.

status: work-completed
workflow_type: build
owner: agent
horizon: next
tags: []
components: [lib/upgrade.sh]
related_tasks: []
created: 2026-03-04T19:27:23Z
last_update: 2026-03-04T20:49:02Z
date_finished: 2026-03-04T20:49:02Z
---

# T-315: Build fw upgrade command (audit, propose, apply)

## Context

T-306 found existing `fw upgrade` (T-169) had bugs: settings.json regeneration silently skipped (generate_claude_code_config checks file existence), detection only checked for budget-gate, no backups. Fix these + verify all 6 upgrade phases work correctly with T-313/T-314 fixes.

## Acceptance Criteria

### Agent
- [x] Settings.json detection counts hooks (not just checks for budget-gate)
- [x] Settings.json regeneration uses force=true to override file existence check
- [x] Backup (.bak) created before overwriting settings.json
- [x] Backup (.bak) created before overwriting CLAUDE.md
- [x] Dry-run shows correct hook count (N/10 hooks, missing M)
- [x] Stale project (5 hooks) upgrades to 10 hooks after fw upgrade

## Verification

# fw upgrade exists and is callable
grep -q 'do_upgrade' lib/upgrade.sh
# Hook count detection present
grep -q 'expected_hooks=10' lib/upgrade.sh
# Backup mechanism present
grep -q '.bak' lib/upgrade.sh
# Force regeneration present
grep -q 'force=true' lib/upgrade.sh

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

### 2026-03-04T19:27:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-315-build-fw-upgrade-command-audit-propose-a.md
- **Context:** Initial task creation

### 2026-03-04T20:44:13Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-04T20:49:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
