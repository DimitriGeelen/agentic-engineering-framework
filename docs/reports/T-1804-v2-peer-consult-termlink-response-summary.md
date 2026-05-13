# T-1804 v2 peer-consult — TermLink-side response summary

**Source:** `/opt/termlink/docs/reports/v2-peer-consult-seam-response.md` (committed in /opt/termlink)
**Dispatched via:** `fw termlink dispatch --name peer-consult-v2 --project /opt/termlink` (this session)
**TermLink-side decision:** ACCEPT seam + REFINE wakeup option to (i)-via-event-class

## TermLink-side outcome (verbatim summary lines from worker)

1. **Seam: AGREED, no negotiation.** The split (TermLink = transport, AEF = semantics + spawn) maps exactly to what's already in production (`agent-chat-arc`, `fw termlink dispatch`, `dm:*` topics).

2. **Wakeup: option (i) refined.** Hub emits `inbox.queued` event when a message lands in a session's inbox with no live consumer. Payload: addressee ID, channel, offset, timestamp — no body. AEF subscribes via existing `event.subscribe` long-poll (T-690 already shipped at the Rust layer). Cron-managed 30s long-poll means zero-latency wakeup without a daemon. **Vetoed the raw `$WAKEUP_CMD` form** on security + domain-neutrality grounds.

3. **Cost: ≤40 lines, 0 new CLI verbs, 0 new config fields.** Fits within T-243's delivery window (TermLink internal task).

4. **Cross-machine: machine-local, no relay.** When sender on host A delivers to recipient on host B via `termlink remote`, hub:B handles inbox delivery and emits `inbox.queued` on host B. AEF's per-host cron subscriber catches it locally. No cross-hub event relay needed.

## What this unblocks on framework side

T-1804 inception was GO but with cross-repo coordination round-trip required before build slices could ship. That round-trip is now closed:

- ✅ Seam confirmed (transport vs semantics)
- ✅ Wakeup mechanism agreed (event class, not hook command)
- ✅ Bounded cost on TermLink side (T-243, internal)
- ✅ Cross-machine semantics clarified

## Refined framework-side build slice (v2 peer-consult slice 1)

The original T-1804 anticipated AEF needs:
- A peer-consult prompt-template surface in workflows (deferred, downstream)
- A subscriber daemon / bridge to handle wakeup

With (i) refined to `inbox.queued` event, the AEF-side becomes:
- **Cron-driven `fw peer subscribe` long-poll job** (30s window) per host
- On `inbox.queued` event: parse addressee, spawn responder via existing `fw termlink dispatch`, hand context off
- No new daemon, no new state — uses existing dispatch substrate

Estimated framework-side cost: **comparable to TermLink-side ≤40 lines** (single cron job + dispatch glue).

## Recommendation for human

This is a tight, low-cost cross-repo coordination outcome. The recommended next move:

1. **Read TermLink-side artifact:** `/opt/termlink/docs/reports/v2-peer-consult-seam-response.md` (committed there)
2. **Decide:** file v2 peer-consult slice 1 as new build task (framework + TermLink each ship their ≤40 LOC half), OR defer if (b1) operator-pause load is acceptable in practice
3. **If go:** new build task `T-XXXX v2 peer-consult slice 1 — inbox.queued event subscription + responder spawn-bridge` under `arc:orchestrator-rethink` tag

## Dispatch evidence

- Worker session: `tl-6dgo7ynz` (peer-consult-v2)
- Spawned: 2026-05-13 ~21:13Z (this session, after user requested option 2)
- Completed: ~21:25Z (≈12 min, well under 30 min timeout)
- Exit: 0
- Result manifest: `/tmp/tl-dispatch/peer-consult-v2/result.md`
- Output committed in /opt/termlink (cross-repo durability)
