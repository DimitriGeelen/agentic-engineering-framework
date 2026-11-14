# t5123_termlink_check_no_hub

> T-5123 — `fw termlink check` completes when no hub is reachable.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t5123_termlink_check_no_hub.bats`

## What It Does

T-5123 — `fw termlink check` completes when no hub is reachable.
BEFORE: agents/termlink/termlink.sh declared `local hub_pid hub_dir cfg_dir`
without initialising them. `hub_dir` is assigned only inside
if [ -n "$hub_pid" ] && [ -r "/proc/$hub_pid/environ" ]
so when no hub process is found — or its environ is unreadable — it stayed
DECLARED BUT UNSET. The script runs under `set -u`, so the first dereference
(`[ -n "$hub_dir" ]`, inside the `if [ -f "$mcp" ]` branch) aborted the whole
function with `hub_dir: unbound variable`.
The failure fired exactly when no hub was reachable — which is when an agent
runs this command to find out why. On 2026-11-13 it masked the real finding

---
*Auto-generated from Component Fabric. Card: `tests-unit-t5123_termlink_check_no_hub.yaml`*
*Last verified: 2026-11-13*
