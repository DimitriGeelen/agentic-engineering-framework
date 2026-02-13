---
id: T-004
name: Install pre-commit hook for task enforcement
description: >
  Create a git pre-commit hook that validates commit messages contain task references (T-XXX pattern). This provides structural enforcement per D2 Reliability.
status: captured
workflow_type: build
owner: human
priority: medium
tags: [enforcement, git, D2]
agents:
  primary:
  supporting: []
created: 2026-02-13T18:13:16Z
last_update: 2026-02-13T18:13:16Z
date_finished: null
---

# T-004: Install pre-commit hook for task enforcement

## Design Record

Per P-002 (Structural Enforcement Over Agent Discipline), we cannot rely on agents/humans to remember task references. A git pre-commit hook provides structural enforcement.

**Design decisions:**
- Hook checks commit message for T-XXX pattern
- Allows bypass with `--no-verify` (Tier 2 bypass - logs warning)
- Does NOT block merge commits or rebase
- Provides helpful error message with task-create command

**Not in scope (future):**
- Validating task file exists
- Checking task status
- Tier 0 action blocking (that's a different hook)

## Specification Record

**Acceptance criteria:**
- [ ] `.git/hooks/pre-commit` exists and is executable
- [ ] Commit without task reference is blocked with helpful message
- [ ] Commit with task reference (T-XXX) succeeds
- [ ] `--no-verify` bypass works but logs warning
- [ ] Merge commits are allowed (no task ref required)
- [ ] Audit agent passes (no "pre-commit hook missing" warning)

**Hook behavior:**
```
If commit message does NOT contain T-[0-9]+:
  - Print error: "Commit blocked: No task reference found"
  - Print help: "Add task reference: git commit -m 'T-XXX: description'"
  - Print help: "Create task: ./agents/task-create/create-task.sh"
  - Print help: "Bypass (emergency): git commit --no-verify"
  - Exit 1
Else:
  - Allow commit
  - Exit 0
```

## Test Files

- Test: commit without task ref → blocked
- Test: commit with T-001 → allowed
- Test: merge commit → allowed
- Run `./agents/audit/audit.sh` → no hook warning

## Updates

### 2026-02-13T18:13:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-004-install-pre-commit-hook-for-task-enforce.md
- **Context:** Initial task creation
