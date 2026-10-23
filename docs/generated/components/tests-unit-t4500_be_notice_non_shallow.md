# t4500_be_notice_non_shallow

> T-4500: pre-release notices say "upgrade from a NON-SHALLOW clone". A shallow clone of a -be tag cannot see the consumer's recorded version_sha, so fw upgrade refuses it as foreign-source (lib/version-relation.sh, T-3714).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4500_be_notice_non_shallow.bats`

## What It Does

T-4500: pre-release notices say "upgrade from a NON-SHALLOW clone". A shallow
clone of a -be tag cannot see the consumer's recorded version_sha, so fw upgrade
refuses it as foreign-source (lib/version-relation.sh, T-3714). The notice must
say so before the field project clones, and name the unshallow remedy.
Temp repos only — nothing here tags or pushes the framework repo.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4500_be_notice_non_shallow.yaml`*
*Last verified: 2026-10-20*
