# t4492_runme_sha_manifest

> T-4492: runme job queue slice 2 of the T-4470 GO — the sha manifest over job.json and every file a step reaches, rechecked immediately before each step (prerequisite 3, review finding 5: "the sha binds job.sh only"), and the per-step y/N…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4492_runme_sha_manifest.bats`

## What It Does

T-4492: runme job queue slice 2 of the T-4470 GO — the sha manifest over job.json and
every file a step reaches, rechecked immediately before each step (prerequisite 3,
review finding 5: "the sha binds job.sh only"), and the per-step y/N confirm with
typeahead discarded. Each finding-5 leg is red against slice 1, which hashed job.json
only and confirmed once for the whole job.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4492_runme_sha_manifest.yaml`*
*Last verified: 2026-10-20*
