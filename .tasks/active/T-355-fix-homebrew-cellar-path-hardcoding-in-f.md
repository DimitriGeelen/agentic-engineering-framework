---
id: T-355
name: "Fix Homebrew Cellar path hardcoding in fw init — use opt symlink"
description: >
  Fix Homebrew Cellar path hardcoding in fw init — use opt symlink

status: work-completed
workflow_type: build
owner: human
horizon: now
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-03-08T17:25:34Z
last_update: 2026-03-08T19:14:05Z
date_finished: 2026-03-08T17:33:40Z
---

# T-355: Fix Homebrew Cellar path hardcoding in fw init — use opt symlink

## Context

GitHub issue #7. `fw init` bakes Homebrew Cellar paths into `.claude/settings.json`. Cellar paths are versioned — `brew upgrade` removes the old version directory, silently breaking all 10 hooks. Fix: resolve through `/usr/local/opt/fw` symlink which Homebrew maintains. Related: T-352.

## Acceptance Criteria

### Agent
- [x] `resolve_framework()` in `bin/fw` detects Cellar paths and returns opt symlink instead
- [x] `fw doctor` warns about existing Cellar paths in hooks (even when paths still exist)
- [x] `fw doctor` shows actionable fix message for stale Cellar paths

### Human
- [ ] [RUBBER-STAMP] Verify on macOS: `brew reinstall fw && fw init --provider claude --force && cat .claude/settings.json`
  **Steps:**
  1. `brew reinstall DimitriGeelen/agentic-fw/fw`
  2. `mkdir /tmp/test-cellar && cd /tmp/test-cellar && git init && fw init --provider claude --force`
  3. `cat .claude/settings.json | grep -o '/[^ "]*agents' | head -1`
  **Expected:** Path contains `/opt/fw/libexec/agents`, NOT `/Cellar/fw/`
  **If not:** Check `fw version` for FRAMEWORK_ROOT path — should be opt, not Cellar

## Verification

# resolve_framework Cellar detection code exists
grep -q 'Cellar/fw' bin/fw
# fw doctor Cellar warning code exists
grep -q 'stale Homebrew Cellar path' bin/fw

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

### 2026-03-08T17:25:34Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-355-fix-homebrew-cellar-path-hardcoding-in-f.md
- **Context:** Initial task creation

### 2026-03-08T17:33:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
