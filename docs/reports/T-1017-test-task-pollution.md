# T-1017: Test Task Pollution — RCA Investigation

## Problem Statement

E2E tests (`fw self-test`) and integration tests (`fw test integration`) are creating task files in the **real** `.tasks/active/` directory instead of their designated temp directories. 16 orphan tasks (T-995 through T-1013) were discovered on 2026-04-07, all untracked/uncommitted.

**Impact:**
- 16 fake tasks pollute active task list and metrics
- Real task IDs consumed (T-995–T-1013) — gap in traceability
- Handover documents list orphan tasks as real work
- Audit metrics inflated (active task count, horizon distribution)
- Framework was blind — no detection mechanism existed

## Evidence

### Orphan task inventory

| Task | Name | Source Test | Created |
|------|------|-----------|---------|
| T-995 | Task for focus test | fw_context.bats | 09:59:59 |
| T-996 | Evaluate caching strategy | fw_inception.bats | 10:05:00 |
| T-997 | Test workflow type | fw_inception.bats | 10:05:04 |
| T-998 | Status check task | fw_inception.bats | 10:05:07 |
| T-999 | Metrics count test | fw_metrics.bats | 10:05:17 |
| T-1000 | Self-test lifecycle task | lifecycle-test.sh (E2E) | 10:05:36 |
| T-1001 | Self-test lifecycle task | lifecycle-test.sh (E2E) | 10:06:28 |
| T-1002 | Self-test lifecycle task | lifecycle-test.sh (E2E) | 10:07:13 |
| T-1004 | Self-test lifecycle task | lifecycle-test.sh (E2E) | 10:07:57 |
| T-1005 | Fix login timeout handling | fw_task.bats | 10:08:45 |
| T-1006 | Visible task in list | fw_task.bats | 10:08:48 |
| T-1007 | Onboarding test task | onboarding-test.sh (E2E) | 10:12:41 |
| T-1009 | Onboarding test task | onboarding-test.sh (E2E) | 10:17:24 |
| T-1011 | Fix auth timeout handling | fw_work_on.bats | 10:21:10 |
| T-1012 | Focus test task | fw_work_on.bats | 10:21:13 |
| T-1013 | Resumable test task | fw_work_on.bats | 10:21:17 |

### Isolation code analysis

All tests APPEAR to isolate correctly:
- Integration tests (`fw_task.bats`, `fw_inception.bats`, etc.) use `setup()` with `mktemp -d` and `export PROJECT_ROOT="$TEST_TEMP_DIR"`
- E2E tests (`lifecycle-test.sh`) create own temp dir and pass `PROJECT_ROOT="$TMPDIR"` to each command
- `create-task.sh` uses `$TASKS_DIR` (from `lib/paths.sh`) which respects `$PROJECT_ROOT`
- `generate_id()` scans `$TASKS_DIR` (not hardcoded path)

Yet the files ended up in the real `.tasks/active/`. The IDs are sequential with the real project counter.

## Investigation

### Hypothesis 1: PROJECT_ROOT not exported through exec chain

**Theory:** `bin/fw` sets `PROJECT_ROOT` as a shell variable (line 111-113) but does NOT export it. When `fw task create` does `exec "$AGENTS_DIR/task-create/create-task.sh"` (line 1259), shell variables are NOT inherited by `exec`.

**Test:** Check if bin/fw exports PROJECT_ROOT.

### Hypothesis 2: E2E tests run via fw self-test without PROJECT_ROOT isolation  

**Theory:** `fw_self_test.bats` calls `$FW self-test` without setting PROJECT_ROOT. `bin/fw` resolves it to the real framework root. The E2E scripts create temp dirs but some code path still writes to the original PROJECT_ROOT.

### Hypothesis 3: Integration tests work, but counter.yaml bleeds

**Theory:** There's a shared counter file that's updated in the real project even when tasks are created in temp dirs. But investigation shows `generate_id()` scans task files (no counter file), so this is unlikely.

## Findings

### Hypothesis 1: DISPROVED
`bin/fw` DOES export PROJECT_ROOT at line 421: `export PROJECT_ROOT`. `lib/paths.sh` also exports at line 42: `export FRAMEWORK_ROOT PROJECT_ROOT TASKS_DIR CONTEXT_DIR`. The exec chain properly inherits env vars.

### Hypothesis 2: DISPROVED
Ran `fw self-test` with leak detection — no leaks. Ran `bats tests/integration/fw_task.bats`, `bats tests/integration/fw_inception.bats`, `fw test integration` — no leaks in any case. The isolation code works correctly.

### Hypothesis 3: DISPROVED
`generate_id()` (create-task.sh:112-126) scans `$TASKS_DIR/active/T-*.md` — no shared counter file. When TASKS_DIR points to temp dir, IDs start from T-001.

### Root cause: NON-REPRODUCIBLE

After exhaustive testing (5 reproduction attempts, 0 leaks), the exact mechanism cannot be reproduced. The isolation code is correct and working. The orphan tasks exist as historical artifacts.

**Most likely explanation**: During the previous session, the agent or a background task ran test commands (bats or fw test) in an unusual environment state where PROJECT_ROOT was not properly isolated. Possible triggers:
1. Agent tool subprocess ran test commands with inherited PROJECT_ROOT pointing to real project
2. A test command was run directly (outside bats) without temp dir isolation
3. An environmental race condition during concurrent agent dispatches

**What IS reproducible**: The framework had NO detection mechanism for test artifacts in production. This is the structural gap regardless of root cause.

### Structural blindness analysis

5 layers that SHOULD have caught this but didn't:

| Layer | Why it missed |
|-------|--------------|
| `.gitignore` | No pattern for test-generated tasks |
| `fw audit` | No check for test-artifact descriptions/names |
| Handover agent | Lists all active tasks without filtering test artifacts |
| Metrics | Counts all tasks indiscriminately |
| Task gate | Only checks if focus is set, not if task is legitimate |

## Options

### A: Audit check for test-artifact tasks (DETECTION)
Add audit rule detecting tasks with descriptions like "Test", "Created by E2E test", or names matching known test fixtures ("Self-test lifecycle task", "Onboarding test task", etc.).
- **Pro:** Catches future leaks immediately, runs every 30 min via cron
- **Con:** Pattern matching may have false positives; doesn't prevent creation

### B: Test isolation validation in test_helper (PREVENTION)
Add to `tests/test_helper` a function that verifies PROJECT_ROOT is NOT the real project root, and fails the test if it is. Called in every test's setup().
- **Pro:** Structural prevention — tests physically cannot write to real tasks
- **Con:** Requires all tests to use the helper (not enforced)

### C: Cleanup orphans + .gitignore guard (REMEDIATION)
Delete the 16 orphan tasks. Add `.tasks/active/` entries to `.gitignore` that exclude test-patterned names.
- **Pro:** Immediate cleanup
- **Con:** .gitignore only prevents commits, not creation; pattern matching is fragile

### D: FW_TEST_MODE env var in create-task.sh (PREVENTION)
When `FW_TEST_MODE=1`, create-task.sh validates that PROJECT_ROOT is a temp directory (under /tmp).
- **Pro:** Direct structural guard at the creation point
- **Con:** Adds complexity to create-task.sh; may break legitimate uses

## Recommendation

**GO with A + B** (detection + prevention):

1. **Option B** (structural prevention): Add `assert_test_isolation()` to `tests/test_helper` that fails if PROJECT_ROOT equals FRAMEWORK_ROOT. This is the root cause fix — tests MUST use temp dirs.

2. **Option A** (detection layer): Add audit check for test-artifact tasks. This catches any future leaks that bypass the test_helper guard.

3. **Cleanup**: Delete the 16 orphan task files as part of implementation.

**Why not C alone**: .gitignore only prevents commits, not creation. The pollution to metrics and handovers happens regardless of git tracking.

**Why not D**: Adds runtime complexity to create-task.sh for a problem that should be caught at the test level, not the production tool level.

## Decision

(Pending human GO/NO-GO)
