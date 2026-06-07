# test_worker_kind_drift

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_worker_kind_drift.bats`

## What It Does

T-1708 — worker_kind drift regression test.
Origin: 2026-05-04 T-1707. T-1706 added `ollama-loop` to the termlink
dispatcher's --worker-kind flag and to the ollama-research workflow YAML,
but missed VALID_WORKER_KINDS in bin/fw's workflow validator. The
dispatcher and the validator drifted silently — `fw doctor` started
emitting FAIL on the new workflow file with no visible upstream cause.
These tests pin the invariant: every TermLink-routed kind in
VALID_WORKER_KINDS has a matching case in termlink.sh's --worker-kind
acceptor. Adding a kind to one without the other now fails loudly.

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [termlink](/docs/generated/agents-termlink-termlink) | calls | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |
| [ollama-tool-loop](/docs/generated/tools-ollama-tool-loop) | calls | TODO: describe what this component does |
| [termlink](/docs/generated/agents-termlink-termlink) | tests | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |
| [ollama-tool-loop](/docs/generated/tools-ollama-tool-loop) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_worker_kind_drift.yaml`*
*Last verified: 2026-05-03*
