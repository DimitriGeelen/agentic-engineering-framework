# recover

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/gpu-recover/recover.sh`

## What It Does

recover.sh — Free GPU memory by terminating the largest non-ollama VRAM consumer.
Designed for shared GPU hosts where an ollama-using project hits a load
failure because another project (FLUX, Whisper, ...) is holding VRAM.
Reactive only — fires when invoked, not on a schedule.
Usage:
fw gpu recover [--requester <name>] [--dry-run] [--threshold-mb N] [--json]
Exit codes:
0 — action taken (process terminated) OR no action needed (no eligible target)
1 — error (nvidia-smi unavailable, parse failure)
2 — eligible target found but kill failed

---
*Auto-generated from Component Fabric. Card: `agents-gpu-recover-recover.yaml`*
*Last verified: 2026-04-25*
