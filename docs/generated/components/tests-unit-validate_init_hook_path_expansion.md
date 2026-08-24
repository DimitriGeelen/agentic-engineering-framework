# validate_init_hook_path_expansion

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/validate_init_hook_path_expansion.bats`

## What It Does

T-2724 — lib/validate-init.sh must expand ${CLAUDE_PROJECT_DIR} before testing
whether a hook script exists.
Origin: every `fw init` ended with
✗ hookpaths-6vc  Hook script paths all resolve — 19 hook script(s) not found
✗ func-paths  Missing hook scripts: fw,fw,fw,...  (nineteen times)
Validation: 2 error(s) out of 42 checks
on a completely correct install. `fw init` writes hook commands in the form
'${CLAUDE_PROJECT_DIR}/.agentic-framework/bin/fw hook <event>'; the validator passed
that literal string to os.path.exists(), which is always False, and reported
os.path.basename() of it — hence 'fw' nineteen times instead of a script name.

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [validate-init](/docs/generated/lib-validate-init) | tests | Post-init validation — reads #@init: tags from init.sh and validates each creation unit exists and is correct. Called automatically at end of fw init and available as fw validate-init. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [pre-compact](/docs/generated/agents-context-pre-compact) | calls | Pre-Compaction Hook — Save structured context before lossy compaction |

---
*Auto-generated from Component Fabric. Card: `tests-unit-validate_init_hook_path_expansion.yaml`*
*Last verified: 2026-08-02*
