# spawn

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/spawn.py`

## What It Does

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [pi_worker](/docs/generated/lib-pi_worker) | calls | TODO: describe what this component does |
| [resolver](/docs/generated/lib-resolver) | calls | TODO: describe what this component does |
| [ollama_loop](/docs/generated/lib-ollama_loop) | calls | TODO: describe what this component does |
| [keylock-py](/docs/generated/lib-keylock-py) | uses | Python sibling of lib/keylock.sh: sidecar fcntl.flock advisory locks in .context/locks/, with a bounded timeout that raises loudly rather than degrading to a silent skipped write. Guards the dispatch ledger against the concurrent-append erasure fixed in T-3042. |
| [pi_worker](/docs/generated/lib-pi_worker) | uses | TODO: describe what this component does |
| [ollama_loop](/docs/generated/lib-ollama_loop) | uses | TODO: describe what this component does |
| [ollama_thin_loop](/docs/generated/lib-ollama_thin_loop) | uses | OllamaThinLoopWorker — direct /v1/messages tool loop for small local models (worker_kind=ollama-thin-loop). Ported from tools/ollama-tool-loop.py after T-2592 proved claude -p drowns 8B models (hermes3 0/9 via claude -p vs 92% here). Sandboxed Read/Bash/Grep, claude-p-shaped events so spawn/_classify_status/harness consume it unchanged. |
| [termlink_worker](/docs/generated/lib-termlink_worker) | uses | TODO: describe what this component does |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | called_by | TODO: describe what this component does |
| [test_spawn](/docs/generated/tests-unit-test_spawn) | called_by | TODO: describe what this component does |
| [keylock-py](/docs/generated/lib-keylock-py) | called_by | Python sibling of lib/keylock.sh: sidecar fcntl.flock advisory locks in .context/locks/, with a bounded timeout that raises loudly rather than degrading to a silent skipped write. Guards the dispatch ledger against the concurrent-append erasure fixed in T-3042. |
| [resolver](/docs/generated/lib-resolver) | uses_by | TODO: describe what this component does |
| [workflow_coverage](/docs/generated/lib-workflow_coverage) | uses_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-spawn.yaml`*
*Last verified: 2026-05-06*
