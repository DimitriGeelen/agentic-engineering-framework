# dispatch

> fw dispatch subcommand: cross-machine SSH-based result dispatch. Serializes bus envelopes and pipes via SSH to remote fw bus receive.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/dispatch.sh`

## What It Does

fw dispatch - SSH-based cross-machine communication
Sends bus envelopes to remote machines via SSH pipe.
Uses ~/.ssh/config for host resolution and authentication.
Commands:
fw dispatch send --host REMOTE --task T-XXX --agent TYPE --summary "text" [--result "text"]
fw dispatch hosts    # List configured SSH hosts
Integration with fw bus:
fw bus post --remote REMOTE --task T-XXX --agent TYPE --summary "text"
Part of: Agentic Engineering Framework (T-517: SSH-based cross-machine comms)

### Framework Reference

When using Claude Code's Task tool to dispatch sub-agents (Explore, Plan, Code, etc.), follow these rules. Based on evidence from 96 tasks where 8 used sub-agents.

### Result Management Rules

**Content generators** (enrichment, file creation, report writing):
- Sub-agent MUST write output to disk (Write tool), NOT return full content
- Return only: file path + one-line summary (e.g., "Wrote .context/episodic/T-073.yaml — enriched from skeleton")
- This prevents context explosion (T-073: 9 agents returning full YAML spiked context by 30K+ tokens)

*(truncated — see CLAUDE.md for full section)*

## Used By (5)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `lib/bus.sh` | called_by |
| `agents/context/check-agent-dispatch.sh` | called_by |
| `tests/unit/lib_dispatch.bats` | called-by |
| `tests/unit/lib_dispatch.bats` | called_by |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-dispatch.yaml`*
*Last verified: 2026-03-23*
