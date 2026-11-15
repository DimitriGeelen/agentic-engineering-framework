# t5134_boundary_claude_code_tmpdir

> T-5134 (dimitri-mint-dev T-226): with CLAUDE_CODE_TMPDIR set, Claude Code keeps the session scratchpad and task-output files under <dir>/claude-<uid>/.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5134_boundary_claude_code_tmpdir.bats`

## What It Does

T-5134 (dimitri-mint-dev T-226): with CLAUDE_CODE_TMPDIR set, Claude Code keeps the
session scratchpad and task-output files under <dir>/claude-<uid>/. The boundary hook
allows Bash reads there, and only there: the rest of <dir>, another account's subtree
and the rest of /var/tmp stay refused, as before.
The hook is FED each command; nothing here is executed.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5134_boundary_claude_code_tmpdir.yaml`*
*Last verified: 2026-11-14*
