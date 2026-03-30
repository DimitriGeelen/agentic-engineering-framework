# colors

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/colors.sh`

## What It Does

lib/colors.sh — Shared color variables for the Agentic Engineering Framework
Provides TTY-aware, NO_COLOR-respecting color variables.
Replaces inline color definitions duplicated across 20+ scripts.
Usage: source "$FRAMEWORK_ROOT/lib/colors.sh"
Variables: RED, GREEN, YELLOW, CYAN, BOLD, NC
Automatically sourced via lib/errors.sh → lib/paths.sh chain.
Scripts that source lib/paths.sh get colors for free.

---
*Auto-generated from Component Fabric. Card: `lib-colors.yaml`*
*Last verified: 2026-03-11*
