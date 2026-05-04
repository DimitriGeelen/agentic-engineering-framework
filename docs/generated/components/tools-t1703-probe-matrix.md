# t1703-probe-matrix

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/t1703-probe-matrix.sh`

## What It Does

T-1703 probe matrix — gemma4 + qwen3.5 against 3 tool catalogues.
Uses simple-read prompts only (Read tool sufficient) so the Read-only
catalogue cell isn't penalised for prompts that need Bash.
Output: docs/reports/T-1703-curated-catalogue-probe.md
Usage: tools/t1703-probe-matrix.sh [N_per_cell]   (default 3)

---
*Auto-generated from Component Fabric. Card: `tools-t1703-probe-matrix.yaml`*
*Last verified: 2026-05-03*
