# t3712_upgrade_step5_field_hooks

> T-3712 — `fw upgrade` step 5 reported PARTIAL "missing check-paid-backend, check-worktree-governance-write, Stop:stop-driver.sh" and left the three hooks missing, while `fw hook-enable` registered them fine (055 field report, 2026-10-02…

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3712_upgrade_step5_field_hooks.bats`

## What It Does

T-3712 — `fw upgrade` step 5 reported PARTIAL "missing check-paid-backend,
check-worktree-governance-write, Stop:stop-driver.sh" and left the three
hooks missing, while `fw hook-enable` registered them fine (055 field report,
2026-10-02; same report from 010 as T-3815). Root cause: the consumer
template (lib/init.sh generate_claude_code_config) did not write them, and
the framework's Stop hook is spelled agents/context/stop-driver.sh while the
template spells 'fw hook stop-driver'. Fixed by T-3881 (69e87852f).
t3881_template_hook_parity.bats pins the template/detector parity statically.
This pins the end-to-end symptom the field saw: a REAL `fw upgrade`
subprocess, under env -i, against a vendored consumer whose settings.json

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3712_upgrade_step5_field_hooks.yaml`*
*Last verified: 2026-10-20*
