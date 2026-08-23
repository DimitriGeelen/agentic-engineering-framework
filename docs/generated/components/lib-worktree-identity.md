# worktree-identity

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/worktree-identity.sh`

## What It Does

lib/worktree-identity.sh — "is this checkout a replica?" (T-3111, R7)
ONE PREDICATE, THREE SURFACES. The question *am I a linked worktree* is asked by:
1. lib/paths.sh            — sources this file, so every agent that sources
paths.sh keeps `fw_is_linked_worktree` verbatim.
2. bin/fw's L2 redirect    — must answer it BEFORE FRAMEWORK_ROOT exists, and
cannot source paths.sh (which resolves and exports
paths as a side effect of being sourced).
3. bin/fw doctor           — suppresses HOST-level drift checks in a worktree
(T-2435/OBS-077); previously an inline copy.
The predicate lived in lib/paths.sh with an independent inline copy in bin/fw's

---
*Auto-generated from Component Fabric. Card: `lib-worktree-identity.yaml`*
*Last verified: 2026-08-22*
