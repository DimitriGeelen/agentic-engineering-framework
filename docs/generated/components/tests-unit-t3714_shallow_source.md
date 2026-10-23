# t3714_shallow_source

> T-3714: a SHALLOW framework clone cannot see a consumer's recorded version_sha by construction.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3714_shallow_source.bats`

## What It Does

T-3714: a SHALLOW framework clone cannot see a consumer's recorded
version_sha by construction. fw_version_relation used to convict it as a
FOREIGN source ("it cannot be the origin of the consumer's code"), and the
upgrade block sent the reader after a stale global shim. Reported by 055
(2026-10-02) and 832 (2026-10-05, a --depth 1 clone of v1.8.2).
Contract: still refuse (the commit is unverifiable), but name the shallow
clone and the one-command remedy. The full-history foreign case keeps its
own reason (control), and unshallowing turns the same pair into `behind`.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3714_shallow_source.yaml`*
*Last verified: 2026-10-05*
