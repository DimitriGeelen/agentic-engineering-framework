# t2996_seed_commit_assertion

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2996_seed_commit_assertion.bats`

## What It Does

T-2996 (G-006): the onboarding seeds asserted a property of HEAD.
`git log -1 --format=%s | grep -q "T-003"` is true at the moment the seed task
completes and false from the next commit onward. Every project built on AEF
inherited a CTL-013 that fires forever and that no consumer action clears —
and `fw update` overwrites any local fix.
The load-bearing tests are the two behavioural ones at the bottom. They build
throwaway repos and run the seed's actual assertion under P-011's real
conditions (`set -eo pipefail`), rather than asserting on the text of the file.
The text tests above them exist only to catch a regression to the old shape.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2996_seed_commit_assertion.yaml`*
*Last verified: 2026-08-14*
