# continuous_loop

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/integration/continuous_loop.bats`

## What It Does

T-2368 (arc-012 S-test): end-to-end continuous-loop integration test.
Drives the REAL agents/context/post-compact-resume.sh resume hook against a
temp PROJECT_ROOT, feeding SessionStart hook JSON on stdin and asserting on
the emitted additionalContext JSON. This exercises the integration seam that
the per-component unit tests (test_inject_next_directive.py, resume.bats) do
NOT cover: post-compact-resume.sh invoking the injector, capturing its stdout,
and folding the directive into the SessionStart output (post-compact-resume.sh
:267-313). Closes the D-058 "shipped before substrate-verified" gap for the
continuous-run loop.
NOT covered here (by design): the `claude-fw` process auto-restart junction —

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | calls | Session Resume Hook — Reinject structured context on session recovery |
| [inject-next-directive](/docs/generated/agents-context-inject-next-directive) | calls | TODO: describe what this component does |
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | tests | Session Resume Hook — Reinject structured context on session recovery |
| [inject-next-directive](/docs/generated/agents-context-inject-next-directive) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-integration-continuous_loop.yaml`*
*Last verified: 2026-06-13*
