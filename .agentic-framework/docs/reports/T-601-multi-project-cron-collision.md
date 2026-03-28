# T-601: Multi-Project Cron Collision

## Problem Statement

`fw audit schedule install` writes to a single hardcoded file `/etc/cron.d/agentic-audit`. When multiple framework-managed projects exist on the same machine, the last project to install cron silently overwrites all others. Every other project's scheduled audits are disabled without warning.

**Discovered:** 2026-03-24, 150-skills-manager agent overwrote framework repo's cron.
**Severity:** Urgent — silent failure of a core governance mechanism (scheduled audits).
**Same class as:** G-021 (silent disabling of enforcement on clone/move).

## Evidence

1. `agents/audit/audit.sh:25` — `CRON_FILE="/etc/cron.d/agentic-audit"` hardcoded
2. No check for existing cron pointing to different project
3. No warning on overwrite
4. Consumer agent dismissed the overwrite: "For now this is fine"
5. Framework repo's cron was silently disabled

## Technical Constraints

- `/etc/cron.d/` filenames must match `^[a-zA-Z0-9_-]+$` (no dots, no slashes)
- Multiple cron files in `/etc/cron.d/` coexist naturally — each is loaded independently
- `PROJECT_ROOT` is available at install time and uniquely identifies a project

## Options

### A: Project-specific cron filename (minimal)
```bash
# Derive safe name from PROJECT_ROOT
project_slug=$(echo "$PROJECT_ROOT" | tr '/' '-' | sed 's/^-//; s/-$//')
CRON_FILE="/etc/cron.d/agentic-audit-${project_slug}"
```
- **Pro:** Zero conflict, multiple projects coexist, backward-compatible
- **Con:** Long filenames for deep paths; cleanup needed when project is removed

### B: Single cron file, multi-project entries
Append entries per project instead of overwriting.
- **Pro:** Single file to manage
- **Con:** Complex dedup logic, error-prone, harder to remove one project

### C: Project-specific with short hash
```bash
project_hash=$(echo "$PROJECT_ROOT" | md5sum | head -c 8)
CRON_FILE="/etc/cron.d/agentic-audit-${project_hash}"
```
- **Pro:** Short, safe filenames
- **Con:** Opaque — can't tell which project from filename alone

### D: Basename with collision detection
```bash
project_name=$(basename "$PROJECT_ROOT")
CRON_FILE="/etc/cron.d/agentic-audit-${project_name}"
# Warn if file exists for different PROJECT_ROOT
```
- **Pro:** Human-readable, short
- **Con:** Collides if two projects share basename (e.g., two `app/` dirs)

## Recommendation

**Option D with collision warning** — human-readable, covers 95% of cases, warns on the rare collision. Fallback to Option C (hash suffix) when collision detected.

## Additional Fixes Needed

1. **`schedule remove`** — must also use project-specific filename
2. **`schedule status`** — should show cron for THIS project, not just "is any cron installed?"
3. **`fw doctor`** — should check cron points to this project
4. **Overwrite guard** — if existing cron file points to different PROJECT_ROOT, warn before overwriting

## Go/No-Go Criteria

- **Go if:** Option D (or variant) is clean to implement, <50 lines changed
- **No-go if:** cron.d filename restrictions make project-specific naming unreliable
