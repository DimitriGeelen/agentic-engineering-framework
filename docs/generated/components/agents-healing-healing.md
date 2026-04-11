# healing

> Healing Agent - Antifragile error recovery and pattern learning

**Type:** script | **Subsystem:** healing | **Location:** `agents/healing/healing.sh`

## What It Does

Healing Agent - Antifragile error recovery and pattern learning
Commands:
diagnose T-XXX    Analyze task issues, suggest recovery
resolve T-XXX     Mark issue resolved, log pattern
patterns          Show known failure patterns
suggest           Get suggestions for current issues
Usage:
./agents/healing/healing.sh diagnose T-015
./agents/healing/healing.sh resolve T-015 --mitigation "Added retry logic"
./agents/healing/healing.sh patterns

### Framework Reference

**Location:** `agents/healing/`

**When to use:** When a task encounters issues (status = `issues`). Implements the antifragile healing loop.

## Dependencies (5)

| Target | Relationship |
|--------|-------------|
| `agents/healing/lib/diagnose.sh` | calls |
| `agents/healing/lib/resolve.sh` | calls |
| `agents/healing/lib/patterns.sh` | calls |
| `agents/healing/lib/suggest.sh` | calls |
| `lib/paths.sh` | calls |

## Used By (6)

| Component | Relationship |
|-----------|-------------|
| `agents/task-create/update-task.sh` | called_by |
| `bin/fw` | called_by |
| `tests/unit/healing_diagnose.bats` | called-by |
| `tests/unit/healing_suggest.bats` | called-by |
| `tests/unit/healing_diagnose.bats` | called_by |
| `tests/unit/healing_suggest.bats` | called_by |

## Documentation

- [Deep Dive: The Healing Loop](docs/articles/deep-dives/05-healing-loop.md) (deep-dive)

## Related

### Tasks
- T-796: Fix remaining single-warning shellcheck issues in agent scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-871: Fix unbound PATTERNS_FILE variable in healing agent
- T-872: Sync vendored healing.sh with T-871 fix

---
*Auto-generated from Component Fabric. Card: `agents-healing-healing.yaml`*
*Last verified: 2026-02-20*
