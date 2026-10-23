# t3881_template_hook_parity

> T-3881: `fw upgrade` step [5/10] computes "expected hooks" from the framework repo's own .claude/settings.json and compares them with what lib/init.sh generate_claude_code_config writes for a consumer.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3881_template_hook_parity.bats`

## What It Does

T-3881: `fw upgrade` step [5/10] computes "expected hooks" from the framework
repo's own .claude/settings.json and compares them with what
lib/init.sh generate_claude_code_config writes for a consumer. A hook added
here but not to the template made EVERY consumer upgrade end
"1 step(s) failed" (ring20-dashboard, v1.8.0 -> v1.8.2: check-paid-backend,
check-worktree-governance-write, stop-driver). This pins the parity at the
source, before a consumer ever sees it.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3881_template_hook_parity.yaml`*
*Last verified: 2026-10-05*
