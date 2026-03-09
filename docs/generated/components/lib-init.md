# init

> fw init - Bootstrap a new project with the Agentic Engineering Framework

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/init.sh`

## What It Does

fw init - Bootstrap a new project with the Agentic Engineering Framework
Creates the directory structure, config files, and git hooks needed
for a project to use the framework.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `agents/git/git.sh` | calls |
| `lib/validate-init.sh` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `lib/setup.sh` | called_by |
| `lib/validate-init.sh` | reads_tags |

## Related

### Tasks
- T-348: Fix update-task.sh sed failing on macOS BSD sed
- T-349: Streamline fw init output for new users
- T-352: Fix hook path resolution in fw init for Homebrew installs
- T-357: Implement post-init validation with #@init: tags
- T-367: Auto-generate watch-patterns.yaml on fw context init

---
*Auto-generated from Component Fabric. Card: `lib-init.yaml`*
*Last verified: 2026-02-20*
