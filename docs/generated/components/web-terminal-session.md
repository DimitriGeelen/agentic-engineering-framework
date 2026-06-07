# session

> Provider-neutral dataclass defining the terminal session descriptor schema with metadata, capabilities, and process info

**Type:** script | **Subsystem:** watchtower | **Location:** `web/terminal/session.py`

## What It Does

### Framework Reference

**Before beginning any work:**
1. Initialize context: `fw context init`
2. Read `.context/handovers/LATEST.md` to understand current state
3. Review the "Suggested First Action" section
4. Set focus: `fw context focus T-XXX`
5. Run `fw metrics` to see project status
6. If handover feedback section exists, fill it in

**Before ANY implementation (even if a skill says "start now"):**
1. Verify a task exists for the work: `fw work-on "name" --type build` or `fw work-on T-XXX`
2. Confirm focus is set in `.context/working/focus.yaml`
3. THEN proceed with implementation

*(truncated — see CLAUDE.md for full section)*

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [terminal](/docs/generated/web-blueprints-terminal) | called_by | Flask blueprint providing the interactive web terminal API with session creation, I/O, resize, and profile-based configuration |
| [registry](/docs/generated/web-terminal-registry) | called_by | Provides CRUD operations and YAML file persistence for terminal session records stored in .context/sessions/ |

## Related

### Tasks
- T-967: Session profiles + provider registry for orchestrator readiness (T-962 Phase 4)

---
*Auto-generated from Component Fabric. Card: `web-terminal-session.yaml`*
*Last verified: 2026-04-06*
