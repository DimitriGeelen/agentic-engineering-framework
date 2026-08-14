# ollama-tool-loop

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/ollama-tool-loop.py`

## What It Does

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [termlink](/docs/generated/agents-termlink-termlink) | called_by | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |
| [test_worker_kind_drift](/docs/generated/tests-unit-test_worker_kind_drift) | called_by | TODO: describe what this component does |
| [test_worker_kind_drift](/docs/generated/tests-unit-test_worker_kind_drift) | tests_by | TODO: describe what this component does |
| [ollama_thin_loop](/docs/generated/lib-ollama_thin_loop) | called_by | OllamaThinLoopWorker — direct /v1/messages tool loop for small local models (worker_kind=ollama-thin-loop). Ported from tools/ollama-tool-loop.py after T-2592 proved claude -p drowns 8B models (hermes3 0/9 via claude -p vs 92% here). Sandboxed Read/Bash/Grep, claude-p-shaped events so spawn/_classify_status/harness consume it unchanged. |

---
*Auto-generated from Component Fabric. Card: `tools-ollama-tool-loop.yaml`*
*Last verified: 2026-05-03*
