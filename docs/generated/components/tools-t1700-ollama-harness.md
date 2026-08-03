# t1700-ollama-harness

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/t1700-ollama-harness.sh`

## What It Does

T-1700 ollama-research harness (v2, T-2408) — exercises the v1 dispatch
substrate end-to-end through `fw resolver run` onto litellm/ollama.
Usage:
tools/t1700-ollama-harness.sh [N]
N defaults to 3. Each iteration dispatches one ollama-loop worker via
`fw resolver run <task> ollama-research --var TASK_DESCRIPTION=...` with a
unique tool-use prompt, reads the JSON outcome (status / events_path), and
counts real tool_use events from the events stream.
v2 (T-2408): rerouted from the raw termlink-CLI dispatch path so every run
lands an envelope row in .context/dispatches.jsonl, and a final

---
*Auto-generated from Component Fabric. Card: `tools-t1700-ollama-harness.yaml`*
*Last verified: 2026-05-03*
