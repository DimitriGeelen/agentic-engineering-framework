# upgrade

> fw upgrade - Sync framework improvements to a consumer project

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/upgrade.sh`

## What It Does

fw upgrade - Sync framework improvements to a consumer project
Runs in a consumer project directory, reads .framework.yaml to find the
framework, then updates governance sections, templates, hooks, and seeds.
Project-specific content is preserved.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/git/git.sh` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `tests/unit/lib_upgrade.bats` | called-by |
| `tests/unit/lib_upgrade.bats` | called_by |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-857: fw upgrade sync gap — lib/, agents/task-create/, agents/handover/, agents/git/ not vendored to consumer projects
- T-858: Update fw upgrade help text with new sync targets
- T-859: Fix fw upgrade VERSION file sync to vendored .agentic-framework/
- T-881: Upgrade consumer projects with T-879 xargs fix and T-880 init improvements

---
*Auto-generated from Component Fabric. Card: `lib-upgrade.yaml`*
*Last verified: 2026-02-20*
