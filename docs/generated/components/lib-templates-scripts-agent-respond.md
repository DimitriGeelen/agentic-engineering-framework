# agent-respond

> Template skill script: pickup-and-respond ritual — receiver's mechanical ack for doorbell+mail turns (T-1805)

**Type:** script | **Subsystem:** termlink-integration | **Location:** `lib/templates/scripts/agent-respond.sh`

## What It Does

T-1805 — pickup-and-respond ritual: the receiver's mechanical ack (T-1800 build #2).
Counterpart to scripts/agent-send.sh (T-1804). When a listener is woken by an
injected doorbell (/check-arc) and finds an unread turn, this verb closes the
"respond" half of the doorbell+mail loop — deterministically, with no protocol
changes, composing only existing termlink primitives:
1. receipt : channel post <dm-topic> --msg-type receipt --metadata
conversation_id=<cid> --metadata up_to=<offset>
-> the EXACT shape agent-send.sh polls for, so the sender
learns DELIVERED (closes the PL-011 "ok != delivered" gap).
2. reply   : (optional, --reply) channel post <dm-topic> --msg-type turn

---
*Auto-generated from Component Fabric. Card: `lib-templates-scripts-agent-respond.yaml`*
*Last verified: 2026-09-08*
