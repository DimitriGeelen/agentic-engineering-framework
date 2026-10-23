# conversation-holder

> T-3890: never run two live copies of one Claude conversation.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/conversation-holder.sh`

## What It Does

T-3890: never run two live copies of one Claude conversation.
`claude -c` continues the NEWEST conversation in this directory and
`--resume <id>` a named one. Neither checks whether another live process is
already in that conversation. 832, 2026-10-05: after a reboot the fleet resumed
their conversation by id while a separate `claude-fw -c` continued the same
one; two live copies ran ~2h45 and BOTH executed the upgrade's re-apply step.
Live holder = the sidecar session record (.context/sidecar/sessions/<id>.json,
written by the prompt/stop hooks) names a claude_pid that is alive AND is
still a claude process (a recycled pid does not count).

---
*Auto-generated from Component Fabric. Card: `lib-conversation-holder.yaml`*
*Last verified: 2026-10-05*
