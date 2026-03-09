# fw

> Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes.

**Type:** script | **Subsystem:** framework-core | **Location:** `bin/fw`

## What It Does

fw - Agentic Engineering Framework CLI
Single entry point for all framework operations.
Reads .framework.yaml from the project directory to resolve
FRAMEWORK_ROOT, then routes commands to the appropriate agent.
When run from a project that uses the framework as shared tooling,
fw reads .framework.yaml to find the framework install path.
When run from inside the framework repo itself, it auto-detects.

### Framework Reference

The `fw` command is the single entry point for all framework operations. It resolves paths, sets environment variables, and routes to agents.

```bash
fw help              # Show all commands
fw version           # Show version and paths
fw doctor            # Check framework health
fw audit             # Run compliance audit
fw context init      # Initialize session
fw git commit -m "T-XXX: description"
fw handover --commit # Generate and commit handover
fw task create --name "Fix bug" --type build --owner human
```

*(truncated — see CLAUDE.md for full section)*

## Dependencies (21)

| Target | Relationship |
|--------|-------------|
| `agents/task-create/create-task.sh` | calls |
| `agents/task-create/update-task.sh` | calls |
| `C-004` | calls |
| `agents/audit/plugin-audit.sh` | calls |
| `C-001` | calls |
| `agents/fabric/fabric.sh` | calls |
| `agents/git/git.sh` | calls |
| `agents/handover/handover.sh` | calls |
| `agents/healing/healing.sh` | calls |
| `agents/resume/resume.sh` | calls |
| `agents/mcp/mcp-reaper.sh` | calls |
| `agents/observe/observe.sh` | calls |
| `lib/inception.sh` | calls |
| `lib/promote.sh` | calls |
| `lib/assumption.sh` | calls |
| `lib/bus.sh` | calls |
| `lib/init.sh` | calls |
| `lib/upgrade.sh` | calls |
| `lib/setup.sh` | calls |
| `lib/harvest.sh` | calls |
| `web/app.py` | calls |

## Documentation

- [Deep Dive: Tier 0 Protection](docs/articles/deep-dives/02-tier0-protection.md) (deep-dive)
- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

## Related

### Tasks
- T-355: Fix Homebrew Cellar path hardcoding in fw init — use opt symlink
- T-357: Implement post-init validation with #@init: tags
- T-359: Rename Homebrew formula to avoid brocode/fw collision
- T-364: Layer 1: Component reference doc generator
- T-366: Layer 2: AI-assisted subsystem article generator

---
*Auto-generated from Component Fabric. Card: `bin-fw.yaml`*
*Last verified: 2026-02-20*
