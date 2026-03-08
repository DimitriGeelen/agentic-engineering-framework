---
id: T-352
name: "Fix hook path resolution in fw init for Homebrew installs"
description: >
  Fix hook path resolution in fw init for Homebrew installs

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [lib/init.sh]
related_tasks: []
created: 2026-03-08T15:57:48Z
last_update: 2026-03-08T16:03:31Z
date_finished: 2026-03-08T15:59:54Z
---

# T-352: Fix hook path resolution in fw init for Homebrew installs

## Context

`_sed_i` function was undefined in `lib/init.sh` — `__FRAMEWORK_ROOT__` and `__PROJECT_ROOT__` placeholders in generated `.claude/settings.json` were never replaced with real paths. Fix: use unquoted heredoc with shell variable expansion instead of post-processing with sed.

## Acceptance Criteria

### Agent
- [x] Generated `.claude/settings.json` contains real absolute paths, not `__FRAMEWORK_ROOT__` placeholders
- [x] `fw doctor` reports "Hook configuration valid" on freshly initialized project

### Human
- [ ] [RUBBER-STAMP] Homebrew install + fw init + fw doctor passes on macOS
  **Steps:**
  1. `brew reinstall DimitriGeelen/agentic-fw/fw` (after this version is released)
  2. `mkdir /tmp/test-brew && cd /tmp/test-brew && git init && fw init --provider claude`
  3. `fw doctor`
  **Expected:** No FAIL on hook config, all hooks resolve
  **If not:** Check `.claude/settings.json` for placeholder strings

## Verification

# Test that init generates real paths (no placeholders)
tmpdir=$(mktemp -d) && git init -q "$tmpdir" && fw init "$tmpdir" --provider claude --force >/dev/null 2>&1 && ! grep -q '__FRAMEWORK_ROOT__\|__PROJECT_ROOT__' "$tmpdir/.claude/settings.json" && rm -rf "$tmpdir"

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

### 2026-03-08T15:57:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-352-fix-hook-path-resolution-in-fw-init-for-.md
- **Context:** Initial task creation

### 2026-03-08T15:59:54Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
