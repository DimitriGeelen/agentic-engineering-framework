# reviewer_verdict_replacement_escape

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/reviewer_verdict_replacement_escape.bats`

## What It Does

T-2730 — a rendered verdict is DATA, and must never reach `re.sub` as a
replacement *template*.
`re.sub(repl, string)` parses `repl` for template escapes. The reviewer passed
its rendered verdict straight in, and the verdict quotes evidence lines out of
the task body — so any backslash the author wrote was interpreted. CLAUDE.md
itself instructs authors to write `sed 's/\x1b\[[0-9;]*m//g'` to strip ANSI, so
the reviewer crashed on precisely the tasks that follow the documented idiom:
re.error: bad escape \x at position 386
Measured population at fix time: 7 task files (`\x`, and also `\s` and `\d`
from regex idioms in Verification blocks), out of 486 containing a backslash

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-reviewer_verdict_replacement_escape.yaml`*
*Last verified: 2026-08-02*
