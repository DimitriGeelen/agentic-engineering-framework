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

## Used By (1)

| Component | Relationship |
|-----------|-------------|
| `C-004` | called_by |

## Documentation

- [Deep Dive: Tier 0 Protection](docs/articles/deep-dives/02-tier0-protection.md) (deep-dive)
- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

## Related

### Tasks
- T-229: Fix HIGH severity enforcement bypasses — B-001 (--no-verify) and B-005 (hook config)

---
*Auto-generated from Component Fabric. Card: `agents-context-check-tier0.yaml`*
*Last verified: 2026-02-20*
