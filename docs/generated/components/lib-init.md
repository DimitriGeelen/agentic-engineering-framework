# init

> fw init - Bootstrap a new project with the Agentic Engineering Framework

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/init.sh`

## What It Does

fw init - Bootstrap a new project with the Agentic Engineering Framework
Creates the directory structure, config files, and git hooks needed
for a project to use the framework.

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `agents/git/git.sh` | calls |
| `lib/validate-init.sh` | calls |
| `lib/preflight.sh` | calls |
| `C-001` | calls |

## Used By (5)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `lib/setup.sh` | called_by |
| `lib/validate-init.sh` | reads_tags |
| `lib/upstream.sh` | read_by |
| `lib/validate-init.sh` | read_by |

## Related

### Tasks
- T-615: Fix fw upgrade hook count bug — enumerate by type not count
- T-663: Fix framework hooks — replace bare fw with bin/fw in settings.json
- T-677: Fix fw init hook merge — pre-existing settings.json blocks framework hooks
- T-681: Add TermLink MCP server to fw init default MCP config
- T-761: Fix shellcheck warnings in update.sh, upstream.sh, init.sh, notify.sh, setup.sh

---
*Auto-generated from Component Fabric. Card: `lib-init.yaml`*
*Last verified: 2026-02-20*
