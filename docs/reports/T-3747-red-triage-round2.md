# T-3747: Unit Suite Red Triage Round 2

**Session:** 2026-10-04
**Triage Start:** 10:02Z (concurrent with 55-min unit-suite.sh)
**Status:** In Progress

## Summary

Two pre-push audit failures blocking `git push origin bleeding-edge`:

- **(A) arc-membership derivation non-canonical** — lib/design_register.py manually re-derives arc membership instead of using lib.arc_membership helpers. **FIXED** ✓
- **(B) Unit suite reds** — 18 NEW reds + 7 bats timeouts vs baseline. In progress (unit-suite.sh running concurrently).

## Phase 1: T-3790 (Cron Test Leaks)

**Status:** ✓ CLOSED

Summary: `tests/unit/t3070_audit_schedule_install_delegates_to_registry.bats` test 3 wrote to real `/etc/cron.d/` (26 leaked files since 2026-08-23). Root cause: `agents/audit/audit.sh` line 32 hardcoded `/etc/cron.d/` without checking `FW_CRON_INSTALL_DIR` environment variable.

**Fixes Applied:**
1. Line 32-34 in audit.sh: use `CRON_INSTALL_DIR="${FW_CRON_INSTALL_DIR:-/etc/cron.d}"` with explicit directory variable
2. Added PROJECT_ROOT existence check at line 33-36 — exits non-zero with clear error if missing
3. Created `tools/bats-cron-env-lint.py` to scan all .bats files that run cron operations and verify FW_CRON_INSTALL_DIR is set
4. Added t3070 test 3 assertion that `/etc/cron.d` is unchanged before/after
5. Added t3070 test 5 for non-existent PROJECT_ROOT error case

**Verification:** All 4 ACs ticked, all 5 tests pass, no leaked files.

**Commits:**
- `6f0da4799` T-3790: cron test leaks → FW_CRON_INSTALL_DIR + PROJECT_ROOT validation
- `6c5739f6a` T-3790: register bats-cron-env-lint tool + episodic

## Phase 2A: T-3747 (A) — Arc-Membership Canonicalization

**Status:** ✓ FIXED

Issue: Pre-push audit found lib/design_register.py (lines 299-328) re-deriving arc_membership logic instead of using canonical lib.arc_membership functions.

**Fix Applied:**
- Added import of `scan_tasks_by_arc_id` from lib.arc_membership with fallback for script execution
- Refactored stale_keystones() function (line 327-330) to use canonical function instead of manual arc_id extraction

**Testing:** All 25 tests in test_t3694_design_register.py pass.

**Commit:** `924071db6` T-3747: lib/design_register.py uses canonical lib.arc_membership for arc_id scanning (A)

## Phase 2B: T-3747 (B) — Unit Suite Reds

**Status:** In Progress (unit-suite.sh running concurrently, ~45 min remaining)

### Known Issues to Fix

From the prompt, 18 NEW reds identified:

| Test File | Test Name | Status |
|-----------|-----------|--------|
| audit.bats | 'audit runs structure section' | Pending |
| audit.bats | 'audit runs compliance section' | Pending |
| context_yaml_escape.bats | 3: add-decision hostile input / round-trip | Pending |
| context_yaml_escape.bats | 3: add-learning hostile input | Pending |
| fw_doctor_vendored_drift.bats | 'reports No vendored-source drift when in sync' | Pending |
| fw_mode_detection.bats | T-1406 Active mode line | Pending |
| greenfield_seed_audit_prototype.bats | (T-2703, T-2740) | Pending |
| handover_digest.bats | narrative byte-identical | Pending |
| t1719_ask_routing.bats | a3 ollama outage fails at RETRIEVAL | Pending |
| t1719_index_one_post_write.bats | empty file skipped | Pending |
| t2243 | t1 | Pending |
| t2436 | t3 --check never mutates | Pending |
| t2452 | F6 --quick | Pending |
| t3511 | clean merge of a PARKED branch refused | Pending |
| t3662 | port allocation skips foreign holder | Pending |
| test_doctor_litellm_ollama.bats | (test name) | Pending |
| test_doctor_scope_tags.bats | (test name) | Pending |

### Root Cause Category

Many reds appear related to:
- **Vector index / Ollama changes (T-3786, T-3783, T-3789):** 
  - web/embeddings.py changed to raise IndexUnavailable instead of building
  - lib/ask.py now exits 3 on IndexUnavailable
  - lib/vector_index_health.py has new doctor/audit checks
  - Tests that depend on index/Ollama may timeout or fail
  
- **Doctor checks now probing index/Ollama:** Tests expecting fast doctor runs now hang on Ollama timeouts

### Strategy

1. Run full unit-suite.sh to completion (currently running, ~45 min remaining)
2. For each NEW red:
   - Run test alone to isolate
   - Determine if regression vs pre-existing/environmental
   - If regression: fix properly (code or test, never weaken assertions)
   - If pre-existing: file task for tracking

## Next Steps

1. **Await unit-suite.sh completion** (~45 min) → capture latest reds
2. **Run individual failing tests** to isolate root causes
3. **Apply fixes** for regression reds
4. **File tasks** for pre-existing/environmental reds
5. **Re-run full suite** quietly and verify all pass
6. **Run `fw audit --section structure`** to confirm arc-membership line fixed
7. **Push to origin/bleeding-edge**

