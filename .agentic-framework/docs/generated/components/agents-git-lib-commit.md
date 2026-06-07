# commit

> Git Agent - Commit subcommand

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/commit.sh`

## What It Does

Git Agent - Commit subcommand
Validates task references before committing

### Framework Reference

- **Commit after every meaningful unit of work** (not just at session end)
- A "meaningful unit" = completing a subtask, finishing a file, or making a decision
- Each commit is a checkpoint: if context runs out, work up to the last commit is safe
- Target: at least one commit every 15-20 minutes of active work

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [bypass](/docs/generated/agents-git-lib-bypass) | calls | Git Agent - Bypass logging subcommand |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [git](/docs/generated/agents-git-git) | called_by | Git Agent - Structural Enforcement for Git Operations |

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-commit.yaml`*
*Last verified: 2026-02-20*
