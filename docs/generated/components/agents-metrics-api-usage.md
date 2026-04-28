# api-usage

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/metrics/api-usage.sh`

## What It Does

T-1304/T-1308: fw metrics api-usage [--last-Nd N] [--runtime-dir PATH] [--gate-pct N]
Reads <runtime_dir>/rpc-audit.jsonl, tallies per-method RPC counts, and
reports the percentage of legacy primitives — used as the T-1166 entry
gate (retire legacy `event.broadcast` + `inbox.*` + `file.*` once their
share drops below 1% over 60 days).
Modes:
- Default (no --last-Nd):       trend report across 1d / 7d / 30d / 60d
windows for incremental feedback. Exit
code reflects the 60d (gate) window.
- --last-Nd N:                  single window, original CI-gate behavior.

---
*Auto-generated from Component Fabric. Card: `agents-metrics-api-usage.yaml`*
*Last verified: 2026-04-28*
