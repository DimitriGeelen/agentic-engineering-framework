# termlink-runtime

> T-3779: TERMLINK_RUNTIME_DIR split-brain.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/termlink-runtime.sh`

## What It Does

T-3779: TERMLINK_RUNTIME_DIR split-brain.
TermLink keeps its hub socket and session registry in a runtime dir:
$TERMLINK_RUNTIME_DIR, or /tmp/termlink-$UID when unset. The canonical hub
on a host can live elsewhere (here: /var/lib/termlink). A launcher that
starts an agent under `env -i` drops the variable, so the agent's
`termlink register` lands in /tmp/termlink-$UID where no hub listens — peers
cannot discover it and peer mail is never typed into it. Seen live after the
2026-10-05 reboot: 27 fleet sessions, AEF's included.
fw_termlink_runtime_resolve
Prints ONE line "<verdict> <dir> <reason>" and returns 0; changes nothing

---
*Auto-generated from Component Fabric. Card: `lib-termlink-runtime.yaml`*
*Last verified: 2026-10-05*
