# t3425_sidecar_read_allowlist

> T-3425 (OBS-461) — the sidecar's read verbs and TermLink's channel reads are on the task gate's read-only allowlist; their write forms are not.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3425_sidecar_read_allowlist.bats`

## What It Does

T-3425 (OBS-461) — the sidecar's read verbs and TermLink's channel reads are
on the task gate's read-only allowlist; their write forms are not.
Origin: right after a task close nulled focus, with the only focusable
task partial-complete, `bin/fw sidecar inbox --peek` was refused by
check-active-task.sh — a session could not see whether a peer consult was
waiting for it. Each accepted and each refused form is pinned here so the
read/write split cannot drift silently in either direction.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | tests | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3425_sidecar_read_allowlist.yaml`*
*Last verified: 2026-09-22*
