# ollama_thin_loop

> OllamaThinLoopWorker — direct /v1/messages tool loop for small local models (worker_kind=ollama-thin-loop). Ported from tools/ollama-tool-loop.py after T-2592 proved claude -p drowns 8B models (hermes3 0/9 via claude -p vs 92% here). Sandboxed Read/Bash/Grep, claude-p-shaped events so spawn/_classify_status/harness consume it unchanged.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/ollama_thin_loop.py`

**Tags:** `dispatch`, `ollama`, `worker`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [ollama-tool-loop](/docs/generated/tools-ollama-tool-loop) | calls | TODO: describe what this component does |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [spawn](/docs/generated/lib-spawn) | calls | TODO: describe what this component does |
| `tests/unit/test_ollama_thin_loop.py` | reads | — |

---
*Auto-generated from Component Fabric. Card: `lib-ollama_thin_loop.yaml`*
*Last verified: 2026-07-21*
