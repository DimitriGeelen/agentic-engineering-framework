# agent-send

> Template skill script: deterministic doorbell+mail send verb composing termlink primitives into one atomic delivered-or-failed send (T-1804)

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/agent-send.sh`

## What It Does

T-1804 — deterministic doorbell+mail send verb (T-1800 build #1).
Composes EXISTING termlink primitives (no protocol changes) into one atomic
send so the SENDER always learns delivered-or-failed — closing the PL-011
"ok:true means hub-accepted, NOT delivered" gap for conversational turns:
1. mail     : channel post <dm-topic> --msg-type turn  (the turn content)
2. doorbell : inject <peer-session> "/check-arc"        (wake the listener)
3. receipt  : poll the dm-topic (filtered by conversation_id) for a
msg_type=receipt envelope (the receiver's ack)
4. re-ring  : if no receipt within the per-attempt timeout, ring again,
up to --max-rings; then exit non-zero (NOT delivered).

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-agent-send.yaml`*
*Last verified: 2026-09-08*
