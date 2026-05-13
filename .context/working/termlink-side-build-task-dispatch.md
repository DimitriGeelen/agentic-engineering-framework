# TermLink-side build task: file the `inbox.queued` event emission counterpart

You are a TermLink-side agent. The framework agent has filed T-1818 framework-half of the v2 peer-consult slice 1. Your job is to file the TermLink-side counterpart build task in your project's task system (or its equivalent issue tracker / project plan).

## Background (read first)

1. Read /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1818-v2-peer-consult-slice-1-framework-half--.md — the framework-side build task that pairs with yours.
2. Read /opt/999-Agentic-Engineering-Framework/docs/reports/T-1804-v2-peer-consult-termlink-response-summary.md — the cross-repo coordination outcome (your prior session's response captured framework-side).
3. Read your project's existing v2-peer-consult-seam-response.md artifact in docs/reports/ — that's the YOUR prior response.

## What to deliver

File a build task on the TermLink side (in your project's task system) that ships the `inbox.queued` event emission. The contract from your own prior response was:

- **New event class:** `inbox.queued`
- **Payload:** `{addressee, channel, offset, timestamp}` — NO message body
- **Trigger:** message lands in a session's inbox AND no live consumer (PTY subscriber) is attached
- **Hub behaviour:** machine-local emission (no cross-hub relay); when sender on host A delivers to recipient on host B via `termlink remote`, hub:B handles inbox delivery and emits `inbox.queued` on host B
- **Cost:** ≤40 lines, 0 new CLI verbs, 0 new config fields (per your earlier estimate)

The build task should pair with framework T-1818 (cross-repo joint slice). Both halves should ship under matching ACs so the wire contract stays identical.

## Important

- File the task in YOUR project's task system (use your normal task-create verb).
- The task should reference T-1818 (framework-side counterpart) in its description / related_tasks / linked-issues field — whatever your project uses.
- DO NOT write code yet. This task is the BUILD task; code lands later when the task is worked.
- Keep ACs at a substrate level: event class emitted, payload shape correct, no-live-consumer detection, cross-machine semantics correct, unit test pinning all four.
- DO NOT modify files outside your project root.

## Final reply format (≤5 lines)

  DONE
  <path to the new TermLink-side build task file you created>
  TermLink-side build task ID: <T-XXX or whatever your project uses>
  Pairs with framework T-1818 / wire contract: inbox.queued{addressee,channel,offset,timestamp}
  Estimated cost: ≤40 lines, 0 new CLI verbs (per your prior estimate)
