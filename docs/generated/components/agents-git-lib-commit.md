# commit

> Git Agent - Commit subcommand

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/commit.sh`

## What It Does

Git Agent - Commit subcommand
Validates task references before committing
── Pathspec scoping (T-3090) ────────────────────────────────────────────────
Everything after `--` is a PATHSPEC and is forwarded to `git commit` after its
own `--`, so the commit contains only those paths. Without it, `git commit`
takes the WHOLE INDEX — including anything a concurrent session had staged but
not yet committed.
That is not hypothetical: commit d3d3e49db ("T-3028: Session handover
S-2026-0819-2334") absorbed two files belonging to another session's T-3089 and
emptied that session's index out from under it mid-compose. The handover had

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
