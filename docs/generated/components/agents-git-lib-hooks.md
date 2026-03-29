# hooks

> Git Agent - Hook installation subcommand

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/hooks.sh`

## What It Does

Git Agent - Hook installation subcommand

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `C-004` | calls |
| `lib/tasks.sh` | calls |

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `agents/git/git.sh` | called_by |

## Related

### Tasks
- T-519: Fix do_vendor not found during fw doctor interactive init
- T-520: Fix commit-msg hook FRAMEWORK_ROOT resolution for vendored installs
- T-521: fw init should git init when not in a git repo
- T-591: Commit cadence warning — PostToolUse hook counting edits since last commit
- T-606: Version bumping mechanism — structural enforcement for version tracking across framework and vendored projects

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-hooks.yaml`*
*Last verified: 2026-02-20*
