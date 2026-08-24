# no-backticks-in-inline-python

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/lint/no-backticks-in-inline-python.bats`

## What It Does

T-2707: backticks inside a double-quoted `python3 -c "..."` block are COMMAND
SUBSTITUTION performed by bash before python ever sees the source.
The defect shape is prose: someone writes a markdown-style `command` inside an
explanatory comment that happens to live inside the python string. Bash runs it,
splices its STDOUT into the python source, and if that output is multi-line the
second line stops being a comment and becomes executable python -> SyntaxError ->
the whole block dies. In a PreToolUse hook that means the gate fails open.
Origin: T-2702 shipped a comment reading "PRINTS `fw context focus T-XXX` as the
remedy" into agents/context/budget-gate.sh. Every hook invocation then shelled out
to `fw context focus` (and `context init`, `context focus` -> command not found).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [budget-gate](/docs/generated/budget-gate) | tests | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-lint-no-backticks-in-inline-python.yaml`*
*Last verified: 2026-07-31*
