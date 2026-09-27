# ollama_thin_loop

> OllamaThinLoopWorker — direct /v1/messages tool loop for small local models (worker_kind=ollama-thin-loop). Ported from tools/ollama-tool-loop.py after T-2592 proved claude -p drowns 8B models (hermes3 0/9 via claude -p vs 92% here). Sandboxed Read/Bash/Grep, claude-p-shaped events so spawn/_classify_status/harness consume it unchanged.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/ollama_thin_loop.py`

**Tags:** `dispatch`, `ollama`, `worker`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [ollama-tool-loop](/docs/generated/tools-ollama-tool-loop) | calls | T-1706 — thin tool-execution loop for ollama-research workflow. |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [spawn](/docs/generated/lib-spawn) | calls | spawn — dispatch driver: read resolver envelope, spawn worker, finalise outcome. |
| `tests/unit/test_ollama_thin_loop.py` | reads | — |
| [spawn](/docs/generated/lib-spawn) | uses_by | spawn — dispatch driver: read resolver envelope, spawn worker, finalise outcome. |

---
*Auto-generated from Component Fabric. Card: `lib-ollama_thin_loop.yaml`*
*Last verified: 2026-07-21*
