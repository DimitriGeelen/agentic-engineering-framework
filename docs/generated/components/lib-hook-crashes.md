# hook-crashes

> hook-crashes.sh — acknowledge / count the hook crash log (T-4227)

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/hook-crashes.sh`

## What It Does

hook-crashes.sh — acknowledge / count the hook crash log (T-4227)
fw_hook_crash_trap (lib/config.sh) and fw_hook_run (lib/hook-dispatch.sh) append
to .context/working/.hook-crashes.log; `fw doctor` WARNs on every line in it.
Before T-4227 nothing ever removed a line, so once a crash was logged the doctor
count could never return to zero. `acknowledge` moves the live entries to
.hook-crashes.acknowledged.log (history kept, stamped with when they were
acknowledged) and empties the live log.
Usage (sourced or run directly; no bin/fw route yet):
bash lib/hook-crashes.sh count          — live (unacknowledged) entries
bash lib/hook-crashes.sh acknowledge    — archive live entries, empty the log

---
*Auto-generated from Component Fabric. Card: `lib-hook-crashes.yaml`*
*Last verified: 2026-10-18*
