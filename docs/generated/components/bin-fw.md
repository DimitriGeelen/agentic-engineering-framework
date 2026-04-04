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

## Dependencies (37)

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
| `agents/audit/self-audit.sh` | calls |
| `agents/onboarding-test/test-onboarding.sh` | calls |
| `agents/docgen/generate-article.sh` | calls |
| `agents/docgen/generate-component.sh` | calls |
| `agents/termlink/termlink.sh` | calls |
| `lib/compat.sh` | calls |
| `lib/review.sh` | calls |
| `lib/ask.sh` | calls |
| `lib/tasks.sh` | calls |
| `lib/dispatch.sh` | calls |
| `lib/upstream.sh` | calls |
| `lib/preflight.sh` | calls |
| `lib/validate-init.sh` | calls |
| `lib/update.sh` | calls |
| `bin/watchtower.sh` | calls |
| `lib/build.sh` | calls |

## Used By (3)

| Component | Relationship |
|-----------|-------------|
| `agents/audit/self-audit.sh` | read_by |
| `lib/upstream.sh` | called_by |
| `web/subprocess_utils.py` | called_by |

## Documentation

- [Deep Dive: Tier 0 Protection](docs/articles/deep-dives/02-tier0-protection.md) (deep-dive)
- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

## Related

### Tasks
- T-775: fw pickup send — consumer-side CLI for local and TermLink push
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-812: fw task stale — identify and report stale active tasks
- T-814: fw doctor stale task count — show task debt in health check
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block

---
*Auto-generated from Component Fabric. Card: `bin-fw.yaml`*
*Last verified: 2026-02-20*
