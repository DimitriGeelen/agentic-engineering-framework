---
id: T-013
name: Create git agent for local operations
description: >
  Design and implement a git agent that handles: commit with task refs, pre-commit enforcement, bypass logging. Consider integration with handover script. Phase 1: local only. Phase 2: remote operations.
status: work-completed
workflow_type: design
owner: human
priority: medium
tags: [enforcement, git, P-002]
agents:
  primary: claude-code
  supporting: [Plan]
created: 2026-02-13T18:32:42Z
last_update: 2026-02-13T18:47:56Z
date_finished: 2026-02-13T19:47:00Z
---

# T-013: Create git agent for local operations

## Design Record

**Key design decisions:**

1. **Hybrid architecture** (bash scripts + AGENT.md) following P-006
2. **Modular structure** with lib/ subdirectory for maintainability
3. **Absorbs T-003 and T-004** — bypass logging and hook installation become git agent commands
4. **commit-msg hook** (not pre-commit) — validates message format, not file content
5. **Optional handover integration** — `--commit` flag for auto-commit

**Integration points:**
- Handover agent: Optional `--commit` flag calls git agent
- Audit agent: Updated to check for commit-msg hook
- CLAUDE.md: Updated with git agent commands

## Specification Record

**Commands implemented:**
- `git.sh commit` — Commit with task ref validation
- `git.sh status` — Task-aware status
- `git.sh install-hooks` — Install commit-msg + post-commit hooks
- `git.sh log-bypass` — Record bypasses in .context/bypass-log.yaml
- `git.sh log` — Task-filtered history and traceability stats

**Acceptance criteria:**
- [x] Git agent created at agents/git/
- [x] AGENT.md documents all commands
- [x] Hooks installed successfully
- [x] Bootstrap bypass logged
- [x] Audit passes (T-003, T-004 warnings resolved)
- [x] Handover --commit flag works
- [x] CLAUDE.md updated

## Test Files

- Run `./agents/git/git.sh commit -m "test"` → blocked (no task ref)
- Run `./agents/git/git.sh commit -m "T-013: test"` → allowed
- Run `./agents/git/git.sh log --traceability` → shows stats
- Run `./agents/audit/audit.sh` → passes hook and bypass checks

## Updates

### 2026-02-13T18:32:42Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-013-create-git-agent-for-local-operations.md
- **Context:** Initial task creation

### 2026-02-13T19:35:00Z — design-complete [Plan agent]
- **Action:** Spawned Plan agent for comprehensive git agent design
- **Output:** Full design document covering scope, commands, integration, phases
- **Context:** Design includes absorbing T-003 and T-004

### 2026-02-13T19:46:00Z — implementation-complete [claude-code]
- **Action:** Implemented git agent with all Phase 1 commands
- **Output:** agents/git/ directory with git.sh, AGENT.md, lib/
- **Context:** Hooks installed, bootstrap bypass logged, handover updated
