---
id: T-034
name: Create init.sh for project bootstrapping
description: >
  Bootstrap script scaffolds .tasks .context CLAUDE.md git hooks and .framework.yaml in target project directory
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: [bootstrapping, shared-tooling, init]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T23:45:27Z
last_update: 2026-02-14T08:59:33Z
date_finished: 2026-02-14T08:59:33Z
---

# T-034: Create init.sh for project bootstrapping

## Design Record

**Architecture:** `lib/init.sh` sourced by `fw` when `fw init` is invoked.

**Scaffolds:**
- `.tasks/{active,completed,templates}` with default.md template
- `.context/{working,project,episodic,handovers}` with empty YAML memory files
- `.framework.yaml` pointing to framework install
- Provider config (CLAUDE.md or .cursorrules)
- Git hooks (if .git exists)

**Key decisions:**
- lib/init.sh (not a separate agent) — init is a one-time setup, not a recurring workflow
- `--provider` flag: claude (CLAUDE.md), cursor (.cursorrules), generic (CLAUDE.md)
- Idempotent: refuses to reinit without `--force`
- Empty project memory files (patterns, decisions, learnings) with schema comments

## Specification Record

**Acceptance Criteria:**
- [x] `fw init` scaffolds full directory structure
- [x] `fw init --provider claude` generates CLAUDE.md
- [x] `fw init --provider cursor` generates .cursorrules
- [x] `.framework.yaml` points to correct framework path
- [x] Git hooks installed when .git exists
- [x] `fw doctor` passes on initialized project
- [x] Idempotent — refuses reinit without --force
- [x] Task template copied from framework

## Updates

### 2026-02-13T23:45:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent

### 2026-02-14T08:59:33Z — build-completed [claude-code]
- **Action:** Built lib/init.sh and wired into fw CLI
- **Output:** lib/init.sh, updated bin/fw with init command routing
- **Context:** Enables `fw init /path/to/project --provider claude` workflow. Also fixed doctor to check commit-msg (not pre-commit) and use correct grep pattern.
- **Tests:** Verified on fresh git repo (all doctor checks pass), idempotency (refuses without --force), cursor provider (.cursorrules generated)
