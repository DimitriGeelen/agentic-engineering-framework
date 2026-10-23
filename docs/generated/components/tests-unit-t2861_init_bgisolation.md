# t2861_init_bgisolation

> T-2861: generate_claude_code_config (lib/init.sh) — the generator behind `fw init` and `fw upgrade` step 5 — must emit worktree.bgIsolation=none.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t2861_init_bgisolation.bats`

## What It Does

T-2861: generate_claude_code_config (lib/init.sh) — the generator behind `fw init`
and `fw upgrade` step 5 — must emit worktree.bgIsolation=none. T-3263 set it in
the framework repo's own .claude/settings.json by hand; consumers never got it,
so a background session refused the first Write of an inception (C-001 artifact)
until it entered a worktree, which forks tracked governance state (T-2821/T-2822).

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2861_init_bgisolation.yaml`*
*Last verified: 2026-10-20*
