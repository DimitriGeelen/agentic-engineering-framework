# t3890_conversation_holder

> T-3890: claude-fw must not open a conversation another live process holds. 832 (2026-10-05): a fleet resume-by-id plus a separate `claude-fw -c` ran the same conversation twice for ~2h45; both executed one runme step.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3890_conversation_holder.bats`

## What It Does

T-3890: claude-fw must not open a conversation another live process holds.
832 (2026-10-05): a fleet resume-by-id plus a separate `claude-fw -c` ran the
same conversation twice for ~2h45; both executed one runme step.
A fake holder is a process whose argv[0] is "claude" (exec -a).

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3890_conversation_holder.yaml`*
*Last verified: 2026-10-05*
