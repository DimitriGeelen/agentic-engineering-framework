# t1700-ollama-harness

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/t1700-ollama-harness.sh`

## What It Does

T-1700 ollama-research harness — exercises v1 dispatch substrate end-to-end
through litellm proxy onto ollama. Used for AC group 4 (empirical validation).
Usage:
tools/t1700-ollama-harness.sh [N]
N defaults to 3. Each iteration spawns one TermLink worker via
`fw termlink dispatch --task-type ollama-research` with a unique tool-use
prompt, waits for completion, captures exit code + result + latency.
Output: docs/reports/T-1700-harness-results.md (overwritten each run).
Requirements (checked at start, fails loud if missing):
- litellm proxy on :4000 (health/liveliness)

---
*Auto-generated from Component Fabric. Card: `tools-t1700-ollama-harness.yaml`*
*Last verified: 2026-05-03*
