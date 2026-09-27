# revisit-due-scan-test

> Unit test for the revisit-due daily scan over DEFER decisions (T-1452, G-053)

**Type:** script | **Subsystem:** tests | **Location:** `agents/context/tests/revisit-due-scan-test.sh`

## What It Does

revisit-due-scan-test.sh — Unit test for T-1452 / G-053
Creates a sandbox PROJECT_ROOT with two mock tasks (one ripe, one future)
plus one without revisit_at, runs the scanner, asserts only the ripe task
appears in the output file.

---
*Auto-generated from Component Fabric. Card: `agents-context-tests-revisit-due-scan-test.yaml`*
*Last verified: 2026-09-08*
