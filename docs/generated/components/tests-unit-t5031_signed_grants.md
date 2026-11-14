# t5031_signed_grants

> T-5031 (operator ruling 2026-11-14, "Signed commit"): once policy/grants-allowed-signers has been committed, a grant counts only from an SSH-signed commit by a listed key.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5031_signed_grants.bats`

## What It Does

T-5031 (operator ruling 2026-11-14, "Signed commit"): once policy/grants-allowed-signers has
been committed, a grant counts only from an SSH-signed commit by a listed key. The signers
list is a chain: each change signed by a key from the previous version, the first one
self-signed (the anchor, shown by doctor). Real keys (ssh-keygen), real signed commits, git's
own verifier. Projects that never adopted signing keep the trailer rule with a doctor WARN.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5031_signed_grants.yaml`*
*Last verified: 2026-11-14*
