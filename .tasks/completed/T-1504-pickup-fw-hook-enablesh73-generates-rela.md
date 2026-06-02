---
id: T-1504
name: "Pickup: fw hook-enable.sh:73 generates relative-path hook commands that fail when shell cwd != project root (680 silent occurrences in one downstream project) (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-140. Type: bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: [pickup, bug-report]
components: [bin/hook-enable.sh, tests/unit/hook_enable_absolute_path.bats]
related_tasks: []
created: 2026-04-26T11:13:33Z
last_update: 2026-04-26T12:02:30Z
date_finished: 2026-04-26T12:02:30Z
source_task_id_in_origin: T-140
source_project_in_origin: "003-NTB-ATC-Plugin"
---

# T-1504: Pickup: fw hook-enable.sh:73 generates relative-path hook commands that fail when shell cwd != project root (680 silent occurrences in one downstream project) (from 003-NTB-ATC-Plugin)

## Context

`bin/hook-enable.sh:73` writes hook commands as relative paths:
```
command_str=".agentic-framework/bin/fw hook $name"
```

POSIX `sh -c` (Claude Code's hook runner) does not chdir to the project root before invoking, so `.agentic-framework/bin/fw` resolves only when the parent shell happens to be at project root — rarely true after any `cd /tmp`, sub-shell, pipeline, or non-interactive Bash. Downstream 003-NTB-ATC-Plugin: **680 silent occurrences** in one session JSONL (~7.5% of tool calls), each carrying the "non-blocking status code" prefix so it never surfaces.

`generate_claude_code_config` in `lib/init.sh:584` was already fixed to emit absolute paths under T-1364 (G-053-A). T-1504 closes the second code path that was missed: `fw hook-enable` (used to register custom hooks beyond the init-time set).

**Fix:** Match `init.sh:584` pattern — resolve `$PROJECT_ROOT` to canonical absolute path, detect framework-mode vs consumer-mode, emit absolute `$prefix/bin/fw hook $name`.

**Note for downstream:** existing relative-path entries in `.claude/settings.json` are repaired by `fw upgrade` (which regenerates the section). Documented at task close.

## Acceptance Criteria

### Agent
- [x] `bin/hook-enable.sh` resolves PROJECT_ROOT to absolute path and emits absolute hook command (matching `init.sh:584` pattern: framework repo uses `bin/fw`, consumer uses `.agentic-framework/bin/fw`)
- [x] Bats regression test: registered hook command is absolute, contains the project root, and survives a sub-shell `cd /tmp` (i.e. resolves correctly via `sh -c`)
- [x] Idempotency preserved (re-registering same hook is no-op, even though command_str now differs from the legacy relative form? — test by re-registering returns "already registered" only when path matches)

## Verification

bash -n bin/hook-enable.sh
bats tests/unit/hook_enable_absolute_path.bats

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

### 2026-04-26T11:13:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1504-pickup-fw-hook-enablesh73-generates-rela.md
- **Context:** Initial task creation

### 2026-04-26T12:00:24Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7681df46
- **Timestamp:** 2026-06-02T14:57:56Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-26T12:02:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
