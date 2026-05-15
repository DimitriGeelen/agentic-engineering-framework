# check-human-ac-tick

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-human-ac-tick.sh`

## What It Does

T-1731: Human-AC tick guard hook (bash wrapper for the Python implementation).
The fw hook dispatcher (bin/fw:4759) loads .sh files; the actual logic lives
in check-human-ac-tick.py for clean diff parsing.

---
*Auto-generated from Component Fabric. Card: `agents-context-check-human-ac-tick.yaml`*
*Last verified: 2026-05-05*
