# revisit-at-preservation-test

> Regression test: revisit_at and revisit_evidence_needed frontmatter survive update-task.sh field mutations (T-1451)

**Type:** script | **Subsystem:** tests | **Location:** `agents/task-create/tests/revisit-at-preservation-test.sh`

## What It Does

T-1451 regression test: revisit_at + revisit_evidence_needed are preserved
across update-task.sh field mutations.
Strategy: update-task.sh uses targeted `_sed_i "s/^X:..."` replacements on
specific known fields (status, owner, horizon, workflow_type, tags,
last_update). Any field not in that set is preserved by default. This test
asserts revisit_at + revisit_evidence_needed are NOT in the mutation set.
This is a structural assertion: it cannot regress without an explicit code
change to update-task.sh that adds revisit_at to the sed patterns.

---
*Auto-generated from Component Fabric. Card: `agents-task-create-tests-revisit-at-preservation-test.yaml`*
*Last verified: 2026-09-08*
