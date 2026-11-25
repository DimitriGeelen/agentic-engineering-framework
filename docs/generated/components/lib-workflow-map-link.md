# workflow-map-link

> lib/workflow-map-link.sh — T-5391: link a tagged task to its workflow map.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/workflow-map-link.sh`

## What It Does

lib/workflow-map-link.sh — T-5391: link a tagged task to its workflow map.
fw_link_workflow_map TASK_FILE
A task tagged `outside-contributor` gets a `workflow_map:` field (the PR map)
in frontmatter and one **Workflow:** line under ## Context (the tag -> map table
is lib/workflow_map_link.py TAG_MAPS, the one place the map id is named).
Idempotent; an untagged task is not touched and no URL is resolved for it.
The base URL comes from lib/watchtower.sh (_watchtower_base_or_placeholder:
the live URL, or the port this project's Watchtower comes back on) — never a
hard-coded port (WATCHTOWER_URL overrides, as for every caller). Never fails
its caller: a failure is a warning on stderr.

---
*Auto-generated from Component Fabric. Card: `lib-workflow-map-link.yaml`*
*Last verified: 2026-11-24*
