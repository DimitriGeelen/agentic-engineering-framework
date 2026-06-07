# inception_commit_counter

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/inception_commit_counter.bats`

## What It Does

Unit tests for _count_inception_exploration_commits (T-2195)
The inception commit-budget gate must count only EXPLORATION commits.
Storage commits (filing-only, demote, status-flip, frontmatter edit) are
bookkeeping with zero exploration content and must be exempt.
Origin: T-2186 itself hit the budget at commit 3 (Step 0 findings) because
filing + demote consumed 2/2 with zero exploration — the same scoring-shaped
rigidity the inception was trying to recalibrate.

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hooks](/docs/generated/agents-git-lib-hooks) | calls | Git Agent - Hook installation subcommand |
| [hooks](/docs/generated/agents-git-lib-hooks) | tests | Git Agent - Hook installation subcommand |

---
*Auto-generated from Component Fabric. Card: `tests-unit-inception_commit_counter.yaml`*
*Last verified: 2026-06-02*
