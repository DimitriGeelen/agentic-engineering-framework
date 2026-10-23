# t3862_semantic_recall_optout

> T-3862: semantic recall deliberately absent on a host (SEMANTIC_RECALL=0) is "not configured on this host", not 7 FAILs; and fw upgrade names the missing prerequisites (sqlite-vec, a reachable embed host) instead of staying silent.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3862_semantic_recall_optout.bats`

## What It Does

T-3862: semantic recall deliberately absent on a host (SEMANTIC_RECALL=0) is
"not configured on this host", not 7 FAILs; and fw upgrade names the missing
prerequisites (sqlite-vec, a reachable embed host) instead of staying silent.
Hermetic: temp project, no index, embed host pointed at a closed port.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3862_semantic_recall_optout.yaml`*
*Last verified: 2026-10-21*
