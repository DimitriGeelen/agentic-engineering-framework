# fw-task-revisit-due-test

> Unit test for the fw task revisit-due CLI wrapper around the G-053 revisit scan (T-1453)

**Type:** script | **Subsystem:** tests | **Location:** `agents/context/tests/fw-task-revisit-due-test.sh`

## What It Does

fw-task-revisit-due-test.sh — Unit test for T-1453 (CLI wrapper around T-1452 scan)
Creates a sandbox PROJECT_ROOT with one ripe, one future, and one no-revisit
task, then runs `fw task revisit-due` with PWD inside the sandbox. Asserts:
1. Ripe-found path: stdout contains the "Ripe revisits" header AND the ripe T-ID line
2. No-ripe path (after removing the ripe task): stdout contains "No revisits due today"
3. Exit code 0 in both states

---
*Auto-generated from Component Fabric. Card: `agents-context-tests-fw-task-revisit-due-test.yaml`*
*Last verified: 2026-09-08*
