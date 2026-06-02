---
id: T-1479
name: "T-1479: fw upgrade detects duplicate framework hooks across user-level and project-level settings"
description: >
  T-1479: fw upgrade detects duplicate framework hooks across user-level and project-level settings

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-25T21:29:10Z
last_update: 2026-04-25T21:31:52Z
date_finished: 2026-04-25T21:31:52Z
---

# T-1479: T-1479: fw upgrade detects duplicate framework hooks across user-level and project-level settings

## Context

OBS-023's structural cause: framework hooks were registered at BOTH user-level (`~/.claude/settings.json`) and project-level (`.claude/settings.json`). Every Claude Code event then fired both. T-1478's time-window dedup mitigates the symptom; this task handles the cause by surfacing duplicates during `fw upgrade` so the consumer can clean them up.

`fw upgrade` already manages project-level hook installation (lib/upgrade.sh §5). After installing/verifying project hooks, scan `~/.claude/settings.json` for hooks that match the project-level set (by `(event, hook_name)` tuple where the hook command contains `fw hook` or `.agentic-framework`). If overlap exists, emit a warning with the duplicate list. We do NOT auto-remove user-level hooks — that's user state outside the project boundary. Warn-only.

## Acceptance Criteria

### Agent
- [x] `lib/upgrade.sh` step [5/10] adds a duplicate-hook scan after the project-level hook step
- [x] Scan reads `$HOME/.claude/settings.json` and extracts `(event, hook_name)` tuples for hooks whose command contains `fw hook` or `.agentic-framework`
- [x] If overlap with project-level hooks is non-empty, emits a yellow `WARN` line listing the duplicate pairs
- [x] When `~/.claude/settings.json` doesn't exist or is malformed, the scan degrades gracefully (no upgrade abort)
- [x] `bash -n lib/upgrade.sh` passes
- [x] bats test `tests/unit/upgrade_duplicate_hook_detection.bats` passes (11/11)
- [x] Real-world verification: detection finds 16 duplicate hooks on this project (the PostToolUse + PreToolUse + PreCompact set)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# The added scan is present in upgrade.sh
grep -q "Duplicate framework hook" lib/upgrade.sh
# The function/scan reads ~/.claude/settings.json
grep -q '\$HOME/.claude/settings.json' lib/upgrade.sh
# Parses
bash -n lib/upgrade.sh
# Test passes
cd /opt/999-Agentic-Engineering-Framework && bats tests/unit/upgrade_duplicate_hook_detection.bats

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

### 2026-04-25T21:29:10Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1479-t-1479-fw-upgrade-detects-duplicate-fram.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b50a704a
- **Timestamp:** 2026-06-02T14:57:45Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T21:31:52Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
