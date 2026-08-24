# t2920_boundary_heredoc_strip_order

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2920_boundary_heredoc_strip_order.bats`

## What It Does

T-2920 — the project-boundary hook must not read a heredoc BODY as a command.
Found live: a rail message to 832 was refused as "a command targeting another
project" because the message TEXT contained `cd <path>` as prose describing
our own Copy-Pasteable Commands rule, inside a `<<'EOF'` heredoc.
The hook already carried both defences — _strip_quoted (T-1361) and
_strip_heredocs (T-1702) — but in an order where the first voids the second:
_strip_quoted blanks the quoted marker in `<<'EOF'`, leaving `<<'   '`, and
_strip_heredocs matches `(\w+)`, which cannot match spaces. So the QUOTED
heredoc form's body was never stripped.
The both-forms axis below is the load-bearing part. T-1702's own examples use

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-project-boundary](/docs/generated/agents-context-check-project-boundary) | calls | PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559). |
| [check-project-boundary](/docs/generated/agents-context-check-project-boundary) | tests | PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559). |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2920_boundary_heredoc_strip_order.yaml`*
*Last verified: 2026-08-11*
