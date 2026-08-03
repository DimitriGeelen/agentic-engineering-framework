# test_url_credentials

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_url_credentials.bats`

## What It Does

T-2693 — lib/url-credentials.sh, the single dialect for URL credential handling.
Origin: OBS-106. `bin/fw` wrote the vendored `.upstream` sentinel from
`git remote get-url origin` verbatim, so a credentialed origin put a live
token into a tracked file — and echoed it to stdout for good measure. The
strip already existed in lib/consumer-recover.sh and had never been applied
on the write path (L-399 producer/consumer split).
The tokens below are synthesized fixtures, not real credentials.

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_url_credentials.yaml`*
*Last verified: 2026-07-31*
