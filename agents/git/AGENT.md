# Git Agent

> Enforces task traceability for all git operations.

## Purpose

The git agent is the **structural enforcement layer** for code changes. It ensures every commit connects to a task, making non-compliance harder than compliance (P-002: Structural Enforcement Over Agent Discipline).

**Key insight:** The git agent doesn't just wrap git commands—it embodies the framework's traceability guarantee at the enforcement point closest to code changes.

## When to Use

| Trigger | Command |
|---------|---------|
| Committing changes | `./agents/git/git.sh commit -m "T-XXX: message"` |
| Checking status | `./agents/git/git.sh status` |
| Setting up new repo/clone | `./agents/git/git.sh install-hooks` |
| Documenting a bypass | `./agents/git/git.sh log-bypass` |
| Viewing task history | `./agents/git/git.sh log --task T-XXX` |
| Checking traceability | `./agents/git/git.sh log --traceability` |

## Commands

### commit

Commits with task reference validation.

```bash
# Standard commit (requires T-XXX in message)
./agents/git/git.sh commit -m "T-003: Add bypass log"

# Specify task separately
./agents/git/git.sh commit -t T-003 -m "Add bypass log"

# Emergency bypass (prompts for reason, logs to bypass-log)
./agents/git/git.sh commit --bypass -m "Emergency hotfix"
./agents/git/git.sh commit --bypass --reason "Production P1" -m "Emergency hotfix"
```

**Behavior:**
1. Validates message contains T-[0-9]+ pattern
2. If missing: blocks with helpful error message
3. If present: commits and updates task's `last_update` timestamp
4. If `--bypass`: commits, logs to bypass-log.yaml, reminds to create retroactive task

### status

Task-aware git status showing context.

```bash
./agents/git/git.sh status
```

**Output includes:**
- Most recently modified active task (as context)
- Standard git status
- Helpful commit tip with task ID

### install-hooks

Installs commit-msg and post-commit hooks for enforcement.

```bash
./agents/git/git.sh install-hooks
./agents/git/git.sh install-hooks --force  # Reinstall
```

**Installs:**
- `commit-msg` hook: Blocks commits without task references
- `post-commit` hook: Detects bypasses and reminds to log them

**Hook behavior:**
- Merge commits and rebases are allowed (no task ref required)
- Bypass with `git commit --no-verify` (shows warning)

### log-bypass

Records a bypass in `.context/bypass-log.yaml`.

```bash
# Full command
./agents/git/git.sh log-bypass --commit acb4594 --reason "Bootstrap exception"

# Interactive mode (prompts for values)
./agents/git/git.sh log-bypass

# With retroactive task
./agents/git/git.sh log-bypass --commit abc123 --reason "P1 hotfix" --retroactive-task T-015
```

### log

Task-filtered git log with traceability stats.

```bash
# Filter by task
./agents/git/git.sh log --task T-003

# Show traceability report
./agents/git/git.sh log --traceability

# Recent commits
./agents/git/git.sh log -n 20
```

## File Structure

```
agents/git/
  git.sh              # Main router
  AGENT.md            # This file
  lib/
    common.sh         # Shared utilities
    commit.sh         # Commit command
    status.sh         # Status command
    hooks.sh          # Hook installation
    bypass.sh         # Bypass logging
    log.sh            # Log/history command

.git/hooks/
  commit-msg          # Installed by install-hooks
  post-commit         # Installed by install-hooks

.context/
  bypass-log.yaml     # Bypass audit trail
```

## Integration

### With Handover Agent

Handover can auto-commit via optional `--commit` flag:
```bash
./agents/handover/handover.sh --commit
```

### With Audit Agent

Audit validates:
- Pre-commit hook is installed
- Bypass log exists when commits lack refs
- Hook version is current

### With Task-Create Agent

After creating a task, use git agent to commit:
```bash
./agents/task-create/create-task.sh --name "New feature" --start
./agents/git/git.sh commit -m "T-014: Initial implementation"
```

## Bypass Policy

Bypasses are **allowed but always logged**. This follows:
- D2 (Reliability): No silent failures
- P-005: Bootstrap exceptions are first-class

**Valid bypass reasons:**
- Bootstrap exception (task system didn't exist)
- Production P1 incident (retroactive task required)
- Tooling failure (git agent broken)

**Invalid bypass reasons:**
- "Too lazy to create task" — create the task
- "Quick fix" — quick fixes need tasks too
- "Will add later" — add it now

## Error Messages

| Scenario | Message | Action |
|----------|---------|--------|
| No task ref | "No task reference found" | Add T-XXX or use --bypass |
| Task not found | "Task T-XXX not found" (warning only) | Consider creating task |
| Bypass without reason | "Bypass requires a reason" | Provide --reason |
| Hooks already installed | "Hooks already installed" | Use --force to reinstall |

## Setup for New Repository

```bash
# 1. Initialize git (if needed)
git init

# 2. Install enforcement hooks
./agents/git/git.sh install-hooks

# 3. Verify
./agents/git/git.sh log --traceability
```

## Completing T-003 and T-004

This agent absorbs both tasks:

**T-003 (bypass log):**
```bash
./agents/git/git.sh log-bypass --commit acb4594 --reason "Bootstrap exception - task system did not exist"
```

**T-004 (pre-commit hook):**
```bash
./agents/git/git.sh install-hooks
```

## Related

- `agents/task-create/` — Create tasks before committing
- `agents/audit/` — Validates traceability and hooks
- `agents/handover/` — Can use git agent for auto-commit
- `015-Practices.md` — P-002 (Structural Enforcement)
- `011-EnforcementConfig.md` — Bypass log format spec
