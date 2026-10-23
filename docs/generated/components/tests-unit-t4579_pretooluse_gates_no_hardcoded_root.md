# t4579_pretooluse_gates_no_hardcoded_root

> T-4579: tests/governance/test_pretooluse_gates.bats built its hook inputs with file_path literals under the origin host's checkout path.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4579_pretooluse_gates_no_hardcoded_root.bats`

## What It Does

T-4579: tests/governance/test_pretooluse_gates.bats built its hook inputs with
file_path literals under the origin host's checkout path. In any clone at
another path the project root is the clone, so check-active-task and
check-project-boundary correctly treated those paths as outside the project and
the two ALLOWS tests went red (reproduced in a clean clone under env -i).
Every in-project path a hook input names must be built from $FRAMEWORK_ROOT.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4579_pretooluse_gates_no_hardcoded_root.yaml`*
*Last verified: 2026-10-22*
