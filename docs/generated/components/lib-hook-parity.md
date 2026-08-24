# hook-parity

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/hook-parity.sh`

## What It Does

lib/hook-parity.sh — the enforcement-baseline comparison predicate (T-3112, R7 leg 3)
ONE PREDICATE, MANY SURFACES (the T-3101 shape).
"Does this replica carry the hooks the authority carries?" is asked of two
different subjects that used to have nothing in common:
1. CONSUMER PROJECTS — a vendored `.agentic-framework/` tree with its own
`.claude/settings.json`. Audited by `fw doctor` since T-616.
2. LINKED WORKTREES  — a git worktree with its own `.claude/settings.json`,
its own `bin/fw`, and its own copy of the enforcement code that is
supposed to constrain it. Audited by nobody until this file existed.
Subject (2) is the R7 discovery: rules are enforced by code, code is tracked

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [hook_parity](/docs/generated/lib-hook_parity) | called_by | TODO: describe what this component does |
| [t3111_worktree_reexec](/docs/generated/tests-unit-t3111_worktree_reexec) | tests_by | TODO: describe what this component does |
| [t3112_worktree_hook_parity](/docs/generated/tests-unit-t3112_worktree_hook_parity) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-hook-parity.yaml`*
*Last verified: 2026-08-20*
