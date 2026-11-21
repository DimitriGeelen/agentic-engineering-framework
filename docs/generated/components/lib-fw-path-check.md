# fw-path-check

> fw-path-check.sh — which `fw` is on PATH? (T-5303, rule T-5302)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/fw-path-check.sh`

## What It Does

fw-path-check.sh — which `fw` is on PATH? (T-5303, rule T-5302)
Printed commands no longer depend on the answer: since T-5303 every printed
command spells this project's own fw (`bin/fw` or `.agentic-framework/bin/fw`,
lib/paths.sh _fw_cmd). People and agents still TYPE bare `fw`, and that only
runs the project's copy when the PATH fw is the T-2793 router. ring20's host
.122 still had the pre-router fw-shim (T-5302 consultation), so doctor says
which kind is installed and how to refresh it.
fw_path_kind [path]   → router | shim | other | absent   (path = `command -v fw`)
fw_installed_path     → first fw on PATH that is not a project's own copy
fw_doctor_path_fw     → prints one doctor line (+ remedy); returns 1 on WARN

---
*Auto-generated from Component Fabric. Card: `lib-fw-path-check.yaml`*
*Last verified: 2026-11-20*
