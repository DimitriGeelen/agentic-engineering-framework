# t4401_audit_live_repo_lint

> T-4401: no unit test may run a sectioned audit against the real repo.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4401_audit_live_repo_lint.bats`

## What It Does

T-4401: no unit test may run a sectioned audit against the real repo.
audit.sh takes the repo-wide flock $CONTEXT_DIR/locks/audit.lock for every
`--section` run and exits 75 when it is held (audit.sh:614-631). A test that
runs one without a fixture PROJECT_ROOT shares that lock with every cron
audit, pre-push gate and sibling worker, so it skips (`ok ... # skip`, green,
nothing measured) or pays the whole live section. tools/audit-live-repo-lint.py
refuses that shape; this file runs it over tests/unit and pins its controls.
Offender lines below are built from pieces so this file never lints itself red.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4401_audit_live_repo_lint.yaml`*
*Last verified: 2026-10-20*
