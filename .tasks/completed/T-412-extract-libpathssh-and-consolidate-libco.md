---
id: T-412
name: "Extract lib/paths.sh and consolidate lib/compat.sh (S1+S5)"
description: >
  Extract duplicated path resolution (SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT) into lib/paths.sh — currently copy-pasted in 25+ files. Consolidate _sed_i compat fallback (5 files) into guaranteed lib/compat.sh sourcing. Directive score: S1=10 (highest), S5=7. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: work-completed
workflow_type: refactor
owner: human
horizon: now
tags: [refactoring, shell, reliability, portability]
components: [C-004, agents/audit/plugin-audit.sh, agents/audit/self-audit.sh, C-007, agents/context/bus-handler.sh, agents/context/check-active-task.sh, C-008, agents/context/check-tier0.sh, C-001, agents/context/post-compact-resume.sh, agents/context/pre-compact.sh, agents/docgen/generate-article.sh, agents/docgen/generate-component.sh, agents/fabric/fabric.sh, agents/git/git.sh, agents/handover/handover.sh, agents/healing/healing.sh, agents/observe/observe.sh, agents/onboarding-test/test-onboarding.sh, agents/resume/resume.sh, agents/task-create/create-task.sh, agents/task-create/update-task.sh, bin/watchtower.sh, lib/ask.sh, lib/paths.sh]
related_tasks: [T-406, T-411]
created: 2026-03-10T21:03:12Z
last_update: 2026-03-12T12:41:20Z
date_finished: 2026-03-10T22:28:17Z
---

# T-412: Extract lib/paths.sh and consolidate lib/compat.sh (S1+S5)

## Context

Refactoring finding S1 (score 10/12) + S5 (score 7/12) from `docs/reports/T-411-refactoring-directive-scoring.md`.

**S1 — Path resolution duplication (25+ files):**
Every shell script duplicates 3-4 lines of SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT resolution.
See research artifact § "SHELL SCRIPTS" row S1. Files affected: all `agents/*/` scripts, `lib/*.sh`, `bin/fw`.
The T-406 shared-tooling fix already exposed this as a portability risk.

**S5 — _sed_i compat duplication (5 files):**
Scripts define inline _sed_i fallback when lib/compat.sh fails. See research artifact § S5.
Files: update-task.sh:25-28, resume.sh:16-18, context/lib/*.sh.

## Acceptance Criteria

### Agent
- [x] lib/paths.sh created with resolve_paths() function setting SCRIPT_DIR, FRAMEWORK_ROOT, PROJECT_ROOT
- [x] All agents/* scripts source lib/paths.sh instead of inline path resolution
- [x] lib/compat.sh sourced reliably (no inline fallbacks remain in agents/)
- [x] All existing tests/verification commands still pass after change
- [x] fw doctor passes

### Human
- [x] [RUBBER-STAMP] Spot-check 3 agent scripts use lib/paths.sh
  **Steps:**
  1. Run `head -10 agents/audit/audit.sh agents/git/git.sh agents/healing/healing.sh`
  2. Verify each sources lib/paths.sh instead of inline SCRIPT_DIR/FRAMEWORK_ROOT
  **Expected:** Each script starts with `source "$FRAMEWORK_ROOT/lib/paths.sh"`
  **If not:** Note which script still has inline path resolution

## Verification

test -f lib/paths.sh
bash -n lib/paths.sh
source lib/paths.sh && test -n "$FRAMEWORK_ROOT"
# Verify no inline PROJECT_ROOT resolution in agents (SCRIPT_DIR kept for local lib refs)
! grep -r 'PROJECT_ROOT=.*git.*rev-parse' agents/ --include='*.sh' -l | grep -v 'git/lib/hooks.sh' | grep -q .
fw doctor

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

### 2026-03-10T21:03:12Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-412-extract-libpathssh-and-consolidate-libco.md
- **Context:** Initial task creation

### 2026-03-10T22:19:22Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-10T22:28:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
