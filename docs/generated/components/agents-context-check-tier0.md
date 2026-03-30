# check-tier0

> Tier 0 Enforcement Hook — PreToolUse gate for Bash tool

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-tier0.sh`

## What It Does

Tier 0 Enforcement Hook — PreToolUse gate for Bash tool
Detects destructive commands and blocks them unless explicitly approved.
Exit codes (Claude Code PreToolUse semantics):
0 — Allow tool execution
2 — Block tool execution (stderr shown to agent)
Flow:
1. Extract bash command from stdin JSON
2. Quick keyword check (bash grep — no Python overhead for safe commands)
3. If keywords found, Python detailed pattern matching
4. If destructive pattern matched:

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/paths.sh` | calls |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `C-004` | called_by |
| `agents/audit/self-audit.sh` | read_by |
| `agents/context/check-project-boundary.sh` | related_by |
| `C-009` | triggers_by |

## Documentation

- [Deep Dive: Tier 0 Protection](docs/articles/deep-dives/02-tier0-protection.md) (deep-dive)
- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

## Related

### Tasks
- T-612: Agent approval pickup — hook/cron scanning Watchtower approval ledger
- T-635: Deterministic human-facing action routing — structural enforcement that agent always routes through Watchtower/fw-task-review instead of pasting raw commands
- T-638: check-tier0 Watchtower link — emit approval page URL in Tier 0 block message
- T-641: Tier 0 rejection feedback — write rejection reason to resolved YAML, agent reads on retry
- T-709: Wire ntfy notifications into framework hooks — Tier 0, task complete, audit, handover

---
*Auto-generated from Component Fabric. Card: `agents-context-check-tier0.yaml`*
*Last verified: 2026-02-20*
