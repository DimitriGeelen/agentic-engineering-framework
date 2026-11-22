# t5354_status_young_after_compaction

> T-5354 (G-139, reported by 0506): right after a compaction the token counter has fewer than 2 usage entries since the compact_boundary and returns status `young`.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5354_status_young_after_compaction.bats`

## What It Does

T-5354 (G-139, reported by 0506): right after a compaction the token counter has fewer
than 2 usage entries since the compact_boundary and returns status `young`. `checkpoint.sh
status` printed only "unavailable (no usage data)", so the agent fell back to the stale
budget figure in the compaction summary ("~81% of 800k" while the real figure was ~15%).
These tests run the REAL checkpoint.sh status against transcript fixtures.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5354_status_young_after_compaction.yaml`*
*Last verified: 2026-11-21*
