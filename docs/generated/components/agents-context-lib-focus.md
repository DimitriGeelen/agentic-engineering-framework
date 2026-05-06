# focus

> Context Agent - focus command

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/focus.sh`

## What It Does

Context Agent - focus command
Set or show current task focus

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/ask.py` | calls |

## Used By (6)

| Component | Relationship |
|-----------|-------------|
| `C-001` | called_by |
| `capture-skill` | read_by |
| `agents/context/context.sh` | called-by |
| `.claude/commands/capture.md` | used-by |
| `tests/unit/context_focus.bats` | called_by |
| `tests/unit/context_focus.bats` | tests_by |

## Documentation

- [Deep Dive: The Task Gate](docs/articles/deep-dives/01-task-gate.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-focus.yaml`*
*Last verified: 2026-02-20*
