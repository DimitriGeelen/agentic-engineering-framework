# update-task

> Task Update Agent - Status transitions with auto-triggers

**Type:** script | **Subsystem:** task-management | **Location:** `agents/task-create/update-task.sh`

## What It Does

Task Update Agent - Status transitions with auto-triggers
Updates task frontmatter and triggers structural actions:
issues/blocked  → auto-diagnose via healing agent
work-completed  → set date_finished, move to completed/, generate episodic
Usage:
./agents/task-create/update-task.sh T-XXX --status issues
./agents/task-create/update-task.sh T-XXX --status work-completed
./agents/task-create/update-task.sh T-XXX --owner claude-code
./agents/task-create/update-task.sh T-XXX --status blocked --reason "Waiting on API key"

## Dependencies (2)

| Target | Relationship |
|--------|-------------|
| `C-001` | calls |
| `agents/healing/healing.sh` | calls |

## Used By (2)

| Component | Relationship |
|-----------|-------------|
| `C-004` | called_by |
| `bin/fw` | called_by |

## Documentation

- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

## Related

### Tasks
- T-236: Wire agent fabric awareness — blast-radius in git hooks, auto-capture learnings on completion
- T-342: Implement human AC format requirements from T-325
- T-348: Fix update-task.sh sed failing on macOS BSD sed
- T-354: Tighten task gate: validate status + clear focus on completion

---
*Auto-generated from Component Fabric. Card: `agents-task-create-update-task.yaml`*
*Last verified: 2026-02-20*
