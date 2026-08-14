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

---
*Auto-generated from Component Fabric. Card: `tests-unit-validate_init_hook_path_expansion.yaml`*
*Last verified: 2026-08-02*
