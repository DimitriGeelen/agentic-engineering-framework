# t3766_review_credential

> T-3766 — vendor credential location is a registry fact: `credential:` per backend in policy/review-backends.yaml, resolved by `fw review credential`, never printed.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3766_review_credential.bats`

## What It Does

T-3766 — vendor credential location is a registry fact: `credential:` per backend in
policy/review-backends.yaml, resolved by `fw review credential`, never printed.
Hermetic: the sandbox gets its own registry copy whose openrouter entry points at a
temp file holding a FAKE value built at run time. The real /root credential file is
never read; the boundary-hook pair only feeds command TEXT to the hook.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3766_review_credential.yaml`*
*Last verified: 2026-10-03*
