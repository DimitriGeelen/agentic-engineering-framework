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

| Target | Relationship |
|--------|-------------|
| `agents/termlink/termlink.sh` | calls |
| `tools/ollama-tool-loop.py` | calls |
| `agents/termlink/termlink.sh` | tests |
| `tools/ollama-tool-loop.py` | tests |
| `bin/fw` | tests |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_worker_kind_drift.yaml`*
*Last verified: 2026-05-03*
