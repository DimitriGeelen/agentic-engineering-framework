# idalloc

> lib/idalloc.sh — the one task-id allocator (T-5217, slice 1 of inception T-5212).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/idalloc.sh`

## What It Does

lib/idalloc.sh — the one task-id allocator (T-5217, slice 1 of inception T-5212).
Design: 1409's proposal (their T-6848), recorded in docs/reports/T-5212-batch-task-creation.md.
WHY ONE ALLOCATOR. Before this file, agents/task-create/create-task.sh (generate_id) and
lib/objectives-seed.sh (T-5213) each computed "max + 1" on their own, and generate_id
union-scanned every worktree's .tasks/ on every create (2-4 s per id with 24 worktrees).
1409 measured that an old allocator running beside a block allocator reissues an id from an
aborted reservation once more than FW_ID_QUARANTINE_GAP ids are reserved and unused. So every
task id in a repository is handed out here, and `fw doctor` warns when another path remains.
THE PIECES (all under <main worktree>/.tasks/):
.id-highwater     the counter: the highest id ever handed out. Read and raised only under

---
*Auto-generated from Component Fabric. Card: `lib-idalloc.yaml`*
*Last verified: 2026-11-17*
