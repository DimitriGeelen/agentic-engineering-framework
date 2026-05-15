# t1706-tool-loop-probe

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/t1706-tool-loop-probe.sh`

## What It Does

T-1706 — Spike A probe for the thin tool-loop worker.
Same simple-read prompts as T-1704 (hermes3:8b through claude -p, 0/9).
Goal: ≥90% real tool_use events through tools/ollama-tool-loop.py
(curated litellm /v1/messages directly).
Usage: tools/t1706-tool-loop-probe.sh [N_per_cell]   (default 3)
Output: docs/reports/T-1706-tool-loop-probe.md

---
*Auto-generated from Component Fabric. Card: `tools-t1706-tool-loop-probe.yaml`*
*Last verified: 2026-05-03*
