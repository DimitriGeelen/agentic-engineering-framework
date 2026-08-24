# worktree-corpus-guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** git-traceability | **Location:** `agents/git/lib/worktree-corpus-guard.sh`

## What It Does

T-3110 — L1 of R7: task-corpus commit guard for the SHARED pre-commit hook.
WHY THIS EXISTS, AND WHY IT IS NOT JUST ANOTHER SCANNER
R1-R6 of docs/design/task-corpus-concurrency-model.md are enforced by code.
That code is TRACKED CONTENT, so it forks with the branch: a linked worktree
supplies the very code meant to constrain the linked worktree. Measured in
this repo — the `t100199-close` worktree has no check-worktree-governance-write.sh,
zero union-scan in its allocator, and a `bin/fw` dated 6 July. Every fix in
that document is absent from the replica it was designed to constrain.
`.git/hooks` is the one anchor that does NOT fork: it resolves to the shared
common dir from the main checkout and from every linked worktree alike, and

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

---
*Auto-generated from Component Fabric. Card: `agents-git-lib-worktree-corpus-guard.yaml`*
*Last verified: 2026-08-20*
