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

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `lib/paths.sh` | calls |
| `lib/config.sh` | calls |
| `lib/notify.sh` | calls |
| `lib/watchtower.sh` | calls |

## Used By (7)

| Component | Relationship |
|-----------|-------------|
| `C-004` | called_by |
| `agents/audit/self-audit.sh` | read_by |
| `agents/context/check-project-boundary.sh` | related_by |
| `C-009` | triggers_by |
| `.claude/settings.json` | used-by |
| `agents/audit/audit.sh` | called-by |

## Documentation

- [Deep Dive: Tier 0 Protection](docs/articles/deep-dives/02-tier0-protection.md) (deep-dive)
- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

## Related

### Tasks
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block

---
*Auto-generated from Component Fabric. Card: `agents-context-check-tier0.yaml`*
*Last verified: 2026-02-20*
