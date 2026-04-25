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

| Component | Relationship |
|-----------|-------------|
| `web/blueprints/terminal.py` | called_by |
| `web/terminal/registry.py` | called_by |

---
*Auto-generated from Component Fabric. Card: `web-terminal-session.yaml`*
*Last verified: 2026-04-06*
