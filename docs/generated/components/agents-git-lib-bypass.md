# bypass

> Git Agent - Bypass logging subcommand

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/bypass.sh`

## What It Does

Git Agent - Bypass logging subcommand

### Framework Reference

When a PreToolUse hook introduces a bypass contract — e.g. "append `--switch-focus`" or "prefix `FW_X=1`" — the downstream consumers of **every command pattern the hook gates** must honour that contract. A hook that recommends a flag whose downstream parser rejects it as "Unknown option" is a silent governance failure: the agent's workaround (direct-invoke, env-strip, or a different command shape) escapes the regex and bypasses the gate with no audit trail.

**Authoring rule** — when adding a bypass mechanism to a hook:

*(truncated — see CLAUDE.md for full section)*

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [git](/docs/generated/agents-git-git) | called_by | Git Agent - Structural Enforcement for Git Operations |
| [commit](/docs/generated/agents-git-lib-commit) | called_by | Git Agent - Commit subcommand |

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-bypass.yaml`*
*Last verified: 2026-02-20*
