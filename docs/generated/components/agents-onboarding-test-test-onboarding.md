# test-onboarding

> End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project.

**Type:** script | **Subsystem:** framework-core | **Location:** `agents/onboarding-test/test-onboarding.sh`

**Tags:** `test`, `onboarding`, `e2e`

## What It Does

Test Onboarding — End-to-End Flow Test for New Projects
Exercises the full onboarding path: init → first task → commit → audit → handover
Runs 8 checkpoints and reports PASS/WARN/FAIL for each.
Usage:
agents/onboarding-test/test-onboarding.sh              # Use temp dir (auto-cleanup)
agents/onboarding-test/test-onboarding.sh /path/to/dir  # Use specific dir (no cleanup)
agents/onboarding-test/test-onboarding.sh --keep        # Use temp dir, don't cleanup
agents/onboarding-test/test-onboarding.sh --quiet       # Machine-readable output
Exit codes: 0=all pass, 1=warnings, 2=failures
From T-307 inception GO → T-317 build task.

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `?` | uses |
| `?` | uses |

## Related

### Tasks
- T-317: Build fw test-onboarding CLI script (8 checkpoints)

---
*Auto-generated from Component Fabric. Card: `agents-onboarding-test-test-onboarding.yaml`*
*Last verified: 2026-03-04*
