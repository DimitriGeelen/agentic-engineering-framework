# test_t5128_approvals_ac_cache

> T-5128: the approvals page's per-task display parse of the acceptance criteria is cached per task file (mtime, the same key as its body cache), so a repeat request re-parses nothing that did not change — and returns exactly what an…

**Type:** script | **Subsystem:** tests | **Location:** `tests/web/test_t5128_approvals_ac_cache.py`

## What It Does

---
*Auto-generated from Component Fabric. Card: `tests-web-test_t5128_approvals_ac_cache.yaml`*
*Last verified: 2026-11-14*
