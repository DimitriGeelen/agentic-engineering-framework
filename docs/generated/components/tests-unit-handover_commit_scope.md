# handover_commit_scope

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/handover_commit_scope.bats`

## What It Does

T-3090 — a pathspec-scoped commit must not absorb a concurrent writer's index.
The defect: `agents/git/lib/commit.sh` ran `git commit -m "$message"` with no
pathspec, so it committed the WHOLE INDEX. The handover's narrow
`git add <2 files>` bounded staging only — and staging is half the operation.
Live instance: commit d3d3e49db ("T-3028: Session handover S-2026-0819-2334")
carried 4 files, two of them a concurrent session's T-3089 work, and emptied
that session's index out from under it mid-compose.
── What these tests are actually asserting ──────────────────────────────────
NOT "the commit succeeded" and NOT "the foreign file is absent". A do_commit
that committed NOTHING AT ALL would satisfy "the foreign file is absent"

---
*Auto-generated from Component Fabric. Card: `tests-unit-handover_commit_scope.yaml`*
*Last verified: 2026-08-19*
