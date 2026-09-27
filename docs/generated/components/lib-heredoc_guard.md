# heredoc_guard

> T-1945 — Heredoc-in-cmd-substitution detector helper.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/heredoc_guard.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-heredoc-cmd-sub](/docs/generated/agents-context-check-heredoc-cmd-sub) | called_by | T-1945 — Heredoc-in-command-substitution edit-time guard. |

---
*Auto-generated from Component Fabric. Card: `lib-heredoc_guard.yaml`*
*Last verified: 2026-05-20*
