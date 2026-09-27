# test_url_credentials

> T-2693 — lib/url-credentials.sh, the single dialect for URL credential handling.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_url_credentials.bats`

## What It Does

T-2693 — lib/url-credentials.sh, the single dialect for URL credential handling.
Origin: OBS-106. `bin/fw` wrote the vendored `.upstream` sentinel from
`git remote get-url origin` verbatim, so a credentialed origin put a live
token into a tracked file — and echoed it to stdout for good measure. The
strip already existed in lib/consumer-recover.sh and had never been applied
on the write path (L-399 producer/consumer split).
The tokens below are synthesized fixtures, not real credentials.

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [url-credentials](/docs/generated/lib-url-credentials) | calls | URL credential handling — one dialect, shared by every writer of an upstream URL. |
| [consumer-recover](/docs/generated/lib-consumer-recover) | calls | fw consumer-recover - one-command recovery for legacy vendored consumers |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [url-credentials](/docs/generated/lib-url-credentials) | tests | URL credential handling — one dialect, shared by every writer of an upstream URL. |
| [consumer-recover](/docs/generated/lib-consumer-recover) | tests | fw consumer-recover - one-command recovery for legacy vendored consumers |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_url_credentials.yaml`*
*Last verified: 2026-07-31*
