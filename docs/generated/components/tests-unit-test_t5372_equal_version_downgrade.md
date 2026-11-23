# test_t5372_equal_version_downgrade

> T-5372 — equal version strings are decided by commit ancestry.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_t5372_equal_version_downgrade.bats`

## What It Does

T-5372 — equal version strings are decided by commit ancestry.
be-tags keep VERSION at the last release (T-3821), so a be-tag consumer and
master share one version string. Before T-5372 fw_version_relation returned
`same` on equal strings without looking at the recorded version_sha, and the
direct-path precheck in lib/upgrade.sh was skipped on equal strings: a plain
fw upgrade from master could silently roll a be-tag consumer back.
Hermetic: the relation cases run against a throwaway git repo; the do_upgrade
cases use a scratch commit reached through GIT_ALTERNATE_OBJECT_DIRECTORIES so
the live repo's object store is never written. No network.

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_t5372_equal_version_downgrade.yaml`*
*Last verified: 2026-11-22*
