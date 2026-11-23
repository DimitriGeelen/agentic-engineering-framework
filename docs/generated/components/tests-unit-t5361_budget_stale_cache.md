# t5361_budget_stale_cache

> T-5361 — `checkpoint.sh budget` answered "level: unknown / cache is 362s old" mid-session.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5361_budget_stale_cache.bats`

## What It Does

T-5361 — `checkpoint.sh budget` answered "level: unknown / cache is 362s old"
mid-session. Two legs:
writer: budget-gate.sh throttled its transcript re-read to every 5th call even
once the cache was stale, so a stale cache stayed stale for minutes;
reader: when age is the cache's ONLY fault, `budget` measures live from THIS
Claude session's own transcript (found by session id, never "newest").
A foreign cache or another session's transcript still yields unknown (T-3241, T-3598).
Fixtures only: tmp PROJECT_ROOT, tmp HOME, synthetic transcripts and caches.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5361_budget_stale_cache.yaml`*
*Last verified: 2026-11-22*
