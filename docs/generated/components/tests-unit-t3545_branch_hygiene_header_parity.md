# t3545_branch_hygiene_header_parity

> T-3545 / OBS-467 — a module header must not assert the opposite of its own code.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3545_branch_hygiene_header_parity.bats`

## What It Does

T-3545 / OBS-467 — a module header must not assert the opposite of its own code.
`lib/branch-hygiene.sh`'s header read "Judged against TARGET = origin/master
when present, else master" for as long as the code did not: T-3188 changed the
resolution chain to prefer `origin/$FW_DEV_BRANCH` (default `bleeding-edge`)
and left master only as the fallback for a master-only consumer.
That is not a cosmetic drift. Under the release train (CLAUDE.md §Release-Train
Branch Model) master lags deliberately, so "landings are judged against master"
licenses exactly the wrong remediation — and the header is the only interface a
reader has before they decide to trust the function. The findings this rail
emits decide whether branches get deleted.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3545_branch_hygiene_header_parity.yaml`*
*Last verified: 2026-09-28*
