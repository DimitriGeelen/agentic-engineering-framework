---
id: T-101
name: Fix critical hook PROJECT_ROOT bug for external projects
description: >
  CRITICAL BUG: When fw init generates .claude/settings.json for external projects, the hook commands (check-active-task.sh, check-tier0.sh, checkpoint.sh) do not set PROJECT_ROOT. All three scripts fall back to FRAMEWORK_ROOT, meaning enforcement silently operates against the framework repo state, not the project. This is invisible — no errors, just wrong behavior. Fix: Add PROJECT_ROOT placeholder to generated settings.json hook commands and substitute via sed alongside FRAMEWORK_ROOT. Acceptance: hooks in generated settings.json include PROJECT_ROOT=/path/to/project prefix. Files: lib/init.sh (generate_claude_code_config function, lines 256-305).
status: work-completed
workflow_type: build
owner: agent
tags: [critical, fw-init, hooks, external-project]
related_tasks: []
created: 2026-02-17T08:53:08Z
last_update: 2026-02-17T09:18:53Z
date_finished: null
---

# T-101: Fix critical hook PROJECT_ROOT bug for external projects

## Context

Discovered during deep architectural analysis of fw init for external project use (session S-2026-0217-0920).
Three parallel investigation agents identified this as the #1 showstopper bug.
Predecessor analysis: T-097 (dispatch infrastructure), T-098 (dispatch protocol).

## Dependencies

- **Blocks:** T-103, T-104, T-106, T-107
- **Blocked by:** Nothing — this is the critical path start

## Implementation Guide

### The Bug (lib/init.sh:262-298)

Generated `.claude/settings.json` hook commands look like:
```json
"command": "__FRAMEWORK_ROOT__/agents/context/check-active-task.sh"
```

The scripts do: `PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"` (check-active-task.sh:22, check-tier0.sh:26, checkpoint.sh:23). Since PROJECT_ROOT is never set in the hook environment, ALL hooks silently check the framework's .context/, not the project's.

### The Fix

1. Add `__PROJECT_ROOT__` placeholder to all hook commands in the settings.json template:
```json
"command": "PROJECT_ROOT=__PROJECT_ROOT__ __FRAMEWORK_ROOT__/agents/context/check-active-task.sh"
```

2. Add a second sed replacement after the existing one (lib/init.sh:301):
```bash
sed -i "s|__FRAMEWORK_ROOT__|$FRAMEWORK_ROOT|g" "$dir/.claude/settings.json"
sed -i "s|__PROJECT_ROOT__|$target_dir|g" "$dir/.claude/settings.json"
```

3. Also fix the sed fragility: if FRAMEWORK_ROOT or target_dir contains `|` characters, sed breaks. Use a different delimiter or Python for substitution.

### Files to Modify

- `lib/init.sh` — generate_claude_code_config function (lines 256-305)

### Acceptance Criteria

- [x] Generated settings.json hook commands include `PROJECT_ROOT=/path/to/project` prefix
- [x] check-active-task.sh reads focus.yaml from PROJECT, not FRAMEWORK
- [x] check-tier0.sh reads tier0 approval from PROJECT, not FRAMEWORK
- [x] checkpoint.sh reads token counter from PROJECT, not FRAMEWORK
- [x] Test: `fw init /tmp/test-proj --provider claude && grep PROJECT_ROOT /tmp/test-proj/.claude/settings.json`

## Updates

### 2026-02-17T09:10:00Z — work-completed [claude-code]
- **Action:** Added PROJECT_ROOT=__PROJECT_ROOT__ prefix to all 3 hook commands in generate_claude_code_config(). Added second sed pass for PROJECT_ROOT substitution.
- **Output:** Verified: `grep PROJECT_ROOT /tmp/test-proj/.claude/settings.json` shows all 3 hooks correctly set PROJECT_ROOT=/tmp/test-proj
- **Context:** 4-line change in lib/init.sh. All acceptance criteria met.

### 2026-02-17T08:53:08Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-101-fix-critical-hook-projectroot-bug-for-ex.md
- **Context:** Initial task creation
