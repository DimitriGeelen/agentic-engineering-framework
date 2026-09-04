# t3245_trailer_quote_strip

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3245_trailer_quote_strip.bats`

## What It Does

T-3245 — the mandated Co-Authored-By trailer voided the partial-complete
bare-commit allowance.
CLAUDE.md requires every commit to carry:
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
`is_commit_checkpoint_command` (safe-commands.sh) judged has_bash_write_pattern
against the RAW command line. The trailer's `<noreply@anthropic.com>` sits
inside a quoted `-m` argument, and the redirect regex `[^2>&]>[^>&]|>>` cannot
tell it from a real `<` operator — so a commit carrying the mandated trailer
was never "bare", and the T-3179 block message's own remedy ("drop the
redirect and run the commit bare") was unreachable for the trailer the

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | tests | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3245_trailer_quote_strip.yaml`*
*Last verified: 2026-09-03*
