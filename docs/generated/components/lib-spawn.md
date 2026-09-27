# spawn

> spawn — dispatch driver: read resolver envelope, spawn worker, finalise outcome.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/spawn.py`

## What It Does

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [pi_worker](/docs/generated/lib-pi_worker) | calls | PiWorker — subprocess wrapper for pi (mariozechner/coding-agent) in RPC mode. |
| [resolver](/docs/generated/lib-resolver) | calls | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [ollama_loop](/docs/generated/lib-ollama_loop) | calls | OllamaLoopWorker — subprocess wrapper for `claude -p` with redirected env vars. |
| [keylock-py](/docs/generated/lib-keylock-py) | uses | Python sibling of lib/keylock.sh: sidecar fcntl.flock advisory locks in .context/locks/, with a bounded timeout that raises loudly rather than degrading to a silent skipped write. Guards the dispatch ledger against the concurrent-append erasure fixed in T-3042. |
| [pi_worker](/docs/generated/lib-pi_worker) | uses | PiWorker — subprocess wrapper for pi (mariozechner/coding-agent) in RPC mode. |
| [ollama_loop](/docs/generated/lib-ollama_loop) | uses | OllamaLoopWorker — subprocess wrapper for `claude -p` with redirected env vars. |
| [ollama_thin_loop](/docs/generated/lib-ollama_thin_loop) | uses | OllamaThinLoopWorker — direct /v1/messages tool loop for small local models (worker_kind=ollama-thin-loop). Ported from tools/ollama-tool-loop.py after T-2592 proved claude -p drowns 8B models (hermes3 0/9 via claude -p vs 92% here). Sandboxed Read/Bash/Grep, claude-p-shaped events so spawn/_classify_status/harness consume it unchanged. |
| [termlink_worker](/docs/generated/lib-termlink_worker) | uses | TermLinkWorker — subprocess wrapper for `fw termlink dispatch`. |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | called_by | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [test_spawn](/docs/generated/tests-unit-test_spawn) | called_by | T-1773: Unit tests for lib/spawn.py. |
| [keylock-py](/docs/generated/lib-keylock-py) | called_by | Python sibling of lib/keylock.sh: sidecar fcntl.flock advisory locks in .context/locks/, with a bounded timeout that raises loudly rather than degrading to a silent skipped write. Guards the dispatch ledger against the concurrent-append erasure fixed in T-3042. |
| [resolver](/docs/generated/lib-resolver) | uses_by | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |
| [workflow_coverage](/docs/generated/lib-workflow_coverage) | uses_by | workflow_coverage — audit-time check for workflow → dispatcher coverage. |

---
*Auto-generated from Component Fabric. Card: `lib-spawn.yaml`*
*Last verified: 2026-05-06*
