# post-compact-resume

> Session Resume Hook — Reinject structured context on session recovery

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/post-compact-resume.sh`

## What It Does

Session Resume Hook — Reinject structured context on session recovery
Fires on SessionStart with matchers "compact" and "resume" (T-188).
Outputs additionalContext JSON so Claude has framework state immediately.
Triggers:
- After /compact (manual compaction recovery)
- After claude -c (session continuation, including auto-restart via T-179)
Part of: T-111 (compact-resume), T-179/T-188 (auto-restart)

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `agents/fabric/fabric.sh` | calls |

## Related

### Tasks
- T-241: Wire discovery findings into session-start and Watchtower

---
*Auto-generated from Component Fabric. Card: `agents-context-post-compact-resume.yaml`*
*Last verified: 2026-02-20*
