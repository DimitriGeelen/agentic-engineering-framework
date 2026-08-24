# t2813_install_hooks_write_failure

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2813_install_hooks_write_failure.bats`

## What It Does

T-2813: `fw git install-hooks` printed "=== Hooks Installed ===" and exited 0
even when every hook write failed (cat > "$hook" << 'EOF' fails silently at
the redirect, before the heredoc body runs; the subsequent chmod failure was
likewise unchecked). This suite pins the fix: install-hooks now verifies
each hook exists and is executable on disk before reporting it, and exits
non-zero — with no success banner — when any hook was not actually written.
Invokes agents/git/git.sh directly (not `fw git`) with PROJECT_ROOT
exported per-scenario, per the L-271 bats pattern (see sibling
git_install_hooks_git_path.bats for T-2812).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [git](/docs/generated/agents-git-git) | calls | Git Agent - Structural Enforcement for Git Operations |
| [git](/docs/generated/agents-git-git) | tests | Git Agent - Structural Enforcement for Git Operations |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2813_install_hooks_write_failure.yaml`*
*Last verified: 2026-08-05*
