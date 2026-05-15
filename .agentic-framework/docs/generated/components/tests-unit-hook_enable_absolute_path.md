# hook_enable_absolute_path

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/hook_enable_absolute_path.bats`

## What It Does

T-1504: fw hook-enable must emit absolute hook commands.
Background: bin/hook-enable.sh:73 used to emit ".agentic-framework/bin/fw"
(relative). Claude Code's hook runner is POSIX `sh -c`, which does not
chdir to the project root before invoking, so the relative path resolved
only when the parent shell happened to be at project root. Downstream
003-NTB-ATC-Plugin observed 680 silent "non-blocking status code" failures
in one session JSONL.
Fix mirrors lib/init.sh:584 (T-1364, G-053-A): canonicalize the project
root from --file path, detect framework-mode (FRAMEWORK.md + bin/fw) vs
consumer-mode (.agentic-framework/bin/fw), emit absolute path either way.

## Dependencies (4)

| Target | Relationship |
|--------|-------------|
| `bin/hook-enable.sh` | calls |
| `bin/hook-enable.sh` | tests |
| `lib/init.sh` | tests |
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-hook_enable_absolute_path.yaml`*
*Last verified: 2026-04-26*
