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

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |

## Related

### Tasks
- T-169: Build fw upgrade command — sync framework improvements to consumer projects
- T-315: Build fw upgrade command (audit, propose, apply)
- T-348: Fix update-task.sh sed failing on macOS BSD sed

---
*Auto-generated from Component Fabric. Card: `lib-upgrade.yaml`*
*Last verified: 2026-02-20*
