# t4449_precommit_template_shipped

> T-4449 — the pre-commit hook refuses a commit that stages .tasks/templates/*.md while the STAGED lib/upgrade_template_shipped.py is not current (generate_known differs).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4449_precommit_template_shipped.bats`

## What It Does

T-4449 — the pre-commit hook refuses a commit that stages .tasks/templates/*.md
while the STAGED lib/upgrade_template_shipped.py is not current (generate_known
differs). Third occurrence of the class (T-4035, T-4213, T-4441): before this,
only the nightly test_upgrade_template_sync_t3955 noticed, a day later.
Hermetic: same fixture shape as t4379_precommit_dead_negation.bats — hooks are
installed into a temp repo whose .framework.yaml points at this checkout; the
hook is run directly, no commit is made.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4449_precommit_template_shipped.yaml`*
*Last verified: 2026-10-20*
