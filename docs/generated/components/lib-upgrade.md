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
- T-653: Add cron registry seeding to fw upgrade
- T-660: Fix global install sync — upgrade also syncs bin/fw and lib/ to HOME/.agentic-framework
- T-665: Upgrade migration — replace global symlink with shim during fw upgrade
- T-679: Path C workflow refinement — document TermLink-based external ingestion, redo vnx experiment from scratch, capture learnings for TermLink and framework
- T-681: Add TermLink MCP server to fw init default MCP config

---
*Auto-generated from Component Fabric. Card: `lib-upgrade.yaml`*
*Last verified: 2026-02-20*
